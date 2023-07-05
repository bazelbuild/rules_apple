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
    "@build_bazel_rules_apple//apple/internal:entitlements_support.bzl",
    "entitlements_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:cc_toolchain_info_support.bzl",
    "cc_toolchain_info_support",
)

def _debug_outputs_by_architecture(link_outputs):
    """Returns debug outputs indexed by architecture from `register_binary_linking_action` output.

    Args:
        link_outputs: The dictionary of linking outputs found from the `outputs` field of
            `register_binary_linking_action`'s output struct.

    Returns:
        A `struct` containing three fields:

        *   `dsym_binaries`: A mapping of architectures to Files representing dSYM binary outputs
            for each architecture.
        *   `linkmaps`: A mapping of architectures to Files representing linkmaps for each
            architecture.
    """
    dsym_binaries = {}
    linkmaps = {}

    for link_output in link_outputs:
        dsym_binaries[link_output.architecture] = link_output.dsym_binary
        linkmaps[link_output.architecture] = link_output.linkmap

    return struct(
        dsym_binaries = dsym_binaries,
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
        apple_common.new_objc_provider(
            linkopt = depset(linkopts, order = "topological"),
            link_inputs = depset([file]),
        ),
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
        bundle_loader = None,
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
        bundle_loader: For Mach-O bundles, the `Target` whose binary will load this bundle.
            This target must propagate the `apple_common.AppleExecutableBinary` provider.
            This simplifies the process of passing the bundle loader to all the arguments
            that need it: the binary will automatically be added to the linker inputs, its
            path will be added to linkopts via `-bundle_loader`, and the `apple_common.Objc`
            provider of its dependencies (obtained from the `AppleExecutableBinary` provider)
            will be passed as an additional `avoid_dep` to ensure that those dependencies are
            subtracted when linking the bundle's binary.
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
        A `struct` which contains the following fields, which are a superset of the fields
        returned by `apple_common.link_multi_arch_binary`:

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
        bundle_loader_file = bundle_loader[apple_common.AppleExecutableBinary].binary
        all_avoid_deps.append(bundle_loader)
        linkopts.extend(["-bundle_loader", bundle_loader_file.path])
        link_inputs.append(bundle_loader_file)

    linking_outputs = apple_common.link_multi_arch_binary(
        ctx = ctx,
        avoid_deps = all_avoid_deps,
        extra_linkopts = linkopts,
        extra_link_inputs = link_inputs,
        stamp = stamp,
    )

    file_ending = "_lipobin"
    if "-dynamiclib" in extra_linkopts:
        file_ending += ".dylib"

    fat_binary = ctx.actions.declare_file("{}{}".format(ctx.label.name, file_ending))

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
        objc = getattr(linking_outputs, "objc", None),
        outputs = linking_outputs.outputs,
        output_groups = linking_outputs.output_groups,
    )

def _register_static_library_linking_action(ctx):
    """Registers linking actions using the Starlark Apple static library linking API.

    Args:
        ctx: The rule context.

    Returns:
        A `struct` which contains the following fields, which are a superset of the fields
        returned by `apple_common.link_multi_arch_static_library`:

        *   `library`: The final library `File` that was linked. If only one architecture was
            requested, then it is a symlink to that single architecture binary. Otherwise, it
            is a new universal (fat) library obtained by invoking `lipo`.
        *   `objc`: The `apple_common.Objc` provider containing information about the targets
            that were linked.
        *   `outputs`: A `list` of `struct`s containing the single-architecture binaries and
            debug outputs, with identifying information about the target platform, architecture,
            and environment that each was built for.
        *   `output_groups`: A `dict` containing output groups that should be returned in the
            `OutputGroupInfo` provider of the calling rule.
    """
    linking_outputs = apple_common.link_multi_arch_static_library(ctx = ctx)

    fat_library = ctx.actions.declare_file("{}_lipo.a".format(ctx.label.name))

    _lipo_or_symlink_inputs(
        actions = ctx.actions,
        inputs = [output.library for output in linking_outputs.outputs],
        output = fat_library,
        apple_fragment = ctx.fragments.apple,
        xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
    )

    return struct(
        library = fat_library,
        objc = getattr(linking_outputs, "objc", None),
        outputs = linking_outputs.outputs,
        output_groups = linking_outputs.output_groups,
    )

def _lipo_or_symlink_inputs(*, actions, inputs, output, apple_fragment, xcode_config):
    """Creates a fat binary with `lipo` if inputs > 1, symlinks otherwise.

    Args:
      actions: The rule context actions.
      inputs: Binary inputs to use for lipo action.
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

def _link_multi_arch_binary(
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
    link_multi_arch_binary = _link_multi_arch_binary,
    lipo_or_symlink_inputs = _lipo_or_symlink_inputs,
    register_binary_linking_action = _register_binary_linking_action,
    register_static_library_linking_action = _register_static_library_linking_action,
    sectcreate_objc_provider = _sectcreate_objc_provider,
)
