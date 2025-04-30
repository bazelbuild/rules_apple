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

load("@bazel_features//:features.bzl", "bazel_features")
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@rules_cc//cc/common:cc_common.bzl",
    "cc_common",
)
load(
    "//apple/internal:fragment_support.bzl",
    "fragment_support",
)
load(
    "//apple/internal:outputs.bzl",
    "outputs",
)
load(
    "//apple/internal:platform_support.bzl",
    "platform_support",
)

visibility([
    "//apple/...",
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

def _get_static_library_for_linking(library_to_link):
    if library_to_link.static_library:
        return library_to_link.static_library
    elif library_to_link.pic_static_library:
        return library_to_link.pic_static_library
    else:
        return None

def _get_library_for_linking(library_to_link):
    if library_to_link.static_library:
        return library_to_link.static_library
    elif library_to_link.pic_static_library:
        return library_to_link.pic_static_library
    elif library_to_link.interface_library:
        return library_to_link.interface_library
    else:
        return library_to_link.dynamic_library

def _build_avoid_library_set(avoid_dep_linking_contexts):
    avoid_library_set = dict()
    for linking_context in avoid_dep_linking_contexts:
        for linker_input in linking_context.linker_inputs.to_list():
            for library_to_link in linker_input.libraries:
                library_artifact = _get_static_library_for_linking(library_to_link)
                if library_artifact:
                    avoid_library_set[library_artifact.short_path] = True
    return avoid_library_set

def _subtract_linking_contexts(owner, linking_contexts, avoid_dep_linking_contexts):
    """Subtracts the libraries in avoid_dep_linking_contexts from linking_contexts.

    Args:
      owner: The label of the target currently being analyzed.
      linking_contexts: An iterable of CcLinkingContext objects.
      avoid_dep_linking_contexts: An iterable of CcLinkingContext objects.

    Returns:
      A CcLinkingContext object.
    """
    libraries = []
    user_link_flags = []
    additional_inputs = []
    linkstamps = []
    avoid_library_set = _build_avoid_library_set(avoid_dep_linking_contexts)
    for linking_context in linking_contexts:
        for linker_input in linking_context.linker_inputs.to_list():
            for library_to_link in linker_input.libraries:
                library_artifact = _get_library_for_linking(library_to_link)
                if library_artifact.short_path not in avoid_library_set:
                    libraries.append(library_to_link)
            user_link_flags.extend(linker_input.user_link_flags)
            additional_inputs.extend(linker_input.additional_inputs)
            linkstamps.extend(linker_input.linkstamps)
    linker_input = cc_common.create_linker_input(
        owner = owner,
        libraries = depset(libraries, order = "topological"),
        user_link_flags = user_link_flags,
        additional_inputs = depset(additional_inputs),
        linkstamps = depset(linkstamps),
    )
    return cc_common.create_linking_context(
        linker_inputs = depset([linker_input]),
        owner = owner,
    )

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

# TODO: Delete when we drop Bazel 8 support (see f4a3fa40)
def _register_obj_filelist_action(*, apple_platform_info, ctx, obj_files, split_transition_key):
    """
    Returns a File containing the given set of object files.

    This File is suitable to signal symbols to archive in a libtool archiving invocation.
    """
    obj_list = ctx.actions.declare_shareable_artifact(
        paths.join(
            ctx.label.package,
            ctx.label.name + "-intermediates-" + split_transition_key,
            ctx.label.name + "-linker.objlist",
        ),
        apple_platform_info.target_build_config.bin_dir,
    )

    args = ctx.actions.args()
    args.add_all(obj_files)
    args.set_param_file_format("multiline")
    ctx.actions.write(obj_list, args)

    return obj_list

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

    stripped_binary = outputs.main_binary(
        actions = ctx.actions,
        apple_platform_info = apple_platform_info,
        cpp_fragment = ctx.fragments.cpp,
        label = ctx.label,
        unstripped = False,
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

# TODO: Delete when we drop Bazel 8 support (see f4a3fa40)
def _create_deduped_linkopts_list(linker_inputs):
    seen_flags = {}
    final_linkopts = []
    for linker_input in linker_inputs.to_list():
        (_, new_flags, seen_flags) = _dedup_link_flags(
            flags = linker_input.user_link_flags,
            seen_flags = seen_flags,
        )
        final_linkopts.extend(new_flags)

    return final_linkopts

# TODO: Delete when we drop Bazel 8 support (see f4a3fa40)
def _linkstamp_map(*, apple_platform_info, ctx, linkstamps, output):
    # create linkstamps_map - mapping from linkstamps to object files
    linkstamps_map = {}

    stamp_output_dir = paths.join(ctx.label.package, "_objs", output.basename)
    for linkstamp in linkstamps.to_list():
        linkstamp_file = linkstamp.file()
        stamp_output_path = paths.join(
            stamp_output_dir,
            linkstamp_file.short_path[:-len(linkstamp_file.extension)].rstrip(".") + ".o",
        )
        stamp_output_file = ctx.actions.declare_shareable_artifact(
            stamp_output_path,
            apple_platform_info.target_build_config.bin_dir,
        )
        linkstamps_map[linkstamp_file] = stamp_output_file
    return linkstamps_map

# TODO: Delete when we drop Bazel 8 support (see f4a3fa40)
def _classify_libraries(libraries_to_link):
    always_link_libraries = {
        lib: None
        for lib in _get_libraries_for_linking(
            [lib for lib in libraries_to_link if lib.alwayslink],
        )
    }
    as_needed_libraries = {
        lib: None
        for lib in _get_libraries_for_linking(
            [lib for lib in libraries_to_link if not lib.alwayslink],
        )
        if lib not in always_link_libraries
    }
    return always_link_libraries.keys(), as_needed_libraries.keys()

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
        split_transition_key,
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

    # TODO: Remove when we drop Bazel 8
    if bazel_features.cc.objc_fragment_has_builtin_objc_strip_action:
        unstripped = ctx.fragments.objc.builtin_objc_strip_action
    else:
        unstripped = False

    binary = outputs.main_binary(
        actions = ctx.actions,
        apple_platform_info = apple_platform_info,
        cpp_fragment = ctx.fragments.cpp,
        label = ctx.label,
        unstripped = unstripped,
    )

    # TODO: Delete feature check and else branch when we drop Bazel 8 support (see f4a3fa40)
    if cc_common.is_enabled(
        feature_configuration = feature_configuration,
        feature_name = "use_cpp_variables_for_objc_executable",
    ):
        return _register_configuration_specific_link_actions_with_cpp_variables(
            additional_outputs = additional_outputs,
            apple_platform_info = apple_platform_info,
            attr_linkopts = attr_linkopts,
            binary = binary,
            cc_linking_context = cc_linking_context,
            common_variables = common_variables,
            extra_link_args = extra_link_args,
            extra_link_inputs = extra_link_inputs,
            feature_configuration = feature_configuration,
            name = name,
            stamp = stamp,
            user_variable_extensions = user_variable_extensions,
        )
    else:
        return _register_configuration_specific_link_actions_with_objc_variables(
            additional_outputs = additional_outputs,
            apple_platform_info = apple_platform_info,
            attr_linkopts = attr_linkopts,
            binary = binary,
            cc_linking_context = cc_linking_context,
            common_variables = common_variables,
            extra_link_args = extra_link_args,
            extra_link_inputs = extra_link_inputs,
            feature_configuration = feature_configuration,
            name = name,
            split_transition_key = split_transition_key,
            stamp = stamp,
            user_variable_extensions = user_variable_extensions,
        )

def _register_configuration_specific_link_actions_with_cpp_variables(
        *,
        additional_outputs,
        apple_platform_info,
        attr_linkopts,
        binary,
        cc_linking_context,
        common_variables,
        extra_link_args,
        extra_link_inputs,
        feature_configuration,
        name,
        stamp,
        user_variable_extensions):
    ctx = common_variables.ctx

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

    # TODO: Remove bazel_features check when we drop Baze 8
    if bazel_features.cc.objc_fragment_has_builtin_objc_strip_action and \
       fragment_support.is_objc_strip_action_enabled(
           cpp_fragment = ctx.fragments.cpp,
       ) and \
       ctx.fragments.objc.builtin_objc_strip_action:
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

# TODO: Delete when we drop Bazel 8 support (see f4a3fa40)
def _register_configuration_specific_link_actions_with_objc_variables(
        *,
        additional_outputs,
        apple_platform_info,
        attr_linkopts,
        binary,
        cc_linking_context,
        common_variables,
        extra_link_args,
        extra_link_inputs,
        feature_configuration,
        name,
        split_transition_key,
        stamp,
        user_variable_extensions):
    ctx = common_variables.ctx

    # We need to split input libraries into those that require -force_load and those that don't.
    # Clang loads archives specified in filelists and also specified as -force_load twice,
    # resulting in duplicate symbol errors unless they are deduped.
    libraries_to_link = _libraries_from_linking_context(cc_linking_context).to_list()
    always_link_libraries, as_needed_libraries = _classify_libraries(libraries_to_link)

    static_runtimes = common_variables.toolchain.static_runtime_lib(
        feature_configuration = feature_configuration,
    )

    # Passing large numbers of inputs on the command line triggers a bug in Apple's Clang
    # (b/29094356), so we'll create an input list manually and pass -filelist path/to/input/list.

    # Populate the input file list with both the compiled object files and any linkstamp object
    # files.
    # There's some weirdness: cc_common.link compiles linkstamps and does the linking (without ever
    # returning linkstamp objects)
    # We replicate the linkstamp objects names (guess them) and generate input_file_list
    # which is input to linking action.
    linkstamp_map = _linkstamp_map(
        apple_platform_info = apple_platform_info,
        ctx = ctx,
        linkstamps = cc_linking_context.linkstamps(),
        output = binary,
    )
    input_file_list = _register_obj_filelist_action(
        apple_platform_info = apple_platform_info,
        ctx = ctx,
        obj_files = as_needed_libraries + static_runtimes.to_list() + linkstamp_map.values(),
        split_transition_key = split_transition_key,
    )

    extensions = user_variable_extensions | {
        "framework_paths": [],
        "framework_names": [],
        "weak_framework_names": [],
        "library_names": [],
        "filelist": input_file_list.path,
        "linked_binary": binary.path,
        # artifacts to be passed to the linker with `-force_load`
        "force_load_exec_paths": [lib.path for lib in always_link_libraries],
        # linkopts from dependency
        "dep_linkopts": _create_deduped_linkopts_list(cc_linking_context.linker_inputs),
        "attr_linkopts": attr_linkopts,  # linkopts arising from rule attributes
    }
    additional_inputs = [
        input
        for linker_input in cc_linking_context.linker_inputs.to_list()
        for input in linker_input.additional_inputs
    ]
    cc_common.link(
        name = name,
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = common_variables.toolchain,
        language = "objc",
        additional_inputs = (
            as_needed_libraries + always_link_libraries + [input_file_list] + extra_link_inputs +
            additional_inputs +
            getattr(ctx.files, "additional_linker_inputs", [])
        ),
        linking_contexts = [cc_common.create_linking_context(linker_inputs = depset(
            [cc_common.create_linker_input(
                owner = ctx.label,
                linkstamps = cc_linking_context.linkstamps(),
            )],
        ))],
        output_type = "executable",
        build_config = apple_platform_info.target_build_config,
        user_link_flags = extra_link_args,
        stamp = stamp,
        variables_extension = extensions,
        additional_outputs = additional_outputs,
        main_output = binary,
    )

    return binary

compilation_support = struct(
    # TODO(b/331163513): Move apple_common.compliation_support.build_common_variables here, too.
    register_fully_link_action = _register_fully_link_action,
    register_configuration_specific_link_actions = _register_configuration_specific_link_actions,
    subtract_linking_contexts = _subtract_linking_contexts,
)
