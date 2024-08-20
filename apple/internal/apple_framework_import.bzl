# Copyright 2018 The Bazel Authors. All rights reserved.
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

"""Implementation of framework import rules."""

load(
    "@bazel_skylib//lib:collections.bzl",
    "collections",
)
load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@bazel_skylib//lib:sets.bzl",
    "sets",
)
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain", "use_cpp_toolchain")
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "group_files_by_directory",
)
load(
    "@build_bazel_rules_apple//apple/internal:cc_toolchain_info_support.bzl",
    "cc_toolchain_info_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:experimental.bzl",
    "is_experimental_tree_artifact_enabled",
)
load(
    "@build_bazel_rules_apple//apple/internal:framework_import_support.bzl",
    "framework_import_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "AppleFrameworkImportInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:resources.bzl",
    "resources",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_attrs.bzl",
    "rule_attrs",
)
load(
    "@build_bazel_rules_apple//apple/internal/aspects:swift_usage_aspect.bzl",
    "SwiftUsageInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/toolchains:apple_toolchains.bzl",
    "apple_toolchain_utils",
)
load(
    "@build_bazel_rules_swift//swift:swift_clang_module_aspect.bzl",
    "swift_clang_module_aspect",
)
load(
    "@build_bazel_rules_swift//swift:swift_common.bzl",
    "swift_common",
)

visibility([
    "//apple/...",
    "//test/...",
])

# The name of the execution group that houses the Swift toolchain and is used to
# run Swift actions.
_SWIFT_EXEC_GROUP = "swift"

def _grouped_framework_files(framework_imports):
    """Returns a dictionary of each framework's imports, grouped by path to the .framework root."""
    framework_groups = group_files_by_directory(
        framework_imports,
        ["framework"],
        attr = "framework_imports",
    )

    # Only check for unique basenames of these keys, since it's possible to
    # have targets that glob files from different locations but with the same
    # `.framework` name, causing them to be merged into the same framework
    # during bundling.
    unique_frameworks = collections.uniq(
        [paths.basename(path) for path in framework_groups.keys()],
    )
    if len(unique_frameworks) > 1:
        fail("A framework import target may only include files for a " +
             "single '.framework' bundle.", attr = "framework_imports")

    return framework_groups

def _framework_search_paths(header_imports):
    """Return the list framework search paths for the headers_imports."""
    if header_imports:
        header_groups = _grouped_framework_files(header_imports)

        search_paths = sets.make()
        for path in header_groups.keys():
            sets.insert(search_paths, paths.dirname(path))
        return sets.to_list(search_paths)
    else:
        return []

