# Copyright 2019 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Support for linking related actions."""

load("@build_bazel_apple_support//lib:lipo.bzl", "lipo")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load(
    "@rules_cc//cc/private/rules_impl:objc_compilation_support.bzl",
    objc_compilation_support = "compilation_support",
)
load(
    "//apple/internal:cc_toolchain_info_support.bzl",
    "cc_toolchain_info_support",
)
load(
    "//apple/internal:compilation_support.bzl",
    "compilation_support",
)
load(
    "//apple/internal:entitlements_support.bzl",
    "entitlements_support",
)
load(
    "//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "//apple/internal:outputs.bzl",
    "outputs",
)
load(
    "//apple/internal:providers.bzl",
    "AppleDynamicFrameworkInfo",
    "AppleExecutableBinaryInfo",
    "ApplePlatformInfo",
)

def _archive_multi_arch_static_library(
        *,
        ctx,
        cc_configured_features,
        cc_toolchains):
    """Generates a (potentially multi-architecture) static library archive for Apple platforms.

    Rule context is a required parameter due to usage of the cc_common.configure_features API.

    Args:
        ctx: The Starlark rule context.
        cc_configured_features: A struct returned by `features_support.cc_configured_features(...)`
            to capture the rule ctx for a deferred `cc_common.configure_features(...)` call.
        cc_toolchains: Dictionary of CcToolchainInfo and ApplePlatformInfo providers under a split
            transition to relay target platform information for related deps.

    Returns:
        A Starlark struct containing the following attributes:
            - output_groups: OutputGroupInfo provider from transitive CcInfo validation_artifacts.
            - outputs: List of structs containing the following attributes:
                - library: Artifact representing a linked static library.
                - architecture: Static library archive architecture (e.g. 'arm64', 'x86_64').
                - platform: Static library archive target Apple platform (e.g. 'ios', 'macos').
                - environment: Static library archive environment (e.g. 'device', 'simulator').
    """

    # TODO: Delete when we drop bazel 7.x
    legacy_linking_function = getattr(apple_common, "link_multi_arch_static_library", None)
    if legacy_linking_function:
        return legacy_linking_function(ctx = ctx)

    split_deps = ctx.split_attr.deps
    split_avoid_deps = ctx.split_attr.avoid_deps

    outputs = []

    for split_transition_key, child_toolchain in cc_toolchains.items():
        cc_toolchain = child_toolchain[cc_common.CcToolchainInfo]
        common_variables = objc_compilation_support.build_common_variables(
            ctx = ctx,
            toolchain = cc_toolchain,
            use_pch = True,
            deps = split_deps[split_transition_key],
        )

        avoid_cc_linking_contexts = []

        if len(split_avoid_deps.keys()):
            for dep in split_avoid_deps[split_transition_key]:
                if CcInfo in dep:
                    avoid_cc_linking_contexts.append(dep[CcInfo].linking_context)

        name = ctx.label.name + "-" + cc_toolchain.target_gnu_system_name + "-fl"

        cc_linking_context = compilation_support.subtract_linking_contexts(
            owner = ctx.label,
            linking_contexts = common_variables.objc_linking_context.cc_linking_contexts,
            avoid_dep_linking_contexts = avoid_cc_linking_contexts,
        )
        linking_outputs = compilation_support.register_fully_link_action(
            cc_configured_features = cc_configured_features,
            cc_linking_context = cc_linking_context,
            common_variables = common_variables,
            name = name,
        )

        output = {
            "library": linking_outputs.library_to_link.static_library,
        }

        platform_info = child_toolchain[ApplePlatformInfo]
        output["platform"] = platform_info.target_os
        output["architecture"] = platform_info.target_arch
        output["environment"] = platform_info.target_environment

        outputs.append(struct(**output))

    header_tokens = []
    for _, deps in split_deps.items():
        for dep in deps:
            if CcInfo in dep:
                header_tokens.append(dep[CcInfo].compilation_context.validation_artifacts)

    output_groups = {"_validation": depset(transitive = header_tokens)}

    return struct(
        outputs = outputs,
        output_groups = OutputGroupInfo(**output_groups),
    )

