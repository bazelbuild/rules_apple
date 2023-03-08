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
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@bazel_skylib//lib:sets.bzl",
    "sets",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleFrameworkImportInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/providers:framework_import_bundle_info.bzl",
    "AppleFrameworkImportBundleInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:cc_toolchain_info_support.bzl",
    "cc_toolchain_info_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:bundle_paths.bzl",
    "bundle_paths",
)
load(
    "@build_bazel_rules_apple//apple/internal/aspects:swift_usage_aspect.bzl",
    "SwiftUsageInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_factory.bzl",
    "rule_factory",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "group_files_by_directory",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "SwiftToolchainInfo",
    "swift_clang_module_aspect",
    "swift_common",
)
load(
    "@build_bazel_rules_apple//apple/internal:framework_import_support.bzl",
    "framework_import_support",
)
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain", "use_cpp_toolchain")

def _swiftmodule_for_cpu(swiftmodule_files, cpu):
    """Select the cpu specific swiftmodule."""

    # The paths will be of the following format:
    #   ABC.framework/Modules/ABC.swiftmodule/<arch>.swiftmodule
    # Where <arch> will be a common arch like x86_64, arm64, etc.
    named_files = {f.basename: f for f in swiftmodule_files}

    module = named_files.get("{}.swiftmodule".format(cpu))
    if not module and cpu == "armv7":
        module = named_files.get("arm.swiftmodule")

    return module

def _all_framework_binaries(frameworks_groups):
    """Returns a list of Files of all imported binaries."""
    binaries = []
    for framework_dir, framework_imports in frameworks_groups.items():
        binary = _get_framework_binary_file(framework_dir, framework_imports.to_list())
        if binary != None:
            binaries.append(binary)

    return binaries

def _all_dsym_binaries(dsym_imports):
    """Returns a list of Files of all imported dSYM binaries."""
    return [
        file
        for file in dsym_imports
        if file.basename.lower() != "info.plist"
    ]

def _get_framework_binary_file(framework_dir, framework_imports):
    """Returns the File that is the framework's binary."""
    framework_name = paths.split_extension(paths.basename(framework_dir))[0]
    framework_path = paths.join(framework_dir, framework_name)
    for framework_import in framework_imports:
        if framework_import.path == framework_path:
            return framework_import

    return None

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

def _is_debugging(compilation_mode):
    """Returns `True` if the current compilation mode produces debug info.

    rules_apple specific implementation of rules_swift's `is_debugging`, which
    is not currently exported.

    See: https://github.com/bazelbuild/rules_swift/blob/44146fccd9e56fe1dc650a4e0f21420a503d301c/swift/internal/api.bzl#L315-L326
    """
    return compilation_mode in ("dbg", "fastbuild")

def _ensure_swiftmodule_is_embedded(swiftmodule):
    """Ensures that a `.swiftmodule` file is embedded in a library or binary.

    rules_apple specific implementation of rules_swift's
    `ensure_swiftmodule_is_embedded`, which is not currently exported.

    See: https://github.com/bazelbuild/rules_swift/blob/e78ceb37c401a9bf9e551a6accd1df7d864688d5/swift/internal/debugging.bzl#L20-L47
    """
    return dict(
        linkopt = depset(["-Wl,-add_ast_path,{}".format(swiftmodule.path)]),
        link_inputs = depset([swiftmodule]),
    )

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

def _debug_info_binaries(
        dsym_binaries,
        framework_binaries):
    """Return the list of files that provide debug info."""
    all_binaries_dict = {}

    for file in dsym_binaries:
        dsym_bundle_path = bundle_paths.farthest_parent(
            file.short_path,
            "framework.dSYM",
        )
        dsym_bundle_basename = paths.basename(dsym_bundle_path)
        framework_basename = dsym_bundle_basename.rstrip(".dSYM")
        all_binaries_dict[framework_basename] = file

    for file in framework_binaries:
        framework_path = bundle_paths.farthest_parent(
            file.short_path,
            "framework",
        )
        framework_basename = paths.basename(framework_path)
        if framework_basename not in all_binaries_dict:
            all_binaries_dict[framework_basename] = file

    return all_binaries_dict.values()

