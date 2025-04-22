# Copyright 2020 The Bazel Authors. All rights reserved.
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

"""Utility methods used for creating objc_* rules actions"""

load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@build_bazel_rules_apple//apple/internal:platform_support.bzl",
    "platform_support",
)

visibility([
    "@build_bazel_rules_apple//apple/...",
])

def _build_feature_configuration(common_variables):
    ctx = common_variables.ctx

    enabled_features = []
    enabled_features.extend(ctx.features)
    enabled_features.extend(common_variables.extra_enabled_features)

    disabled_features = []
    disabled_features.extend(ctx.disabled_features)
    disabled_features.extend(common_variables.extra_disabled_features)
    disabled_features.append("parse_headers")

    return cc_common.configure_features(
        ctx = common_variables.ctx,
        cc_toolchain = common_variables.toolchain,
        language = "objc",
        requested_features = enabled_features,
        unsupported_features = disabled_features,
    )

def _build_fully_linked_variable_extensions(*, archive, libs):
    extensions = {}
    extensions["fully_linked_archive_path"] = archive.path
    extensions["objc_library_exec_paths"] = [lib.path for lib in libs]
    extensions["cc_library_exec_paths"] = []
    extensions["imported_library_exec_paths"] = []
    return extensions

def _get_library_for_linking(library_to_link):
    if library_to_link.static_library:
        return library_to_link.static_library
    elif library_to_link.pic_static_library:
        return library_to_link.pic_static_library
    elif library_to_link.interface_library:
        return library_to_link.interface_library
    else:
        return library_to_link.dynamic_library

def _libraries_from_linking_context(linking_context):
    libraries = []
    for linker_input in linking_context.linker_inputs.to_list():
        libraries.extend(linker_input.libraries)
    return depset(libraries, order = "topological")

def _get_libraries_for_linking(libraries_to_link):
    libraries = []
    for library_to_link in libraries_to_link:
        libraries.append(_get_library_for_linking(library_to_link))
    return libraries

def _register_fully_link_action(*, cc_linking_context, common_variables, name):
    ctx = common_variables.ctx
    feature_configuration = _build_feature_configuration(common_variables)

    libraries_to_link = _libraries_from_linking_context(cc_linking_context).to_list()
    libraries = _get_libraries_for_linking(libraries_to_link)

    output_archive = ctx.actions.declare_file(name + ".a")
    extensions = _build_fully_linked_variable_extensions(
        archive = output_archive,
        libs = libraries,
    )

    return cc_common.link(
        actions = ctx.actions,
        additional_inputs = libraries,
        cc_toolchain = common_variables.toolchain,
        feature_configuration = feature_configuration,
        language = "objc",
        name = name,
        output_type = "archive",
        variables_extension = extensions,
    )

def _register_binary_strip_action(
        *,
        ctx,
        apple_platform_info,
        binary,
        extra_link_args,
        feature_configuration,
        name):
    """
    Registers an action that uses the 'strip' tool to perform binary stripping on the given binary.
    """

    strip_safe = ctx.fragments.objc.strip_executable_safely

    # For dylibs, loadable bundles, and kexts, must strip only local symbols.
    link_dylib = cc_common.is_enabled(
        feature_configuration = feature_configuration,
        feature_name = "link_dylib",
    )
    link_bundle = cc_common.is_enabled(
        feature_configuration = feature_configuration,
        feature_name = "link_bundle",
    )
    if ("-dynamiclib" in extra_link_args or link_dylib or
        "-bundle" in extra_link_args or link_bundle or "-kext" in extra_link_args):
        strip_safe = True

    # TODO(b/331163513): Use intermediates.file() instead of declare_shareable_artifact().
    stripped_binary = ctx.actions.declare_shareable_artifact(
        paths.join(ctx.label.package, name),
        apple_platform_info.target_build_config.bin_dir,
    )
    args = ctx.actions.args()
    args.add("strip")
    if strip_safe:
        args.add("-x")
    args.add("-o", stripped_binary)
    args.add(binary)
    xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]
    apple_common_platform = platform_support.apple_common_platform_from_platform_info(
        apple_platform_info = apple_platform_info,
    )

    ctx.actions.run(
        arguments = [args],
        env = apple_common.apple_host_system_env(xcode_config) |
              apple_common.target_apple_env(xcode_config, apple_common_platform),
        executable = "/usr/bin/xcrun",
        execution_requirements = xcode_config.execution_info(),
        inputs = [binary],
        mnemonic = "ObjcBinarySymbolStrip",
        outputs = [stripped_binary],
    )
    return stripped_binary

def _emit_builtin_objc_strip_action(ctx):
    return (
        ctx.fragments.objc.builtin_objc_strip_action and
        ctx.fragments.cpp.objc_enable_binary_stripping() and
        ctx.fragments.cpp.compilation_mode() == "opt"
    )