def _link_multi_arch_binary(
        *,
        ctx,
        avoid_deps = [],
        build_settings,
        bundle_name,
        cc_configured_features,
        cc_toolchains,
        extra_linkopts = [],
        extra_link_inputs = [],
        rule_descriptor,
        stamp = -1,
        variables_extension = {}):
    """Links a (potentially multi-architecture) binary targeting Apple platforms.

    Args:
        ctx: The Starlark rule context.
        avoid_deps: A list of `Target`s representing dependencies of the binary but
            whose libraries should not be linked into the binary. This is the case for
            dependencies that will be found at runtime in another image, such as the
            bundle loader or any dynamic libraries/frameworks that will be loaded by
            this binary.
        build_settings: A struct with build settings info from AppleXplatToolsToolchainInfo.
        bundle_name: The name of the bundle name that the linked binary will be a part of, if any.
        cc_configured_features: A struct returned by `features_support.cc_configured_features(...)`
            to capture the rule ctx for a deferred `cc_common.configure_features(...)` call.
        cc_toolchains: Dictionary of CcToolchainInfo and ApplePlatformInfo providers under a split
            transition to relay target platform information for related deps.
        extra_linkopts: A list of strings: Extra linkopts to add to the linking action.
        extra_link_inputs: A list of strings: Extra files to pass to the linker action.
        rule_descriptor: The rule descriptor if one exists for the given rule. For convenience, This
            will define additional parameters required for linking, such as the dSYM bundle name. If
            `None`, these additional parameters will not be set on the linked binary.
        stamp: Whether to include build information in the linked binary. If 1, build
            information is always included. If 0, build information is always excluded.
            If -1 (the default), then the behavior is determined by the --[no]stamp
            flag. This should be set to 0 when generating the executable output for
            test rules.
        variables_extension: A dictionary of user-defined variables to be added to the
            toolchain configuration when create link command line.

    Returns:
        A `struct` which contains the following fields:
        *   `outputs`: A `list` of `struct`s containing the single-architecture binaries and
            debug outputs, with identifying information about the target platform, architecture,
            and environment that each was built for.
        *   `output_groups`: A `dict` with the single key `_validation` and as valuea depset
            containing the validation artifacts from the compilation contexts of the CcInfo
            providers of the targets that were linked.
    """

    # TODO: Delete when we drop bazel 7.x
    legacy_linking_function = getattr(apple_common, "link_multi_arch_binary", None)
    if legacy_linking_function:
        return legacy_linking_function(
            ctx = ctx,
            avoid_deps = avoid_deps,
            extra_linkopts = extra_linkopts,
            extra_link_inputs = extra_link_inputs,
            variables_extension = variables_extension,
            stamp = stamp,
        )

    split_deps = ctx.split_attr.deps

    if split_deps and split_deps.keys() != cc_toolchains.keys():
        fail(("Split transition keys are different between 'deps' [%s] and " +
              "'_cc_toolchain_forwarder' [%s]") % (
            split_deps.keys(),
            cc_toolchains.keys(),
        ))

    avoid_cc_linking_contexts = [
        dep[AppleDynamicFrameworkInfo].framework_linking_context
        for dep in avoid_deps
        if AppleDynamicFrameworkInfo in dep
    ]
    avoid_cc_linking_contexts.extend([
        dep[AppleExecutableBinaryInfo].binary_linking_context
        for dep in avoid_deps
        if AppleExecutableBinaryInfo in dep
    ])
    avoid_cc_linking_contexts.extend(
        [dep[CcInfo].linking_context for dep in avoid_deps if CcInfo in dep],
    )

    linker_outputs = []

    # $(location...) is only used in one test, and tokenize only affects linkopts in one target
    additional_linker_inputs = getattr(ctx.attr, "additional_linker_inputs", [])
    attr_linkopts = [
        ctx.expand_location(opt, targets = additional_linker_inputs)
        for opt in getattr(ctx.attr, "linkopts", [])
    ]
    attr_linkopts = [token for opt in attr_linkopts for token in ctx.tokenize(opt)]

    multi_arch_build = len(cc_toolchains) > 1

    for split_transition_key, child_toolchain in cc_toolchains.items():
        cc_toolchain = child_toolchain[cc_common.CcToolchainInfo]
        deps = split_deps.get(split_transition_key, [])
        platform_info = child_toolchain[ApplePlatformInfo]

        common_variables = objc_compilation_support.build_common_variables(
            ctx = ctx,
            toolchain = cc_toolchain,
            deps = deps,
            attr_linkopts = attr_linkopts,
        )

        split_linking_contexts = common_variables.objc_linking_context.cc_linking_contexts
        split_linking_contexts.extend(avoid_cc_linking_contexts)

        merged_cc_linking_context = cc_common.merge_linking_contexts(
            linking_contexts = split_linking_contexts,
        )

        subtracted_cc_linking_context = compilation_support.subtract_linking_contexts(
            owner = ctx.label,
            linking_contexts = split_linking_contexts,
            avoid_dep_linking_contexts = avoid_cc_linking_contexts,
        )

        additional_outputs = []
        extensions = {}

        dsym_output = None
        if ctx.fragments.cpp.apple_generate_dsym:
            dsym_variants = build_settings.dsym_variant_flag
            if dsym_variants == "bundle":
                if rule_descriptor:
                    dsym_bundle_name = bundle_name + rule_descriptor.bundle_extension
                else:
                    dsym_bundle_name = bundle_name

                full_dsym_bundle_name = "{dsym_bundle_name}.dSYM".format(
                    dsym_bundle_name = dsym_bundle_name,
                )

                if multi_arch_build:
                    dsym_output = intermediates.directory(
                        actions = ctx.actions,
                        target_name = bundle_name,
                        output_discriminator = cc_toolchain.target_gnu_system_name,
                        dir_name = full_dsym_bundle_name,
                    )
                else:
                    # Avoiding "intermediates" as this will be the only dSYM in a single arch build.
                    dsym_output = ctx.actions.declare_directory(
                        full_dsym_bundle_name,
                    )
            elif dsym_variants != "flat":
                fail("""
Internal Error: Found unsupported dsym_variant_flag: {dsym_variants}.

Please report this as a bug to the Apple BUILD Rules team.
                """.format(
                    dsym_variants = dsym_variants,
                ))
            else:
                main_binary_unstripped_basename = outputs.main_binary_basename(
                    bundle_name = bundle_name,
                    cpp_fragment = ctx.fragments.cpp,
                    unstripped = True,
                )
                dsym_output = intermediates.file(
                    actions = ctx.actions,
                    target_name = bundle_name,
                    output_discriminator = cc_toolchain.target_gnu_system_name,
                    file_name = "{}.dwarf".format(main_binary_unstripped_basename),
                )

            extensions["dsym_path"] = dsym_output.path  # dsym symbol file
            additional_outputs.append(dsym_output)

        linkmap = None
        if ctx.fragments.cpp.objc_generate_linkmap:
            linkmap = intermediates.file(
                actions = ctx.actions,
                target_name = ctx.label.name,
                output_discriminator = cc_toolchain.target_gnu_system_name,
                file_name = ctx.label.name + ".linkmap",
            )
            extensions["linkmap_exec_path"] = linkmap.path  # linkmap file
            additional_outputs.append(linkmap)

        main_binary_basename = outputs.main_binary_basename(
            bundle_name = bundle_name,
            cpp_fragment = ctx.fragments.cpp,
            unstripped = False,
        )

        executable = compilation_support.register_configuration_specific_link_actions(
            additional_outputs = additional_outputs,
            apple_platform_info = platform_info,
            attr_linkopts = attr_linkopts,
            bundle_name = bundle_name,
            cc_configured_features = cc_configured_features,
            cc_linking_context = subtracted_cc_linking_context,
            common_variables = common_variables,
            extra_link_args = extra_linkopts,
            extra_link_inputs = extra_link_inputs,
            name = main_binary_basename,
            # TODO: Delete when we drop Bazel 8 support (see f4a3fa40)
            split_transition_key = split_transition_key,
            stamp = stamp,
            user_variable_extensions = variables_extension | extensions,
        )

        output = {
            "binary": executable,
            "platform": platform_info.target_os,
            "architecture": platform_info.target_arch,
            "environment": platform_info.target_environment,
            "dsym_output": dsym_output,
            "linking_context": merged_cc_linking_context,
            "linkmap": linkmap,
        }

        linker_outputs.append(struct(**output))

    header_tokens = []
    for _, deps in split_deps.items():
        for dep in deps:
            if CcInfo in dep:
                header_tokens.append(dep[CcInfo].compilation_context.validation_artifacts)

    output_groups = {"_validation": depset(transitive = header_tokens)}

    return struct(
        output_groups = output_groups,
        outputs = linker_outputs,
    )

