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
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleResourceBundleInfo",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "group_files_by_directory",
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

# TODO(kaipi): Once objc_framework is gone, make this method private, as outside of this file, it
# should only be used in the framework_import aspect.
def filter_framework_imports_for_bundling(framework_imports):
    """Returns the list of files that should be bundled for dynamic framework bundles."""

    # Filter headers and module maps so that they are not propagated to be bundled with the rest
    # of the framework.
    filtered_imports = []
    for file in framework_imports:
        file_short_path = file.short_path
        if file_short_path.endswith(".h"):
            continue
        if file_short_path.endswith(".modulemap"):
            continue
        if "Headers/" in file_short_path:
            # This matches /Headers/ and /PrivateHeaders/
            continue
        if "/Modules/" in file_short_path:
            continue
        filtered_imports.append(file)

    return filtered_imports

def _all_framework_binaries(frameworks_groups):
    return [
        _get_framework_binary_file(framework_dir, framework_imports.to_list())
        for framework_dir, framework_imports in frameworks_groups.items()
    ]

def _get_framework_binary_file(framework_dir, framework_imports):
    framework_name = paths.split_extension(paths.basename(framework_dir))[0]
    framework_short_path = paths.join(framework_dir, framework_name)
    for framework_import in framework_imports:
        if framework_import.short_path == framework_short_path:
            return framework_import

    fail("ERORR: There has to be a binary file in the imported framework.")

def _framework_dirs(framework_imports):
    """Implementation for the apple_dynamic_framework_import rule."""
    framework_groups = group_files_by_directory(
        framework_imports,
        ["framework"],
        attr = "framework_imports",
    )

    # TODO(b/120920467): Add validation to ensure only a single framework is being imported.

    return framework_groups

def _objc_provider_with_dependencies(ctx, objc_provider_fields):
    objc_provider_fields["providers"] = [dep[apple_common.Objc] for dep in ctx.attr.deps]
    return apple_common.new_objc_provider(**objc_provider_fields)

def _apple_dynamic_framework_import_impl(ctx):
    """Implementation for the apple_dynamic_framework_import rule."""
    transitive_sets = []
    for dep in ctx.attr.deps:
        if hasattr(dep[AppleFrameworkImportInfo], "framework_imports"):
            transitive_sets.append(dep[AppleFrameworkImportInfo].framework_imports)

    filtered_framework_imports = filter_framework_imports_for_bundling(ctx.files.framework_imports)
    if filtered_framework_imports:
        transitive_sets.append(depset(filtered_framework_imports))

    providers = []

    provider_fields = {}
    if transitive_sets:
        provider_fields["framework_imports"] = depset(transitive = transitive_sets)
    providers.append(AppleFrameworkImportInfo(**provider_fields))

    framework_groups = _framework_dirs(ctx.files.framework_imports)
    framework_dirs_set = depset(framework_groups.keys())
    objc_provider = _objc_provider_with_dependencies(ctx, {
        "dynamic_framework_file": depset(ctx.files.framework_imports),
        "dynamic_framework_dir": framework_dirs_set,
    })
    providers.append(objc_provider)

    # TODO(kaipi): Remove this dummy binary. It is only required because the
    # new_dynamic_framework_provider Skylark API does not accept None as an argument for the binary
    # argument. This change was submitted in https://github.com/bazelbuild/bazel/commit/f8ffac. We
    # can't remove this until that change is released in bazel.
    dummy_binary = ctx.actions.declare_file("_{}.dummy_binary".format(ctx.label.name))
    ctx.actions.write(dummy_binary, "_dummy_file_")
    providers.append(apple_common.new_dynamic_framework_provider(
        binary = dummy_binary,
        objc = objc_provider,
        framework_dirs = framework_dirs_set,
        framework_files = depset(ctx.files.framework_imports),
    ))

    return providers

def _apple_static_framework_import_impl(ctx):
    """Implementation for the apple_static_framework_import rule."""
    providers = []

    framework_imports = ctx.files.framework_imports
    objc_provider_fields = {
        "static_framework_file": depset(framework_imports),
    }

    framework_groups = _framework_dirs(ctx.files.framework_imports)
    if ctx.attr.alwayslink:
        objc_provider_fields["force_load_library"] = depset(
            _all_framework_binaries(framework_groups),
        )
    if ctx.attr.sdk_dylibs:
        objc_provider_fields["sdk_dylib"] = depset(ctx.attr.sdk_dylibs)
    if ctx.attr.sdk_frameworks:
        objc_provider_fields["sdk_framework"] = depset(ctx.attr.sdk_frameworks)
    if ctx.attr.weak_sdk_frameworks:
        objc_provider_fields["weak_sdk_framework"] = depset(ctx.attr.weak_sdk_frameworks)

    providers.append(_objc_provider_with_dependencies(ctx, objc_provider_fields))

    bundle_files = [x for x in framework_imports if ".bundle/" in x.short_path]
    if bundle_files:
        parent_dir_param = partial.make(
            resources.bundle_relative_parent_dir,
            extension = "bundle",
        )
        resource_provider = resources.bucketize(
            bundle_files,
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
A list of targets that are dependencies of the target being built, which will be
linked into that target.
""",
            providers = [
                [apple_common.Objc, AppleFrameworkImportInfo],
            ],
        ),
    },
    doc = """
This rule encapsulates an already-built framework. It is defined by a list of files in exactly one
.framework directory. apple_dynamic_framework_import targets need to be added to library targets through the
`deps` attribute.
""",
)

apple_static_framework_import = rule(
    implementation = _apple_static_framework_import_impl,
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
        "alwayslink": attr.bool(
            default = False,
            doc = """
If true, any binary that depends (directly or indirectly) on this framework
will link in all the object files for the framework file, even if some
contain no symbols referenced by the binary. This is useful if your code isn't
explicitly called by code in the binary; for example, if you rely on runtime
checks for protocol conformances added in extensions in the library but do not
directly reference any other symbols in the object file that adds that
conformance.
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
    },
    doc = """
This rule encapsulates an already-built static framework. It is defined by a list of files in a
.framework directory. apple_static_framework_import targets need to be added to library targets
through the `deps` attribute.
""",
)
