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
load(
    "@build_bazel_rules_apple//apple/internal:compilation_support.bzl",
    "compilation_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:entitlements_support.bzl",
    "entitlements_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/internal:multi_arch_binary_support.bzl",
    "subtract_linking_contexts",
)
load(
    "@build_bazel_rules_apple//apple/internal:outputs.bzl",
    "outputs",
)
load(
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "AppleExecutableBinaryInfo",
    "ApplePlatformInfo",
    "new_appledebugoutputsinfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/providers:apple_dynamic_framework_info.bzl",
    "AppleDynamicFrameworkInfo",
)

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

_DENIED_VERIFY_PLATFORM_VARIANTS_USERS = []

def _archive_multi_arch_static_library(
        *,
        ctx,
        cc_toolchains):
    """Generates a (potentially multi-architecture) static library archive for Apple platforms.

    Rule context is a required parameter due to usage of the cc_common.configure_features API.

    Args:
        ctx: The Starlark rule context.
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

    split_deps = ctx.split_attr.deps
    split_avoid_deps = ctx.split_attr.avoid_deps

    outputs = []

    for split_transition_key, child_toolchain in cc_toolchains.items():
        cc_toolchain = child_toolchain[cc_common.CcToolchainInfo]
        common_variables = apple_common.compilation_support.build_common_variables(
            ctx = ctx,
            toolchain = cc_toolchain,
            use_pch = True,
            deps = split_deps[split_transition_key],
        )

        avoid_objc_providers = []
        avoid_cc_providers = []
        avoid_cc_linking_contexts = []

        if len(split_avoid_deps.keys()):
            for dep in split_avoid_deps[split_transition_key]:
                if apple_common.Objc in dep:
                    avoid_objc_providers.append(dep[apple_common.Objc])
                if CcInfo in dep:
                    avoid_cc_providers.append(dep[CcInfo])
                    avoid_cc_linking_contexts.append(dep[CcInfo].linking_context)

        name = ctx.label.name + "-" + cc_toolchain.target_gnu_system_name + "-fl"

        cc_linking_context = subtract_linking_contexts(
            owner = ctx.label,
            linking_contexts = common_variables.objc_linking_context.cc_linking_contexts,
            avoid_dep_linking_contexts = avoid_cc_linking_contexts,
        )
        linking_outputs = compilation_support.register_fully_link_action(
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
        cc_toolchains,
        extra_linkopts = [],
        extra_link_inputs = [],
        extra_requested_features = [],
        extra_disabled_features = [],
        rule_descriptor,
        stamp = -1,
        variables_extension = {}):
    """Links a (potentially multi-architecture) binary targeting Apple platforms.

    This method comprises a bulk of the logic of the Starlark `apple_binary`
    rule in the rules_apple domain and exists to aid in the migration of its
    linking logic to Starlark in rules_apple.

    This API is **highly experimental** and subject to change at any time. Do
    not depend on the stability of this function at this time.

    Args:
        ctx: The Starlark rule context.
        avoid_deps: A list of `Target`s representing dependencies of the binary but
            whose libraries should not be linked into the binary. This is the case for
            dependencies that will be found at runtime in another image, such as the
            bundle loader or any dynamic libraries/frameworks that will be loaded by
            this binary.
        build_settings: A struct with build settings info from AppleXplatToolsToolchainInfo.
        cc_toolchains: Dictionary of CcToolchainInfo and ApplePlatformInfo providers under a split
            transition to relay target platform information for related deps.
        extra_linkopts: A list of strings: Extra linkopts to add to the linking action.
        extra_link_inputs: A list of strings: Extra files to pass to the linker action.
        extra_requested_features: A list of strings: Extra requested features to be passed
            to the linker action.
        extra_disabled_features: A list of strings: Extra disabled features to be passed
            to the linker action.
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
        *   `cc_info`: The CcInfo provider containing information about the targets that were
            linked.
        *   `outputs`: A `list` of `struct`s containing the single-architecture binaries and
            debug outputs, with identifying information about the target platform, architecture,
            and environment that each was built for.
        *   `output_groups`: A `dict` with the single key `_validation` and as valuea depset
            containing the validation artifacts from the compilation contexts of the CcInfo
            providers of the targets that were linked.
        *   `debug_outputs_provider`: An AppleDebugOutputs provider
    """

    split_deps = ctx.split_attr.deps

    if split_deps and split_deps.keys() != cc_toolchains.keys():
        fail(("Split transition keys are different between 'deps' [%s] and " +
              "'_cc_toolchain_forwarder' [%s]") % (
            split_deps.keys(),
            cc_toolchains.keys(),
        ))

    avoid_cc_infos = [
        dep[AppleDynamicFrameworkInfo].cc_info
        for dep in avoid_deps
        if AppleDynamicFrameworkInfo in dep
    ]
    avoid_cc_infos.extend([
        dep[AppleExecutableBinaryInfo].cc_info
        for dep in avoid_deps
        if AppleExecutableBinaryInfo in dep
    ])
    avoid_cc_infos.extend([dep[CcInfo] for dep in avoid_deps if CcInfo in dep])
    avoid_cc_linking_contexts = [dep.linking_context for dep in avoid_cc_infos]

    linker_outputs = []
    cc_infos = []
    legacy_debug_outputs = {}

    cc_infos.extend(avoid_cc_infos)

    # $(location...) is only used in one test, and tokenize only affects linkopts in one target
    additional_linker_inputs = getattr(ctx.attr, "additional_linker_inputs", [])
    attr_linkopts = [
        ctx.expand_location(opt, targets = additional_linker_inputs)
        for opt in getattr(ctx.attr, "linkopts", [])
    ]
    attr_linkopts = [token for opt in attr_linkopts for token in ctx.tokenize(opt)]

    for split_transition_key, child_toolchain in cc_toolchains.items():
        cc_toolchain = child_toolchain[cc_common.CcToolchainInfo]
        deps = split_deps.get(split_transition_key, [])
        platform_info = child_toolchain[ApplePlatformInfo]

        common_variables = apple_common.compilation_support.build_common_variables(
            ctx = ctx,
            toolchain = cc_toolchain,
            deps = deps,
            extra_disabled_features = extra_disabled_features,
            extra_enabled_features = extra_requested_features,
            attr_linkopts = attr_linkopts,
        )

        cc_infos.append(CcInfo(
            compilation_context = cc_common.merge_compilation_contexts(
                compilation_contexts =
                    common_variables.objc_compilation_context.cc_compilation_contexts,
            ),
            linking_context = cc_common.merge_linking_contexts(
                linking_contexts = common_variables.objc_linking_context.cc_linking_contexts,
            ),
        ))

        cc_linking_context = subtract_linking_contexts(
            owner = ctx.label,
            linking_contexts = common_variables.objc_linking_context.cc_linking_contexts +
                               avoid_cc_linking_contexts,
            avoid_dep_linking_contexts = avoid_cc_linking_contexts,
        )

        additional_outputs = []
        extensions = {}

        dsym_output = None
        if ctx.fragments.cpp.apple_generate_dsym:
            dsym_variants = build_settings.dsym_variant_flag
            if dsym_variants == "bundle":
                if rule_descriptor:
                    dsym_bundle_name = ctx.label.name + rule_descriptor.bundle_extension
                else:
                    dsym_bundle_name = ctx.label.name

                # Avoiding "intermediates" as this will be the canonical dSYM in a single arch build
                dsym_output = ctx.actions.declare_directory(
                    "{split_transition_key}/{dsym_bundle_name}.dSYM".format(
                        split_transition_key = split_transition_key,
                        dsym_bundle_name = dsym_bundle_name,
                    ),
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
                    cpp_fragment = ctx.fragments.cpp,
                    label_name = ctx.label.name,
                    unstripped = True,
                )
                dsym_output = intermediates.file(
                    actions = ctx.actions,
                    target_name = ctx.label.name,
                    output_discriminator = split_transition_key,
                    file_name = "{}.dwarf".format(main_binary_unstripped_basename),
                )

                # TODO(b/391401130): Remove this once all users are migrated to the downstream
                # provider AppleDsymBundleInfo.
                legacy_debug_outputs.setdefault(
                    platform_info.target_arch,
                    {},
                )["dsym_binary"] = dsym_output

            extensions["dsym_path"] = dsym_output.path  # dsym symbol file
            additional_outputs.append(dsym_output)

        linkmap = None
        if ctx.fragments.cpp.objc_generate_linkmap:
            linkmap = intermediates.file(
                actions = ctx.actions,
                target_name = ctx.label.name,
                output_discriminator = split_transition_key,
                file_name = ctx.label.name + ".linkmap",
            )
            extensions["linkmap_exec_path"] = linkmap.path  # linkmap file
            additional_outputs.append(linkmap)
            legacy_debug_outputs.setdefault(platform_info.target_arch, {})["linkmap"] = linkmap

        main_binary_basename = outputs.main_binary_basename(
            cpp_fragment = ctx.fragments.cpp,
            label_name = ctx.label.name,
            unstripped = False,
        )

        executable = compilation_support.register_configuration_specific_link_actions(
            additional_outputs = additional_outputs,
            apple_platform_info = platform_info,
            attr_linkopts = attr_linkopts,
            common_variables = common_variables,
            cc_linking_context = cc_linking_context,
            extra_link_args = extra_linkopts,
            extra_link_inputs = extra_link_inputs,
            name = main_binary_basename,
            stamp = stamp,
            user_variable_extensions = variables_extension | extensions,
        )

        output = {
            "binary": executable,
            "platform": platform_info.target_os,
            "architecture": platform_info.target_arch,
            "environment": platform_info.target_environment,
            "dsym_output": dsym_output,
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
        cc_info = cc_common.merge_cc_infos(direct_cc_infos = cc_infos),
        output_groups = output_groups,
        outputs = linker_outputs,
        debug_outputs_provider = new_appledebugoutputsinfo(outputs_map = legacy_debug_outputs),
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

def _sectcreate_cc_info(segname, sectname, file):
    """Returns a CcInfo that propagates a section in a linked binary.

    This function creates a new CcInfo that contains the necessary linkopts
    to create a new section in the binary to which the provider is propagated; it
    is equivalent to the `ld` flag `-sectcreate segname sectname file`. This can
    be used, for example, to embed entitlements in a simulator executable (since
    they are not applied during code signing).

    Args:
      segname: The name of the segment in which the section will be created.
      sectname: The name of the section to create.
      file: The file whose contents will be used as the content of the section.

    Returns:
      A CcInfo that propagates the section linkopts.
    """

    linkopts = ["-Wl,-sectcreate,%s,%s,%s" % (segname, sectname, file.path)]
    return [
        CcInfo(
            linking_context = cc_common.create_linking_context(
                user_link_flags = linkopts,
                additional_inputs = [file],
            ),
        ),
    ]

def _validate_platform_variants(*, cc_toolchains, label):
    """Validates that all requested architectures are device or simulator."""
    full_label_package = "//{}/".format(label.package)
    for denied_user in _DENIED_VERIFY_PLATFORM_VARIANTS_USERS:
        if full_label_package.startswith(denied_user):
            return
    expected_environment = None
    for split_transition_key, child_toolchain in cc_toolchains.items():
        actual_environment = child_toolchain[ApplePlatformInfo].target_environment
        if expected_environment != actual_environment:
            if expected_environment == None:
                expected_environment = actual_environment
            else:
                fail("""