def _debug_outputs_by_architecture(link_outputs):
    """Returns debug outputs indexed by architecture from `register_binary_linking_action` output.

    Args:
        link_outputs: The dictionary of linking outputs found from the `outputs` field of
            `register_binary_linking_action`'s output struct.

    Returns:
        A `struct` containing three fields:

        *   `dsym_outputs`: A mapping of architectures to Files representing dSYM outputs for each
            architecture.
        *   `linkmaps`: A mapping of architectures to Files representing linkmaps for each
            architecture.
    """
    dsym_outputs = {}
    linkmaps = {}

    for link_output in link_outputs:
        dsym_outputs[link_output.architecture] = link_output.dsym_output
        linkmaps[link_output.architecture] = link_output.linkmap

    return struct(
        dsym_outputs = dsym_outputs,
        linkmaps = linkmaps,
    )

def _sectcreate_objc_provider(label, segname, sectname, file):
    """Returns an objc provider that propagates a section in a linked binary.

    This function creates a new objc provider that contains the necessary linkopts
    to create a new section in the binary to which the provider is propagated; it
    is equivalent to the `ld` flag `-sectcreate segname sectname file`. This can
    be used, for example, to embed entitlements in a simulator executable (since
    they are not applied during code signing).

    Args:

      label: The `Label` of the target being built. This is used as the owner
             of the linker inputs created
      segname: The name of the segment in which the section will be created.
      sectname: The name of the section to create.
      file: The file whose contents will be used as the content of the section.

    Returns:
      An objc provider that propagates the section linkopts.
    """

    # linkopts get deduped, so use a single option to pass then through as a
    # set.
    linkopts = ["-Wl,-sectcreate,%s,%s,%s" % (segname, sectname, file.path)]
    return [
        CcInfo(
            linking_context = cc_common.create_linking_context(
                linker_inputs = depset([
                    cc_common.create_linker_input(
                        owner = label,
                        user_link_flags = depset(linkopts),
                        additional_inputs = depset([file]),
                    ),
                ]),
            ),
        ),
    ]