def _apple_dynamic_framework_import_impl(ctx):
    """Implementation for the apple_dynamic_framework_import rule."""
    actions = ctx.actions
    apple_xplat_toolchain_info = apple_toolchain_utils.get_xplat_toolchain(ctx)
    cc_toolchain = find_cpp_toolchain(ctx)
    deps = ctx.attr.deps
    disabled_features = ctx.disabled_features
    features = ctx.features
    framework_imports = ctx.files.framework_imports
    label = ctx.label

    # TODO(b/258492867): Add tree artifacts support when Bazel can handle remote actions with
    # symlinks. See https://github.com/bazelbuild/bazel/issues/16361.
    target_triplet = cc_toolchain_info_support.get_apple_clang_triplet(cc_toolchain)
    has_versioned_framework_files = framework_import_support.has_versioned_framework_files(
        framework_imports,
    )
    tree_artifact_enabled = (
        apple_xplat_toolchain_info.build_settings.use_tree_artifacts_outputs or
        is_experimental_tree_artifact_enabled(config_vars = ctx.var)
    )
    if target_triplet.os == "macos" and has_versioned_framework_files and tree_artifact_enabled:
        fail("The apple_dynamic_framework_import rule does not yet support versioned " +
             "frameworks with the experimental tree artifact feature/build setting. " +
             "Please ensure that the `apple.experimental.tree_artifact_outputs` variable is not " +
             "set to 1 on the command line or in your active build configuration.")

    providers = []
    framework = framework_import_support.classify_framework_imports(
        framework_imports = framework_imports,
    )
    binary_imports = []
    if has_versioned_framework_files:
        # Do some extra filtering for binary_imports, in the event of a "Versioned" framework. These
        # will likely contain a symlink for the binary, which we want to filter out, as the dynamic
        # framework processor will insert one of its own.
        binary_imports = framework_import_support.get_canonical_versioned_framework_files(
            framework.binary_imports,
        )
    else:
        binary_imports = framework.binary_imports

    if len(binary_imports) > 1:
        fail("""
Error: Unexpectedly found more than one candidate for a framework binary:

{binary_imports}

There should only be one valid framework binary, given a name that matches its framework bundle.
""".format(binary_imports = "\n".join([f.path for f in binary_imports])))

    # Create AppleFrameworkImportInfo provider.
    providers.append(framework_import_support.framework_import_info_with_dependencies(
        build_archs = [target_triplet.architecture],
        deps = deps,
        binary_imports = binary_imports,
        bundling_imports = framework.bundling_imports,
    ))

    # Create CcInfo provider.
    cc_info = framework_import_support.cc_info_with_dependencies(
        actions = actions,
        cc_toolchain = cc_toolchain,
        ctx = ctx,
        deps = deps,
        disabled_features = disabled_features,
        features = features,
        framework_includes = _framework_search_paths(framework.header_imports),
        header_imports = framework.header_imports,
        kind = "dynamic",
        label = label,
        libraries = binary_imports,
    )
    providers.append(cc_info)

    # Create AppleDynamicFramework provider.
    framework_groups = _grouped_framework_files(framework_imports)
    framework_dirs_set = depset(framework_groups.keys())
    providers.append(apple_common.new_dynamic_framework_provider(
        cc_info = cc_info,
        framework_dirs = framework_dirs_set,
        framework_files = depset(framework_imports),
    ))

    if framework.swift_interface_imports:
        # Create SwiftInfo provider
        swift_toolchain = swift_common.get_toolchain(ctx, exec_group = _SWIFT_EXEC_GROUP)
        swiftinterface_files = framework_import_support.get_swift_module_files_with_target_triplet(
            swift_module_files = framework.swift_interface_imports,
            target_triplet = target_triplet,
        )
        providers.append(
            framework_import_support.swift_info_from_module_interface(
                actions = actions,
                ctx = ctx,
                deps = deps,
                disabled_features = disabled_features,
                features = features,
                module_name = framework.bundle_name,
                swift_toolchain = swift_toolchain,
                swiftinterface_file = swiftinterface_files[0],
            ),
        )
    else:
        # Create _SwiftInteropInfo provider.
        swift_interop_info = framework_import_support.swift_interop_info_with_dependencies(
            deps = deps,
            module_name = framework.bundle_name,
            module_map_imports = framework.module_map_imports,
        )
        if swift_interop_info:
            providers.append(swift_interop_info)

    return providers

