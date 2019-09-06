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
    "@build_bazel_rules_apple//apple/internal:resources.bzl",
    "resources",
)
load(
    "@build_bazel_apple_support//lib:framework_migration.bzl",
    "framework_migration",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "group_files_by_directory",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "SwiftToolchainInfo",
    "SwiftUsageInfo",
    "swift_common",
)

AppleFrameworkImportInfo = provider(
    doc = "Provider that propagates information about framework import targets.",
    fields = {
        "framework_imports": """
Depset of Files that represent framework imports that need to be bundled in the top level
application bundle under the Frameworks directory.
""",
    },
)

def _is_swiftmodule(path):
    """Predicate to identify Swift modules/interfaces."""
    return path.endswith(".swiftmodule") or path.endswith(".swiftinterface")

def _classify_framework_imports(framework_imports):
    """Classify a list of framework files into bundling, header, or module_map."""

    bundling_imports = []
    header_imports = []
    module_map_imports = []
    for file in framework_imports:
        file_short_path = file.short_path
        if file_short_path.endswith(".h"):
            header_imports.append(file)
            continue
        if file_short_path.endswith(".modulemap"):
            module_map_imports.append(file)
            continue
        if "Headers/" in file_short_path:
            # This matches /Headers/ and /PrivateHeaders/
            header_imports.append(file)
            continue
        if _is_swiftmodule(file_short_path):
            # Add Swift's module files to header_imports so that they are correctly included in the build
            # by Bazel but they aren't processed in any way
            header_imports.append(file)
            continue
        if file_short_path.endswith(".swiftdoc"):
            # Ignore swiftdoc files, they don't matter in the build, only for IDEs
            continue
        bundling_imports.append(file)

    return bundling_imports, header_imports, module_map_imports

def _all_framework_binaries(frameworks_groups):
    """Returns a list of Files of all imported binaries."""
    binaries = []
    for framework_dir, framework_imports in frameworks_groups.items():
        binary = _get_framework_binary_file(framework_dir, framework_imports.to_list())
        if binary != None:
            binaries.append(binary)

    return binaries

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

    # TODO(b/120920467): Add validation to ensure only a single framework is being imported.

    return framework_groups

def _objc_provider_with_dependencies(ctx, objc_provider_fields):
    """Returns a new Objc provider which includes transitive Objc dependencies."""
    objc_provider_fields["providers"] = [dep[apple_common.Objc] for dep in ctx.attr.deps]
    return apple_common.new_objc_provider(**objc_provider_fields)

def _transitive_framework_imports(deps):
    """Returns the list of transitive framework imports for the given deps."""
    return [
        dep[AppleFrameworkImportInfo].framework_imports
        for dep in deps
        if hasattr(dep[AppleFrameworkImportInfo], "framework_imports")
    ]

def _framework_import_info(transitive_sets):
    """Returns an AppleFrameworkImportInfo containg any transitive framework imports."""
    provider_fields = {}
    if transitive_sets:
        provider_fields["framework_imports"] = depset(transitive = transitive_sets)
    return AppleFrameworkImportInfo(**provider_fields)

def _framework_objc_provider_fields(
        framework_binary_field,
        header_imports,
        module_map_imports,
        framework_binaries):
    """Return an objc_provider initializer dictionary with information for a given framework."""

    objc_provider_fields = {}
    if header_imports:
        header_groups = _grouped_framework_files(header_imports)
        objc_provider_fields["framework_search_paths"] = depset(header_groups.keys())
        objc_provider_fields["header"] = depset(header_imports)

    if module_map_imports:
        objc_provider_fields["module_map"] = depset(module_map_imports)

    if framework_binaries:
        objc_provider_fields[framework_binary_field] = depset(framework_binaries)

    return objc_provider_fields