def _register_binary_linking_action(
        ctx,
        *,
        avoid_deps = [],
        build_settings,
        bundle_name,
        bundle_loader = None,
        cc_configured_features,
        cc_toolchains,
        entitlements = None,
        exported_symbols_lists,
        extra_linkopts = [],
        extra_link_inputs = [],
        platform_prerequisites = None,
        rule_descriptor = None,
        stamp = -1):
    """Registers linking actions using the Starlark Apple binary linking API.

    This method will add the linkopts as added on the rule descriptor, in addition to any extra
    linkopts given when invoking this method.

    Args:
        ctx: The rule context.
        avoid_deps: A list of `Target`s representing dependencies of the binary but whose
            symbols should not be linked into it.
        build_settings: A struct with build settings info from AppleXplatToolsToolchainInfo.
        bundle_name: The name of the bundle name that the linked binary will be a part of, if any.
        bundle_loader: For Mach-O bundles, the `Target` whose binary will load this bundle.
            This target must propagate the `AppleExecutableBinaryInfo` provider.
            This simplifies the process of passing the bundle loader to all the arguments
            that need it: the binary will automatically be added to the linker inputs, its
            path will be added to linkopts via `-bundle_loader`, and the `apple_common.Objc`
            provider of its dependencies (obtained from the `AppleExecutableBinaryInfo` provider)
            will be passed as an additional `avoid_dep` to ensure that those dependencies are
            subtracted when linking the bundle's binary.
        cc_configured_features: A struct returned by `features_support.cc_configured_features(...)`
            to capture the rule ctx for a deferred `cc_common.configure_features(...)` call.
        cc_toolchains: Dictionary of CcToolchainInfo and ApplePlatformInfo providers under a split
            transition to relay target platform information for related deps.
        entitlements: An optional `File` that provides the processed entitlements for the
            binary or bundle being built. If the build is targeting a simulator environment,
            the entitlements will be embedded in a special section of the binary; when
            targeting non-simulator environments, this file is ignored (it is assumed that
            the entitlements will be provided during code signing).
        exported_symbols_lists: List of `File`s containing exported symbols lists for the linker
            to control symbol resolution.
        extra_linkopts: Extra linkopts to add to the linking action.
        extra_link_inputs: Extra link inputs to add to the linking action.
        platform_prerequisites: The platform prerequisites if one exists for the given rule. This
            will define additional linking sections for entitlements. If `None`, entitlements
            sections are not included.
        rule_descriptor: The rule descriptor if one exists for the given rule. For convenience, This
            will define additional parameters required for linking, such as `rpaths`. If `None`,
            these additional parameters will not be set on the linked binary.
        stamp: Whether to include build information in the linked binary. If 1, build
            information is always included. If 0, the default build information is always
            excluded. If -1, the default behavior is used, which may be overridden by the
            `--[no]stamp` flag. This should be set to 0 when generating the executable output
            for test rules.

    Returns:
        A `struct` which contains the following fields:

        *   `binary`: The final binary `File` that was linked. If only one architecture was
            requested, then it is a symlink to that single architecture binary. Otherwise, it
            is a new universal (fat) binary obtained by invoking `lipo`.
        *   `cc_info`: The CcInfo provider containing information about the targets that were
            linked.
        *   `objc`: The `apple_common.Objc` provider containing information about the targets
            that were linked.
        *   `outputs`: A `list` of `struct`s containing the single-architecture binaries and
            debug outputs, with identifying information about the target platform, architecture,
            and environment that each was built for.
        *   `output_groups`: A `dict` containing output groups that should be returned in the
            `OutputGroupInfo` provider of the calling rule.
    """
    linkopts = []
    link_inputs = []

    # Add linkopts/linker inputs that are common to all the rules.
    for exported_symbols_list in exported_symbols_lists:
        linkopts.append(
            "-Wl,-exported_symbols_list,{}".format(exported_symbols_list.path),
        )
        link_inputs.append(exported_symbols_list)

    if entitlements:
        if platform_prerequisites and platform_prerequisites.platform.is_device:
            fail("entitlements should be None when targeting a device")

        # Add an entitlements and a DER entitlements section, required of all Simulator builds that
        # define entitlements. This is never addressed by /usr/bin/codesign and must be done here.
        linkopts.append(
            "-Wl,-sectcreate,{segment},{section},{file}".format(
                segment = "__TEXT",
                section = "__entitlements",
                file = entitlements.path,
            ),
        )
        link_inputs.append(entitlements)

        der_entitlements = entitlements_support.generate_der_entitlements(
            actions = ctx.actions,
            apple_fragment = platform_prerequisites.apple_fragment,
            entitlements = entitlements,
            label_name = ctx.label.name,
            xcode_version_config = platform_prerequisites.xcode_version_config,
        )
        linkopts.append(
            "-Wl,-sectcreate,{segment},{section},{file}".format(
                segment = "__TEXT",
                section = "__ents_der",
                file = der_entitlements.path,
            ),
        )
        link_inputs.append(der_entitlements)

    # TODO(b/248317958): Migrate rule_descriptor.rpaths as direct inputs of the extra_linkopts arg
    # on this method.
    if rule_descriptor:
        linkopts.extend(["-Wl,-rpath,{}".format(rpath) for rpath in rule_descriptor.rpaths])

    linkopts.extend(extra_linkopts)
    link_inputs.extend(extra_link_inputs)

    all_avoid_deps = list(avoid_deps)
    if bundle_loader:
        bundle_loader_file = bundle_loader[AppleExecutableBinaryInfo].binary
        all_avoid_deps.append(bundle_loader)
        linkopts.extend(["-bundle_loader", bundle_loader_file.path])
        link_inputs.append(bundle_loader_file)

    linking_outputs = _link_multi_arch_binary(
        ctx = ctx,
        avoid_deps = all_avoid_deps,
        build_settings = build_settings,
        bundle_name = bundle_name,
        cc_configured_features = cc_configured_features,
        cc_toolchains = cc_toolchains,
        extra_linkopts = linkopts,
        extra_link_inputs = link_inputs,
        rule_descriptor = rule_descriptor,
        stamp = stamp,
    )

    file_ending = "_lipobin"
    if "-dynamiclib" in extra_linkopts:
        file_ending += ".dylib"

    fat_binary = ctx.actions.declare_file("{}{}".format(ctx.label.name, file_ending))

    # TODO(b/382331215): Add an optional verification check to make sure all requested architectures
    # are device or simulator. This means at constraints resolved by the cc toolchain forwarder,
    # passed down as `cc_toolchains`.

    _lipo_or_symlink_inputs(
        actions = ctx.actions,
        inputs = [output.binary for output in linking_outputs.outputs],
        output = fat_binary,
        apple_fragment = ctx.fragments.apple,
        xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
    )

    return struct(
        binary = fat_binary,
        objc = getattr(linking_outputs, "objc", None),
        outputs = linking_outputs.outputs,
        output_groups = linking_outputs.output_groups,
    )