def _apple_static_framework_import_impl(ctx):
    """Implementation for the apple_static_framework_import rule."""
    actions = ctx.actions
    alwayslink = ctx.attr.alwayslink or ctx.fragments.objc.alwayslink_by_default
    cc_toolchain = find_cpp_toolchain(ctx)
    deps = ctx.attr.deps
    disabled_features = ctx.disabled_features
    features = ctx.features
    framework_imports = ctx.files.framework_imports
    has_swift = ctx.attr.has_swift
    label = ctx.label
    sdk_dylibs = ctx.attr.sdk_dylibs
    sdk_frameworks = ctx.attr.sdk_frameworks
    weak_sdk_frameworks = ctx.attr.weak_sdk_frameworks

    has_versioned_framework_files = framework_import_support.has_versioned_framework_files(
        framework_imports,
    )

    providers = []
    framework = framework_import_support.classify_framework_imports(
        framework_imports = framework_imports,
    )
    binary_imports = []
    if has_versioned_framework_files:
        # Do some extra filtering for binary_imports, in the event of a "Versioned" framework. For
        # a static framework without an Info.plist these are completely unnecessary, but some
        # clients do ship these artifacts.
        binary_imports = framework_import_support.get_canonical_versioned_framework_files(
            framework.binary_imports,
        )
    else:
        binary_imports = framework.binary_imports

    if len(binary_imports) > 1:
        fail("""
Error: Unexpectedly found more than one candidate for a framework static library archive:

{binary_imports}

There should only be one valid framework binary, given a name that matches its framework bundle.
""".format(binary_imports = "\n".join([f.path for f in binary_imports])))

    # Create AppleFrameworkImportInfo provider
    target_triplet = cc_toolchain_info_support.get_apple_clang_triplet(cc_toolchain)
    providers.append(framework_import_support.framework_import_info_with_dependencies(
        build_archs = [target_triplet.architecture],
        deps = deps,
    ))

    # Collect transitive Objc/CcInfo providers from Swift toolchain
    additional_cc_infos = []
    if framework.swift_interface_imports or has_swift:
        toolchain = swift_common.get_toolchain(ctx, exec_group = _SWIFT_EXEC_GROUP)
        providers.append(SwiftUsageInfo())

        # The Swift toolchain propagates Swift-specific linker flags (e.g.,
        # library/framework search paths) as an implicit dependency. In the
        # rare case that a binary has a Swift framework import dependency but
        # no other Swift dependencies, make sure we pick those up so that it
        # links to the standard libraries correctly.
        additional_cc_infos.extend(toolchain.implicit_deps_providers.cc_infos)

    # Create CcInfo provider
    linkopts = []
    if sdk_dylibs:
        for dylib in ctx.attr.sdk_dylibs:
            if dylib.startswith("lib"):
                dylib = dylib[3:]
            linkopts.append("-l%s" % dylib)
    if sdk_frameworks:
        for sdk_framework in ctx.attr.sdk_frameworks:
            linkopts.append("-framework")
            linkopts.append(sdk_framework)
    if weak_sdk_frameworks:
        for sdk_framework in ctx.attr.weak_sdk_frameworks:
            linkopts.append("-weak_framework")
            linkopts.append(sdk_framework)

    providers.append(
        framework_import_support.cc_info_with_dependencies(
            actions = actions,
            additional_cc_infos = additional_cc_infos,
            alwayslink = alwayslink,
            cc_toolchain = cc_toolchain,
            ctx = ctx,
            deps = deps,
            disabled_features = disabled_features,
            features = features,
            framework_includes = _framework_search_paths(
                framework.header_imports,
            ),
            header_imports = framework.header_imports,
            kind = "static",
            label = label,
            libraries = binary_imports,
            linkopts = linkopts,
        ),
    )

    if framework.swift_interface_imports:
        # Create SwiftInfo provider
        swift_toolchain = swift_common.get_toolchain(ctx, exec_group = _SWIFT_EXEC_GROUP)
        swiftinterface_files = framework_import_support.get_swift_module_files_with_target_triplet(
            swift_module_files = framework.swift_interface_imports,
            target_triplet = target_triplet,
        )
        providers.append(
            framework_import_support.swift_info_from_module_interface(
                actions = actions,
                ctx = ctx,
                deps = deps,
                disabled_features = disabled_features,
                features = features,
                module_name = framework.bundle_name,
                swift_toolchain = swift_toolchain,
                swiftinterface_file = swiftinterface_files[0],
            ),
        )
    else:
        # Create SwiftInteropInfo provider for swift_clang_module_aspect
        swift_interop_info = framework_import_support.swift_interop_info_with_dependencies(
            deps = deps,
            module_name = framework.bundle_name,
            module_map_imports = framework.module_map_imports,
        )
        if swift_interop_info:
            providers.append(swift_interop_info)

    # Create AppleResourceInfo provider
    bundle_files = [x for x in framework_imports if ".bundle/" in x.short_path]
    if bundle_files:
        parent_dir_param = partial.make(
            resources.bundle_relative_parent_dir,
            extension = "bundle",
        )
        resource_provider = resources.bucketize_typed(
            bucket_type = "unprocessed",
            expect_files = True,
            owner = str(label),
            parent_dir_param = parent_dir_param,
            resources = bundle_files,
        )
        providers.append(resource_provider)

    return providers