def _apple_dynamic_framework_import_impl(ctx):
    """Implementation for the apple_dynamic_framework_import rule."""
    actions = ctx.actions
    cc_toolchain = find_cpp_toolchain(ctx)
    deps = ctx.attr.deps
    disabled_features = ctx.disabled_features
    features = ctx.features
    framework_imports = ctx.files.framework_imports
    label = ctx.label

    # TODO(b/207475773): Remove grep-includes once it's no longer required for cc_common APIs.
    grep_includes = ctx.file._grep_includes

    providers = []
    framework_imports_by_category = framework_import_support.classify_framework_imports(
        ctx.var,
        framework_imports,
    )

    dsym_binaries = _all_dsym_binaries(ctx.files.dsym_imports)
    dsym_imports = ctx.files.dsym_imports
    framework_groups = _grouped_framework_files(framework_imports)
    framework_binaries = _all_framework_binaries(framework_groups)
    debug_info_binaries = _debug_info_binaries(
        dsym_binaries = dsym_binaries,
        framework_binaries = framework_binaries,
    )

    # Create AppleFrameworkImportInfo provider.
    target_triplet = cc_toolchain_info_support.get_apple_clang_triplet(cc_toolchain)
    providers.append(framework_import_support.framework_import_info_with_dependencies(
        build_archs = [target_triplet.architecture],
        deps = deps,
        debug_info_binaries = debug_info_binaries,
        dsyms = dsym_imports,
        framework_imports = (
            framework_imports_by_category.binary_imports +
            framework_imports_by_category.bundling_imports
        ),
    ))

    # Create apple_common.Objc provider.
    transitive_objc_providers = [
        dep[apple_common.Objc]
        for dep in deps
        if apple_common.Objc in dep
    ]
    objc_provider = framework_import_support.objc_provider_with_dependencies(
        additional_objc_providers = transitive_objc_providers,
        dynamic_framework_file = [] if ctx.attr.bundle_only else framework_imports_by_category.binary_imports,
    )
    providers.append(objc_provider)

    # Create CcInfo provider.
    cc_info = framework_import_support.cc_info_with_dependencies(
        actions = actions,
        cc_toolchain = cc_toolchain,
        ctx = ctx,
        deps = deps,
        disabled_features = disabled_features,
        features = features,
        framework_includes = _framework_search_paths(framework_imports_by_category.header_imports),
        grep_includes = grep_includes,
        header_imports = framework_imports_by_category.header_imports,
        kind = "dynamic",
        label = label,
        libraries = [] if ctx.attr.bundle_only else framework_imports_by_category.binary_imports,
        swiftmodule_imports = framework_imports_by_category.swift_module_imports,
    )
    providers.append(cc_info)

    # Create AppleDynamicFramework provider.
    framework_groups = _grouped_framework_files(framework_imports)
    framework_dirs_set = depset(framework_groups.keys())
    providers.append(apple_common.new_dynamic_framework_provider(
        objc = objc_provider,
        cc_info = cc_info,
        framework_dirs = framework_dirs_set,
        framework_files = depset(framework_imports),
    ))

    # Create _SwiftInteropInfo provider.
    # For now, Swift interop is restricted only to a Clang module map inside
    # the framework.
    swift_interop_info = framework_import_support.swift_interop_info_with_dependencies(
        deps = deps,
        module_name = framework_imports_by_category.bundle_name,
        module_map_imports = framework_imports_by_category.module_map_imports,
    )
    if swift_interop_info:
        providers.append(swift_interop_info)

    return providers

def _apple_static_framework_import_impl(ctx):
    """Implementation for the apple_static_framework_import rule."""
    actions = ctx.actions
    alwayslink = ctx.attr.alwayslink
    cc_toolchain = find_cpp_toolchain(ctx)
    compilation_mode = ctx.var["COMPILATION_MODE"]
    deps = ctx.attr.deps
    disabled_features = ctx.disabled_features
    features = ctx.features
    framework_imports = ctx.files.framework_imports
    has_swift = ctx.attr.has_swift
    label = ctx.label
    sdk_dylibs = ctx.attr.sdk_dylibs
    sdk_frameworks = ctx.attr.sdk_frameworks
    weak_sdk_frameworks = ctx.attr.weak_sdk_frameworks

    # TODO(b/207475773): Remove grep-includes once it's no longer required for cc_common APIs.
    grep_includes = ctx.file._grep_includes

    providers = [
        DefaultInfo(runfiles = ctx.runfiles(files = ctx.files.data)),
    ]

    framework_imports_by_category = framework_import_support.classify_framework_imports(
        ctx.var,
        framework_imports,
    )

    # Create AppleFrameworkImportInfo provider.
    target_triplet = cc_toolchain_info_support.get_apple_clang_triplet(cc_toolchain)
    providers.append(framework_import_support.framework_import_info_with_dependencies(
        build_archs = [target_triplet.architecture],
        deps = deps,
    ))

    # Collect transitive Objc/CcInfo providers from Swift toolchain.
    additional_cc_infos = []
    additional_objc_providers = []
    additional_objc_provider_fields = {}
    if framework_imports_by_category.swift_module_imports or has_swift:
        toolchain = ctx.attr._toolchain[SwiftToolchainInfo]
        providers.append(SwiftUsageInfo())

        # The Swift toolchain propagates Swift-specific linker flags (e.g.,
        # library/framework search paths) as an implicit dependency. In the
        # rare case that a binary has a Swift framework import dependency but
        # no other Swift dependencies, make sure we pick those up so that it
        # links to the standard libraries correctly.
        additional_objc_providers.extend(toolchain.implicit_deps_providers.objc_infos)
        additional_cc_infos.extend(toolchain.implicit_deps_providers.cc_infos)

        if _is_debugging(compilation_mode):
            swiftmodule = _swiftmodule_for_cpu(
                framework_imports_by_category.swift_module_imports,
                target_triplet.architecture,
            )
            if swiftmodule:
                additional_objc_provider_fields.update(_ensure_swiftmodule_is_embedded(swiftmodule))

    # Create apple_common.Objc provider.
    additional_objc_providers.extend([
        dep[apple_common.Objc]
        for dep in deps
        if apple_common.Objc in dep
    ])
    providers.append(
        framework_import_support.objc_provider_with_dependencies(
            additional_objc_provider_fields = additional_objc_provider_fields,
            additional_objc_providers = additional_objc_providers,
            alwayslink = alwayslink,
            sdk_dylib = sdk_dylibs,
            sdk_framework = sdk_frameworks,
            static_framework_file = framework_imports_by_category.binary_imports,
            weak_sdk_framework = weak_sdk_frameworks,
        ),
    )

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

    # Create CcInfo provider.
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
                framework_imports_by_category.header_imports,
            ),
            grep_includes = grep_includes,
            header_imports = framework_imports_by_category.header_imports,
            kind = "static",
            label = label,
            libraries = framework_imports_by_category.binary_imports,
            linkopts = linkopts,
            swiftmodule_imports = framework_imports_by_category.swift_module_imports,
        ),
    )

    # Create _SwiftInteropInfo provider.
    # For now, Swift interop is restricted only to a Clang module map inside
    # the framework.
    swift_interop_info = framework_import_support.swift_interop_info_with_dependencies(
        deps = deps,
        module_name = framework_imports_by_category.bundle_name,
        module_map_imports = framework_imports_by_category.module_map_imports,
    )
    if swift_interop_info:
        providers.append(swift_interop_info)

    # Create AppleFrameworkImportBundleInfo provider.
    bundle_files = [x for x in framework_imports if ".bundle/" in x.short_path]
    if bundle_files:
        providers.append(AppleFrameworkImportBundleInfo(bundle_files = bundle_files))

    return providers