def _register_static_library_archive_action(
        *,
        ctx,
        cc_configured_features,
        cc_toolchains):
    """Registers library archive actions using the Starlark Apple static library archive API.

    Args:
        ctx: The rule context.
        cc_configured_features: A struct returned by `features_support.cc_configured_features(...)`
            to capture the rule ctx for a deferred `cc_common.configure_features(...)` call.
        cc_toolchains: Dictionary of CcToolchainInfo and ApplePlatformInfo providers under a split
            transition to relay target platform information for related deps.

    Returns:
        A `struct` which contains the following fields:

        *   `library`: The final library `File` that was archived. If only one architecture was
            requested, then it is a symlink to that single architecture binary. Otherwise, it
            is a new universal (fat) library archive obtained by invoking `lipo`.
        *   `outputs`: A `list` of `struct`s containing the single-architecture binaries and
            debug outputs, with identifying information about the target platform, architecture,
            and environment that each was built for.
        *   `output_groups`: A `dict` containing output groups that should be returned in the
            `OutputGroupInfo` provider of the calling rule.
    """
    archive_outputs = _archive_multi_arch_static_library(
        ctx = ctx,
        cc_configured_features = cc_configured_features,
        cc_toolchains = cc_toolchains,
    )

    fat_library = ctx.actions.declare_file("{}_lipo.a".format(ctx.label.name))

    _lipo_or_symlink_inputs(
        actions = ctx.actions,
        inputs = [output.library for output in archive_outputs.outputs],
        output = fat_library,
        apple_fragment = ctx.fragments.apple,
        xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
    )

    return struct(
        library = fat_library,
        objc = getattr(archive_outputs, "objc", None),
        outputs = archive_outputs.outputs,
        output_groups = archive_outputs.output_groups,
    )