apple_dynamic_framework_import = rule(
    implementation = _apple_dynamic_framework_import_impl,
    fragments = ["cpp"],
    attrs = dicts.add(
        rule_attrs.common_tool_attrs(),
        {
            "framework_imports": attr.label_list(
                allow_empty = False,
                allow_files = True,
                mandatory = True,
                doc = """
The list of files under a .framework directory which are provided to Apple based targets that depend
on this target.
""",
            ),
            "deps": attr.label_list(
                aspects = [swift_clang_module_aspect],
                doc = """
A list of targets that are dependencies of the target being built, which will be linked into that
target.
""",
                providers = [
                    [CcInfo],
                    [CcInfo, AppleFrameworkImportInfo],
                ],
            ),
            "_cc_toolchain": attr.label(
                default = "@bazel_tools//tools/cpp:current_cc_toolchain",
                doc = "The C++ toolchain to use.",
            ),
            # TODO(b/301253335): Enable AEGs and switch from `swift` exec_group to swift `toolchain` param.
            "_use_auto_exec_groups": attr.bool(default = False),
        },
    ),
    doc = """
This rule encapsulates an already-built dynamic framework. It is defined by a list of files in
exactly one .framework directory. apple_dynamic_framework_import targets need to be added to library
targets through the `deps` attribute.
""",
    exec_groups = dicts.add(
        {
            _SWIFT_EXEC_GROUP: exec_group(
                toolchains = swift_common.use_toolchain(),
            ),
        },
        apple_toolchain_utils.use_apple_exec_group_toolchain(),
    ),
    toolchains = use_cpp_toolchain(),
)

apple_static_framework_import = rule(
    implementation = _apple_static_framework_import_impl,
    fragments = ["cpp", "objc"],
    attrs = dicts.add(
        rule_attrs.common_tool_attrs(),
        {
            "framework_imports": attr.label_list(
                allow_empty = False,
                allow_files = True,
                mandatory = True,
                doc = """
The list of files under a .framework directory which are provided to Apple based targets that depend
on this target.
""",
            ),
            "sdk_dylibs": attr.string_list(
                doc = """
Names of SDK .dylib libraries to link with. For instance, `libz` or `libarchive`. `libc++` is
included automatically if the binary has any C++ or Objective-C++ sources in its dependency tree.
When linking a binary, all libraries named in that binary's transitive dependency graph are used.
""",
            ),
            "sdk_frameworks": attr.string_list(
                doc = """
Names of SDK frameworks to link with (e.g. `AddressBook`, `QuartzCore`). When linking a top level
binary, all SDK frameworks listed in that binary's transitive dependency graph are linked.
""",
            ),
            "weak_sdk_frameworks": attr.string_list(
                doc = """
Names of SDK frameworks to weakly link with. For instance, `MediaAccessibility`. In difference to
regularly linked SDK frameworks, symbols from weakly linked frameworks do not cause an error if they
are not present at runtime.
""",
            ),
            "deps": attr.label_list(
                aspects = [swift_clang_module_aspect],
                doc = """
A list of targets that are dependencies of the target being built, which will provide headers and be
linked into that target.
""",
                providers = [
                    [CcInfo],
                    [CcInfo, AppleFrameworkImportInfo],
                ],
            ),
            "alwayslink": attr.bool(
                default = False,
                doc = """
If true, any binary that depends (directly or indirectly) on this framework will link in all the
object files for the framework file, even if some contain no symbols referenced by the binary. This
is useful if your code isn't explicitly called by code in the binary; for example, if you rely on
runtime checks for protocol conformances added in extensions in the library but do not directly
reference any other symbols in the object file that adds that conformance.
""",
            ),
            "has_swift": attr.bool(
                doc = """
A boolean indicating if the target has Swift source code. This helps flag Apple frameworks that do
not include Swift interface files.
""",
                default = False,
            ),
            "_cc_toolchain": attr.label(
                default = "@bazel_tools//tools/cpp:current_cc_toolchain",
                doc = "The C++ toolchain to use.",
            ),
            # TODO(b/301253335): Enable AEGs and switch from `swift` exec_group to swift `toolchain` param.
            "_use_auto_exec_groups": attr.bool(default = False),
        },
    ),
    doc = """
This rule encapsulates an already-built static framework. It is defined by a list of files in a
.framework directory. apple_static_framework_import targets need to be added to library targets
through the `deps` attribute.
""",
    exec_groups = dicts.add(
        {
            _SWIFT_EXEC_GROUP: exec_group(
                toolchains = swift_common.use_toolchain(),
            ),
        },
        apple_toolchain_utils.use_apple_exec_group_toolchain(),
    ),
    toolchains = use_cpp_toolchain(),
)