apple_dynamic_framework_import = rule(
    implementation = _apple_dynamic_framework_import_impl,
    fragments = ["cpp"],
    attrs = dicts.add(
        rule_factory.common_tool_attributes,
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
            "dsym_imports": attr.label_list(
                allow_files = True,
                doc = """
The list of files under a .dSYM directory, that is the imported framework's dSYM bundle.
""",
            ),
            "bundle_only": attr.bool(
                default = False,
                doc = """
Avoid linking the dynamic framework, but still include it in the app. This is useful when you want
to manually dlopen the framework at runtime.
""",
            ),
            "_cc_toolchain": attr.label(
                default = "@bazel_tools//tools/cpp:current_cc_toolchain",
                doc = "The C++ toolchain to use.",
            ),
        },
    ),
    doc = """
This rule encapsulates an already-built dynamic framework. It is defined by a list of
files in exactly one `.framework` directory. `apple_dynamic_framework_import` targets
need to be added to library targets through the `deps` attribute.
### Examples

```python
apple_dynamic_framework_import(
    name = "my_dynamic_framework",
    framework_imports = glob(["my_dynamic_framework.framework/**"]),
)

objc_library(
    name = "foo_lib",
    ...,
    deps = [
        ":my_dynamic_framework",
    ],
)
```
""",
    toolchains = use_cpp_toolchain(),
)

apple_static_framework_import = rule(
    implementation = _apple_static_framework_import_impl,
    fragments = ["cpp"],
    attrs = dicts.add(
        rule_factory.common_tool_attributes,
        swift_common.toolchain_attrs(),
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
Names of SDK frameworks to link with (e.g. `AddressBook`, `QuartzCore`). `UIKit` and `Foundation`
are always included when building for the iOS, tvOS and watchOS platforms. For macOS, only
`Foundation` is always included. When linking a top level binary, all SDK frameworks listed in that
binary's transitive dependency graph are linked.
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
            "data": attr.label_list(
                allow_files = True,
                doc = """
List of files needed by this target at runtime.

Files and targets named in the `data` attribute will appear in the `*.runfiles`
area of this target, if it has one. This may include data files needed by a
binary or library, or other programs needed by it.
""",
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
A boolean indicating if the target has Swift source code. This helps flag frameworks that do not
include Swift interface files but require linking the Swift libraries.
""",
                default = False,
            ),
            "_cc_toolchain": attr.label(
                default = "@bazel_tools//tools/cpp:current_cc_toolchain",
                doc = "The C++ toolchain to use.",
            ),
        },
    ),
    doc = """
This rule encapsulates an already-built static framework. It is defined by a list of
files in exactly one `.framework` directory. `apple_static_framework_import` targets
need to be added to library targets through the `deps` attribute.
### Examples

```python
apple_static_framework_import(
    name = "my_static_framework",
    framework_imports = glob(["my_static_framework.framework/**"]),
)

objc_library(
    name = "foo_lib",
    ...,
    deps = [
        ":my_static_framework",
    ],
)
```
""",
)