ERROR: Attempted to build a fat binary with the following platforms, but their environments \
(device or simulator) are not consistent:

{split_transition_keys}

First mismatched environment was {actual_environment} from {split_transition_key}.

Expected all environments to be {expected_environment}.

All requested architectures must be either device or simulator architectures.""".format(
                    actual_environment = actual_environment,
                    expected_environment = expected_environment,
                    split_transition_key = split_transition_key,
                    split_transition_keys = ", ".join(cc_toolchains.keys()),
                ))

def _register_binary_linking_action(
        ctx,
        *,
        avoid_deps = [],
        build_settings,
        bundle_loader = None,
        cc_toolchains,
        entitlements = None,
        exported_symbols_lists = [],
        extra_link_inputs = [],
        extra_linkopts = [],
        extra_requested_features = [],
        extra_disabled_features = [],
        platform_prerequisites = None,
        rule_descriptor = None,
        stamp = -1,
        verify_platform_variants = True):
    """Registers linking actions using the Starlark Apple binary linking API.

    This method will add the linkopts as added on the rule descriptor, in addition to any extra
    linkopts given when invoking this method.

    Args:
        ctx: The rule context.
        avoid_deps: A list of `Target`s representing dependencies of the binary but whose
            symbols should not be linked into it.
        build_settings: A struct with build settings info from AppleXplatToolsToolchainInfo.
        bundle_loader: For Mach-O bundles, the `Target` whose binary will load this bundle.
            This target must propagate the `AppleExecutableBinaryInfo` provider.
            This simplifies the process of passing the bundle loader to all the arguments
            that need it: the binary will automatically be added to the linker inputs, its
            path will be added to linkopts via `-bundle_loader`, and the `apple_common.Objc`
            provider of its dependencies (obtained from the `AppleExecutableBinaryInfo` provider)
            will be passed as an additional `avoid_dep` to ensure that those dependencies are
            subtracted when linking the bundle's binary.
        cc_toolchains: Dictionary of CcToolchainInfo and ApplePlatformInfo providers under a split
            transition to relay target platform information for related deps.
        entitlements: An optional `File` that provides the processed entitlements for the
            binary or bundle being built. If the build is targeting a simulator environment,
            the entitlements will be embedded in a special section of the binary; when
            targeting non-simulator environments, this file is ignored (it is assumed that
            the entitlements will be provided during code signing).
        exported_symbols_lists: List of `File`s containing exported symbols lists for the linker
            to control symbol resolution.
        extra_link_inputs: Extra Files to add to the linking action, expected to be referenced via
            extra_linkopts.
        extra_linkopts: Extra linkopts to add to the linking action.
        extra_requested_features: Extra features as Strings requested of the underlying linker
            action.
        extra_disabled_features: Extra features as Strings requeted to be disabled from the
            underlying linker action.
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
        verify_platform_variants: Whether to verify that all requested architectures are device or
            simulator. True by default.

    Returns:
        A `struct` which contains the following fields:

        *   `binary`: The final binary `File` that was linked. If only one architecture was
            requested, then it is a symlink to that single architecture binary. Otherwise, it
            is a new universal (fat) binary obtained by invoking `lipo`.
        *   `cc_info`: The CcInfo provider containing information about the targets that were
            linked.
        *   `outputs`: A `list` of `struct`s containing the single-architecture binaries and
            debug outputs, with identifying information about the target platform, architecture,
            and environment that each was built for.
        *   `output_groups`: A `dict` containing output groups that should be returned in the
            `OutputGroupInfo` provider of the calling rule.
        *   `debug_outputs_provider`: An AppleDebugOutputs provider
    """
    if verify_platform_variants:
        _validate_platform_variants(cc_toolchains = cc_toolchains, label = ctx.label)

    linkopts = []
    link_inputs = []

    # Add linkopts/linker inputs that are common to all the rules.
    for exported_symbols_list in exported_symbols_lists:
        linkopts.append(
            "-Wl,-exported_symbols_list,{}".format(exported_symbols_list.path),
        )
        link_inputs.append(exported_symbols_list)

    if entitlements and platform_prerequisites and not platform_prerequisites.platform.is_device:
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

    if platform_prerequisites and platform_prerequisites.uses_swift:
        linkopts.append("-Wl,-rpath,/usr/lib/swift")

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
        cc_toolchains = cc_toolchains,
        extra_linkopts = linkopts,
        extra_link_inputs = link_inputs,
        extra_requested_features = extra_requested_features,
        # TODO(321109350): Disable include scanning to work around issue with GrepIncludes actions
        # being routed to the wrong exec platform.
        extra_disabled_features = extra_disabled_features + ["cc_include_scanning"],
        rule_descriptor = rule_descriptor,
        stamp = stamp,
    )

    fat_binary = ctx.actions.declare_file("{}_lipobin".format(ctx.label.name))

    _lipo_or_symlink_inputs(
        actions = ctx.actions,
        inputs = [output.binary for output in linking_outputs.outputs],
        output = fat_binary,
        apple_fragment = ctx.fragments.apple,
        xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
    )

    return struct(
        binary = fat_binary,
        cc_info = linking_outputs.cc_info,
        debug_outputs_provider = linking_outputs.debug_outputs_provider,
        outputs = linking_outputs.outputs,
        output_groups = linking_outputs.output_groups,
    )

def _register_static_library_archive_action(
        *,
        ctx,
        cc_toolchains,
        verify_platform_variants = True):
    """Registers library archive actions using the Starlark Apple static library archive API.

    Args:
        ctx: The rule context.
        cc_toolchains: Dictionary of CcToolchainInfo and ApplePlatformInfo providers under a split
            transition to relay target platform information for related deps.
        verify_platform_variants: Whether to verify that all requested architectures are device or
            simulator. True by default.

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
    if verify_platform_variants:
        _validate_platform_variants(cc_toolchains = cc_toolchains, label = ctx.label)

    archive_outputs = _archive_multi_arch_static_library(
        ctx = ctx,
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

linking_support = struct(
    debug_outputs_by_architecture = _debug_outputs_by_architecture,
    lipo_or_symlink_inputs = _lipo_or_symlink_inputs,
    register_binary_linking_action = _register_binary_linking_action,
    register_static_library_archive_action = _register_static_library_archive_action,
    sectcreate_cc_info = _sectcreate_cc_info,
)
