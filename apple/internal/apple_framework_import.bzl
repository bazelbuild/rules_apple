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

"""Implementation of apple_framework_import."""

load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
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

def _validate_single_framework(framework_paths):
    """Validates that there is only 1 framework being imported.

    This method validates that only 1 framework is imported by this target, even if it is composed
    by multiple .framework bundles. In such a case, all of them must have the same name.

    Args:
        framework_paths: List of .framework containers being imported by the target.
    """
    framework_names = {}
    for framework_path in framework_paths:
        framework_names[paths.basename(framework_path)] = None
    if len(framework_names) > 1:
        fail(
            "There has to be exactly 1 imported framework. Found:\n{}".format(
                "\n".join(framework_names),
            ),
        )

def _apple_framework_import_impl(ctx):
    """Implementation for the apple_framework_import rule."""
    framework_imports = ctx.files.framework_imports
    framework_groups = group_files_by_directory(
        framework_imports,
        ["framework"],
        attr = "framework_imports",
    )

    _validate_single_framework(framework_groups.keys())

    providers = []

    framework_imports_set = depset(framework_imports)
    framework_dirs_set = depset(framework_groups.keys())
    objc_provider_fields = {}

    if ctx.attr.is_dynamic:
        if any([ctx.attr.sdk_dylibs, ctx.attr.sdk_frameworks, ctx.attr.weak_sdk_frameworks]):
            fail(
                "Error: sdk_dylibs, sdk_frameworks and weak_sdk_frameworks can only be set for " +
                "static frameworks (i.e. is_dynamic = False)",
            )

        objc_provider_fields["dynamic_framework_file"] = framework_imports_set
        objc_provider_fields["dynamic_framework_dir"] = framework_dirs_set

        filtered_framework_imports = filter_framework_imports_for_bundling(framework_imports)
        if filtered_framework_imports:
            providers.append(
                AppleFrameworkImportInfo(framework_imports = depset(filtered_framework_imports)),
            )
    else:
        if ctx.attr.sdk_dylibs:
            objc_provider_fields["sdk_dylib"] = depset(direct = ctx.attr.sdk_dylibs)
        if ctx.attr.sdk_frameworks:
            objc_provider_fields["sdk_framework"] = depset(direct = ctx.attr.sdk_frameworks)
        if ctx.attr.weak_sdk_frameworks:
            objc_provider_fields["weak_sdk_framework"] = depset(direct = ctx.attr.weak_sdk_frameworks)
        objc_provider_fields["static_framework_file"] = framework_imports_set

    # TODO(kaipi): Remove this dummy binary. It is only required because the
    # new_dynamic_framework_provider Skylark API does not accept None as an argument for the binary
    # argument. This change was submitted in https://github.com/bazelbuild/bazel/commit/f8ffac. We
    # can't remove this until that change is released in bazel.
    dummy_binary = ctx.actions.declare_file("_{}.dummy_binary".format(ctx.label.name))
    ctx.actions.write(dummy_binary, "_dummy_file_")

    objc_provider = apple_common.new_objc_provider(**objc_provider_fields)
    providers.append(objc_provider)
    providers.append(
        apple_common.new_dynamic_framework_provider(
            binary = dummy_binary,
            objc = objc_provider,
            framework_dirs = framework_dirs_set,
            framework_files = framework_imports_set,
        ),
    )
    return providers

apple_framework_import = rule(
    implementation = _apple_framework_import_impl,
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
        "is_dynamic": attr.bool(
            mandatory = True,
            doc = """
Indicates whether this framework is linked dynamically or not. If this attribute is set to True, the
final application binary will link against this framework and also be copied into the final
application bundle inside the Frameworks directory. If this attribute is False, the framework will
be statically linked into the final application binary instead.
""",
        ),
        "sdk_dylibs": attr.string_list(
            doc = """
Names of SDK .dylib libraries to link with. For instance, `libz` or `libarchive`. `libc++` is
included automatically if the binary has any C++ or Objective-C++ sources in its dependency tree.
When linking a binary, all libraries named in that binary's transitive dependency graph are used.
Only applicable for static frameworks (i.e. `is_dynamic = False`).
""",
        ),
        "sdk_frameworks": attr.string_list(
            doc = """
Names of SDK frameworks to link with (e.g. `AddressBook`, `QuartzCore`). `UIKit` and `Foundation`
are always included when building for the iOS, tvOS and watchOS platforms. For macOS, only
`Foundation` is always included. When linking a top level binary, all SDK frameworks listed in that
binary's transitive dependency graph are linked. Only applicable for static frameworks (i.e.
`is_dynamic = False`).
""",
        ),
        "weak_sdk_frameworks": attr.string_list(
            doc = """
Names of SDK frameworks to weakly link with. For instance, `MediaAccessibility`. In difference to
regularly linked SDK frameworks, symbols from weakly linked frameworks do not cause an error if they
are not present at runtime. Only applicable for static frameworks (i.e. `is_dynamic = False`).
""",
        ),
    },
    doc = """
This rule encapsulates an already-built framework. It is defined by a list of files in exactly one
.framework directory. apple_framework_import targets need to be added to library targets through the
`deps` attribute.
""",
)