def _apple_dynamic_framework_import_impl(ctx):
    """Implementation for the apple_dynamic_framework_import rule."""
    providers = []

    framework_imports = ctx.files.framework_imports
    bundling_imports, header_imports, module_map_imports = (
        _classify_framework_imports(framework_imports)
    )

    transitive_sets = _transitive_framework_imports(ctx.attr.deps)
    if bundling_imports:
        transitive_sets.append(depset(bundling_imports))
    providers.append(_framework_import_info(transitive_sets))

    framework_groups = _grouped_framework_files(framework_imports)
    framework_dirs_set = depset(framework_groups.keys())
    if framework_migration.is_post_framework_migration():
        objc_provider_fields = _framework_objc_provider_fields(
            "dynamic_framework_file",
            header_imports,
            module_map_imports,
            _all_framework_binaries(framework_groups),
        )
    else:
        objc_provider_fields = {
            "dynamic_framework_dir": framework_dirs_set,
            "dynamic_framework_file": depset(framework_imports),
        }

    objc_provider = _objc_provider_with_dependencies(ctx, objc_provider_fields)
    providers.append(objc_provider)
    providers.append(apple_common.new_dynamic_framework_provider(
        objc = objc_provider,
        framework_dirs = framework_dirs_set,
        framework_files = depset(framework_imports),
    ))

    return providers

def _apple_static_framework_import_impl(ctx):
    """Implementation for the apple_static_framework_import rule."""
    providers = []

    framework_imports = ctx.files.framework_imports
    _, header_imports, module_map_imports = _classify_framework_imports(framework_imports)

    transitive_sets = _transitive_framework_imports(ctx.attr.deps)
    providers.append(_framework_import_info(transitive_sets))

    framework_groups = _grouped_framework_files(framework_imports)
    framework_binaries = _all_framework_binaries(framework_groups)

    if framework_migration.is_post_framework_migration():
        objc_provider_fields = _framework_objc_provider_fields(
            "static_framework_file",
            header_imports,
            module_map_imports,
            framework_binaries,
        )
    else:
        objc_provider_fields = {
            "static_framework_file": depset(framework_imports),
        }

    if ctx.attr.alwayslink:
        if not framework_binaries:
            fail("ERROR: There has to be a binary file in the imported framework.")
        objc_provider_fields["force_load_library"] = depset(framework_binaries)
    if ctx.attr.sdk_dylibs:
        objc_provider_fields["sdk_dylib"] = depset(ctx.attr.sdk_dylibs)
    if ctx.attr.sdk_frameworks:
        objc_provider_fields["sdk_framework"] = depset(ctx.attr.sdk_frameworks)
    if ctx.attr.weak_sdk_frameworks:
        objc_provider_fields["weak_sdk_framework"] = depset(ctx.attr.weak_sdk_frameworks)

    for f in header_imports:
        if _is_swiftmodule(f.basename):
            toolchain = ctx.attr._toolchain[SwiftToolchainInfo]
            providers.append(SwiftUsageInfo(toolchain = toolchain))
            break

    providers.append(_objc_provider_with_dependencies(ctx, objc_provider_fields))

    bundle_files = [x for x in framework_imports if ".bundle/" in x.short_path]
    if bundle_files:
        parent_dir_param = partial.make(
            resources.bundle_relative_parent_dir,
            extension = "bundle",
        )
        resource_provider = resources.bucketize_typed(
            bundle_files,
            owner = str(ctx.label),
            bucket_type = "unprocessed",
            parent_dir_param = parent_dir_param,
        )
        providers.append(resource_provider)

    return providers

apple_dynamic_framework_import = rule(
    implementation = _apple_dynamic_framework_import_impl,
    attrs = {
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
            doc = """
A list of targets that are dependencies of the target being built, which will be linked into that
target.
""",
            providers = [
                [apple_common.Objc, AppleFrameworkImportInfo],
            ],
        ),
    },
    doc = """
This rule encapsulates an already-built dynamic framework. It is defined by a list of files in
exactly one .framework directory. apple_dynamic_framework_import targets need to be added to library
targets through the `deps` attribute.
""",
)

apple_static_framework_import = rule(
    implementation = _apple_static_framework_import_impl,
    attrs = dicts.add(swift_common.toolchain_attrs(), {
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
            doc = """
A list of targets that are dependencies of the target being built, which will be
linked into that target.
""",
            providers = [
                [apple_common.Objc, AppleFrameworkImportInfo],
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
    }),
    doc = """
This rule encapsulates an already-built static framework. It is defined by a list of files in a
.framework directory. apple_static_framework_import targets need to be added to library targets
through the `deps` attribute.
""",
)
