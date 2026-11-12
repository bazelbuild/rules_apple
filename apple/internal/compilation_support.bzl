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
    "@build_bazel_rules_apple//apple/internal:outputs.bzl",
    "outputs",
)
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

visibility([
    "@build_bazel_rules_apple//apple/...",
])

def _build_feature_configuration(*, cc_configured_features, cc_toolchain):
    return cc_configured_features.configure_features(
        cc_toolchain = cc_toolchain,
        language = "objc",
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

def _normalized_owner(file):
    """Returns the label of a file's owner as `//package:name` or `@@repo//package:name`.

    Returns None if the file has no owner.
    """
    owner = file.owner
    if not owner:
        return None
    if owner.workspace_name:
        return "@@{}//{}:{}".format(owner.workspace_name, owner.package, owner.name)
    return "//{}:{}".format(owner.package, owner.name)

def _is_retained_library(
        library_to_link,
        library_artifact,
        retained_library_suffixes,
        retained_library_owners):
    """Returns whether an avoided static library is retained instead of subtracted."""
    if library_to_link.alwayslink:
        if retained_library_owners and _normalized_owner(library_artifact) in retained_library_owners:
            # Fully linked into the avoided image, so retaining it would always duplicate it.
            fail((
                "ERROR: `retained_avoid_deps_libraries` lists {owner}, but its library {library} " +
                "is `alwayslink = True`. Such libraries are fully linked into the dynamic " +
                "framework or bundle loader that depends on them and are always subtracted; " +
                "remove {owner} from `retained_avoid_deps_libraries`."
            ).format(owner = _normalized_owner(library_artifact), library = library_artifact.short_path))
        return False
    for suffix in retained_library_suffixes:
        if library_artifact.basename.endswith(suffix):
            return True
    return bool(retained_library_owners) and (
        _normalized_owner(library_artifact) in retained_library_owners
    )

def _build_avoid_library_sets(
        avoid_dep_linking_contexts,
        *,
        retained_library_owners = {},
        retained_library_suffixes = []):
    """Returns the short paths of the avoided static libraries, in one pass.

    Returns:
      A tuple `(subtracted, all_avoided)` of dicts keyed by short path: the avoided static
      libraries that are subtracted, and all avoided static libraries (subtracted or retained).
    """
    subtracted_library_set = dict()
    all_avoided_library_set = dict()
    is_retaining = bool(retained_library_suffixes or retained_library_owners)
    for linking_context in avoid_dep_linking_contexts:
        for linker_input in linking_context.linker_inputs.to_list():
            for library_to_link in linker_input.libraries:
                library_artifact = _get_static_library_for_linking(library_to_link)
                if not library_artifact:
                    continue
                all_avoided_library_set[library_artifact.short_path] = True
                if is_retaining and _is_retained_library(
                    library_to_link,
                    library_artifact,
                    retained_library_suffixes,
                    retained_library_owners,
                ):
                    continue
                subtracted_library_set[library_artifact.short_path] = True
    return subtracted_library_set, all_avoided_library_set

def _subtract_linking_contexts(
        owner,
        linking_contexts,
        avoid_dep_linking_contexts,
        *,
        retained_library_owners = {},
        retained_library_suffixes = []):
    """Subtracts the libraries in avoid_dep_linking_contexts from linking_contexts.

    Args:
      owner: The label of the target currently being analyzed.
      linking_contexts: An iterable of CcLinkingContext objects: the binary's own deps, and the
        objects of `avoid_dep_linking_contexts` (which only contribute their dynamic libraries
        and flags).
      avoid_dep_linking_contexts: An iterable of CcLinkingContext objects.
      retained_library_owners: A dict whose keys are labels, in `//package:name` form for
        the main repository, of targets owning avoided static libraries to retain.
      retained_library_suffixes: A list of static library basename suffixes. Avoided
        `alwayslink = False` static libraries whose basename ends with one of them, or
        whose owner is in `retained_library_owners`, are not subtracted if the binary's own
        deps link them, but placed after
        the avoided dynamic libraries, so that archive members the avoided images did not
        link can still satisfy references from the binary. All other avoided libraries are
        subtracted. Both are empty by default.

    Returns:
      A CcLinkingContext object.
    """
    libraries = []
    avoided_retained_libraries = []
    user_link_flags = []
    additional_inputs = []
    linkstamps = []
    avoid_library_set, all_avoid_static_library_set = _build_avoid_library_sets(
        avoid_dep_linking_contexts,
        retained_library_owners = retained_library_owners,
        retained_library_suffixes = retained_library_suffixes,
    )
    for linking_context in linking_contexts:
        # The linking contexts of the avoided images (frameworks, bundle loader) only contribute
        # their dynamic libraries and flags. Retained static libraries are only taken from the
        # binary's own deps: an avoided image's linking context can hold libraries the binary doesn't
        # depend on, built for other architectures or in the image's configuration.
        is_avoided_image_context = linking_context in avoid_dep_linking_contexts
        for linker_input in linking_context.linker_inputs.to_list():
            for library_to_link in linker_input.libraries:
                library_artifact = _get_library_for_linking(library_to_link)
                if library_artifact.short_path not in avoid_library_set:
                    if library_artifact.short_path in all_avoid_static_library_set:
                        if not is_avoided_image_context:
                            avoided_retained_libraries.append(library_to_link)
                    else:
                        libraries.append(library_to_link)
            user_link_flags.extend(linker_input.user_link_flags)
            additional_inputs.extend(linker_input.additional_inputs)
            linkstamps.extend(linker_input.linkstamps)
    libraries.extend(avoided_retained_libraries)
    linker_input = cc_common.create_linker_input(
        owner = owner,
        libraries = depset(libraries, order = "topological"),
        user_link_flags = user_link_flags,
        additional_inputs = depset(additional_inputs),
        linkstamps = depset(linkstamps),
    )
    return cc_common.create_linking_context(
        linker_inputs = depset([linker_input]),
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

def _register_fully_link_action(
        *,
        cc_configured_features,
        cc_linking_context,
        common_variables,
        name):
    feature_configuration = _build_feature_configuration(
        cc_configured_features = cc_configured_features,
        cc_toolchain = common_variables.toolchain,
    )

    libraries_to_link = _libraries_from_linking_context(cc_linking_context).to_list()
    libraries = _get_libraries_for_linking(libraries_to_link)

    ctx = common_variables.ctx
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

def _register_configuration_specific_link_actions(
        *,
        additional_outputs,
        apple_platform_info,
        attr_linkopts,
        bundle_name,
        common_variables,
        cc_configured_features,
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
    feature_configuration = _build_feature_configuration(
        cc_configured_features = cc_configured_features,
        cc_toolchain = common_variables.toolchain,
    )

    ctx = common_variables.ctx
    binary = outputs.main_binary(
        actions = ctx.actions,
        bundle_name = bundle_name,
        cc_toolchain = common_variables.toolchain,
        label = ctx.label,
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

def _create_deduped_linkopts_linking_context(*, cc_linking_context, seen_flags):
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
                linkstamps = depset(linker_input.linkstamps),
            ))

    return cc_common.create_linking_context(linker_inputs = depset(linker_inputs))

compilation_support = struct(
    register_fully_link_action = _register_fully_link_action,
    register_configuration_specific_link_actions = _register_configuration_specific_link_actions,
    subtract_linking_contexts = _subtract_linking_contexts,
)