def _lipo_or_symlink_inputs(*, actions, inputs, output, apple_fragment, xcode_config):
    """Creates a fat binary with `lipo` if inputs > 1, symlinks otherwise.

    Args:
      actions: The rule context actions.
      inputs: Binary inputs to use for the lipo action.
      output: Binary output for universal binary or symlink.
      apple_fragment: The `apple` configuration fragment used to configure
                      the action environment.
      xcode_config: The `apple_common.XcodeVersionConfig` provider used to
                    configure the action environment.
    """
    if len(inputs) > 1:
        lipo.create(
            actions = actions,
            inputs = inputs,
            output = output,
            apple_fragment = apple_fragment,
            xcode_config = xcode_config,
        )
    else:
        # Symlink if there was only a single architecture created; it's faster.
        actions.symlink(target_file = inputs[0], output = output)

# TODO: Delete when we take https://github.com/bazelbuild/rules_apple/commit/29eb94cbc9b1a898582e1e238cc2551ddbeaa58b
def _legacy_link_multi_arch_binary(
        *,
        actions,
        additional_inputs = [],
        cc_toolchains,
        ctx,
        deps,
        disabled_features,
        features,
        label,
        stamp = -1,
        user_link_flags = []):
    """Experimental Starlark version of multiple architecture binary linking action.

    This Stalark version is an experimental re-write of the apple_common.link_multi_arch_binary API
    with minimal support for linking multiple architecture binaries from split dependencies.

    Specifically, this lacks support for:
        - Generating Apple dSYM binaries.
        - Generating Objective-C linkmaps.
        - Avoid linking symbols from Objective-C(++) dependencies (i.e. avoid_deps).

    Args:
        actions: The actions provider from `ctx.actions`.
        additional_inputs: List of additional `File`s required for the C++ linking action (e.g.
            linking scripts).
        cc_toolchains: Dictionary of targets (`ctx.split_attr`) containing CcToolchainInfo
            providers to use for C++ actions.
        ctx: The Starlark context for a rule target being built.
        deps: Dictionary of targets (`ctx.split_attr`) referencing dependencies for a given target
            to retrieve transitive CcInfo providers for C++ linking action.
        disabled_features: List of features to be disabled for C++ actions.
        features: List of features to be enabled for C++ actions.
        label: Label for the current target (`ctx.label`).
        stamp: Boolean to indicate whether to include build information in the linked binary.
            If 1, build information is always included.
            If 0, the default build information is always excluded.
            If -1, uses the default behavior, which may be overridden by the --[no]stamp flag.
            This should be set to 0 when generating the executable output for test rules.
        user_link_flags: List of `str` user link flags to add to the C++ linking action.
    Returns:
        A struct containing the following information:
            - cc_info: Merged CcInfo providers from each linked binary CcInfo provider.
            - output_groups: OutputGroupInfo provider with CcInfo validation artifacts.
            - outputs: List of `struct`s containing the linking output information below.
                - architecture: The target Apple architecture.
                - binary: `File` referencing the linked binary.
                - environment: The target Apple environment.
                - platform: The target Apple platform/os.
    """
    if type(deps) != "dict" or type(cc_toolchains) != "dict":
        fail(
            "Expected deps and cc_toolchains to be split attributes (dictionaries).\n",
            "deps: %s\n" % deps,
            "cc_toolchains: %s" % cc_toolchains,
        )

    if deps.keys() != cc_toolchains.keys():
        fail(
            "Expected deps and cc_toolchains split attribute keys to match",
            "deps: %s\n" % deps.keys(),
            "cc_toolchains: %s\n" % cc_toolchains.keys(),
        )

    all_cc_infos = []
    linking_outputs = []
    validation_artifacts = []
    for split_attr_key, cc_toolchain_target in cc_toolchains.items():
        cc_toolchain = cc_toolchain_target[cc_common.CcToolchainInfo]
        target_triple = cc_toolchain_info_support.get_apple_clang_triplet(cc_toolchain)

        feature_configuration = cc_common.configure_features(
            cc_toolchain = cc_toolchain,
            ctx = ctx,
            language = "objc",
            requested_features = features,
            unsupported_features = disabled_features,
        )

        cc_infos = [
            dep[CcInfo]
            for dep in deps[split_attr_key]
            if CcInfo in dep
        ]
        all_cc_infos.extend(cc_infos)

        cc_linking_contexts = [cc_info.linking_context for cc_info in cc_infos]
        output_name = "{label}_{os}_{architecture}_bin".format(
            architecture = target_triple.architecture,
            label = label.name,
            os = target_triple.os,
        )
        linking_output = cc_common.link(
            actions = actions,
            additional_inputs = additional_inputs,
            cc_toolchain = cc_toolchain,
            feature_configuration = feature_configuration,
            linking_contexts = cc_linking_contexts,
            name = output_name,
            stamp = stamp,
            user_link_flags = user_link_flags,
        )

        validation_artifacts.extend([
            cc_info.compilation_context.validation_artifacts
            for cc_info in cc_infos
        ])

        linking_outputs.append(
            struct(
                architecture = target_triple.architecture,
                binary = linking_output.executable,
                environment = target_triple.environment,
                platform = target_triple.os,
            ),
        )

    return struct(
        cc_info = cc_common.merge_cc_infos(
            cc_infos = all_cc_infos,
        ),
        output_groups = {
            "_validation": depset(
                transitive = validation_artifacts,
            ),
        },
        outputs = linking_outputs,
    )

linking_support = struct(
    debug_outputs_by_architecture = _debug_outputs_by_architecture,
    legacy_link_multi_arch_binary = _legacy_link_multi_arch_binary,
    link_multi_arch_binary = _link_multi_arch_binary,
    lipo_or_symlink_inputs = _lipo_or_symlink_inputs,
    register_binary_linking_action = _register_binary_linking_action,
    register_static_library_archive_action = _register_static_library_archive_action,
    sectcreate_objc_provider = _sectcreate_objc_provider,
)