def _register_configuration_specific_link_actions(
        *,
        additional_outputs,
        apple_platform_info,
        attr_linkopts,
        common_variables,
        cc_linking_context,
        extra_link_args,
        extra_link_inputs,
        name,
        stamp,
        user_variable_extensions):
    """
    Registers actions to link a single-platform/architecture Apple binary in a specific config.

    Registers any actions necessary to link this rule and its dependencies. Automatically infers
    the toolchain from the configuration.

    Returns:
        (File) the linked binary
    """
    ctx = common_variables.ctx
    feature_configuration = _build_feature_configuration(common_variables)

    # When compilation_mode=opt and objc_enable_binary_stripping are specified, the unstripped
    # binary containing debug symbols is generated by the linker, which also needs the debug
    # symbols for dead-code removal. The binary is also used to generate dSYM bundle if
    # --apple_generate_dsym is specified. A symbol strip action is later registered to strip
    # the symbol table from the unstripped binary.
    if _emit_builtin_objc_strip_action(ctx):
        # TODO(b/331163513): Use intermediates.file() instead of declare_shareable_artifact().
        binary = ctx.actions.declare_shareable_artifact(
            paths.join(ctx.label.package, name + "_unstripped"),
            apple_platform_info.target_build_config.bin_dir,
        )
    else:
        # TODO(b/331163513): Use intermediates.file() instead of declare_shareable_artifact().
        binary = ctx.actions.declare_shareable_artifact(
            paths.join(ctx.label.package, name),
            apple_platform_info.target_build_config.bin_dir,
        )

    prefixed_attr_linkopts = [
        "-Wl,%s" % linkopt
        for linkopt in attr_linkopts
    ]

    seen_flags = {}
    (_, user_link_flags, seen_flags) = _dedup_link_flags(
        flags = extra_link_args + prefixed_attr_linkopts,
        seen_flags = seen_flags,
    )
    cc_linking_context = _create_deduped_linkopts_linking_context(
        cc_linking_context = cc_linking_context,
        owner = ctx.label,
        seen_flags = seen_flags,
    )

    cc_common.link(
        actions = ctx.actions,
        additional_inputs = (
            extra_link_inputs +
            getattr(ctx.files, "additional_linker_inputs", [])
        ),
        additional_outputs = additional_outputs,
        build_config = apple_platform_info.target_build_config,
        cc_toolchain = common_variables.toolchain,
        feature_configuration = feature_configuration,
        language = "objc",
        linking_contexts = [cc_linking_context],
        main_output = binary,
        name = name,
        output_type = "executable",
        stamp = stamp,
        user_link_flags = user_link_flags,
        variables_extension = user_variable_extensions,
    )

    if _emit_builtin_objc_strip_action(ctx):
        return _register_binary_strip_action(
            ctx = ctx,
            apple_platform_info = apple_platform_info,
            binary = binary,
            extra_link_args = extra_link_args,
            feature_configuration = feature_configuration,
            name = name,
        )
    else:
        return binary

def _dedup_link_flags(*, flags, seen_flags = {}):
    new_flags = []
    previous_arg = None
    for arg in flags:
        if previous_arg in ["-framework", "-weak_framework"]:
            framework = arg
            key = previous_arg[1] + framework
            if key not in seen_flags:
                new_flags.extend([previous_arg, framework])
                seen_flags[key] = True
            previous_arg = None
        elif arg in ["-framework", "-weak_framework"]:
            previous_arg = arg
        elif arg.startswith("-Wl,-framework,") or arg.startswith("-Wl,-weak_framework,"):
            framework = arg.split(",")[2]
            key = arg[5] + framework
            if key not in seen_flags:
                new_flags.extend([arg.split(",")[1], framework])
                seen_flags[key] = True
        elif arg.startswith("-Wl,-rpath,"):
            rpath = arg.split(",")[2]
            key = arg[5] + rpath
            if key not in seen_flags:
                new_flags.append(arg)
                seen_flags[key] = True
        elif arg.startswith("-l"):
            if arg not in seen_flags:
                new_flags.append(arg)
                seen_flags[arg] = True
        else:
            new_flags.append(arg)

    same = (
        len(flags) == len(new_flags) and
        all([flags[i] == new_flags[i] for i in range(0, len(flags))])
    )

    return (same, new_flags, seen_flags)

def _create_deduped_linkopts_linking_context(*, cc_linking_context, owner, seen_flags):
    linker_inputs = []
    for linker_input in cc_linking_context.linker_inputs.to_list():
        (same, new_flags, seen_flags) = _dedup_link_flags(
            flags = linker_input.user_link_flags,
            seen_flags = seen_flags,
        )
        if same:
            linker_inputs.append(linker_input)
        else:
            linker_inputs.append(cc_common.create_linker_input(
                additional_inputs = depset(linker_input.additional_inputs),
                libraries = depset(linker_input.libraries),
                owner = linker_input.owner,
                user_link_flags = new_flags,
            ))

    # Why does linker_input not expose linkstamp?  This needs to be fixed.
    linker_inputs.append(cc_common.create_linker_input(
        linkstamps = cc_linking_context.linkstamps(),
        owner = owner,
    ))

    return cc_common.create_linking_context(linker_inputs = depset(linker_inputs))

compilation_support = struct(
    # TODO(b/331163513): Move apple_common.compliation_support.build_common_variables here, too.
    register_fully_link_action = _register_fully_link_action,
    register_configuration_specific_link_actions = _register_configuration_specific_link_actions,
)
