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

"""Partial implementation for Swift static frameworks."""

load(
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/internal:processor.bzl",
    "processor",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

def _modulemap_contents(module_name):
    """Returns the contents for the modulemap file for the framework."""
    return """\
framework module {module_name} {{
  header "{module_name}.h"
  requires objc
}}
""".format(module_name = module_name)

def _swift_static_framework_partial_impl(
        *,
        actions,
        bundle_name,
        label_name,
        swift_static_framework_info):
    """Implementation for the Swift static framework processing partial."""

    expected_module_name = bundle_name
    if expected_module_name != swift_static_framework_info.module_name:
        fail("""
error: Found swift_library with module name '{actual}' but expected '{expected}'. Swift static \
frameworks expect a single swift_library dependency with `module_name` set to the same \
`bundle_name` as the static framework target.\
""".format(
            actual = swift_static_framework_info.module_name,
            expected = expected_module_name,
        ))

    generated_header = swift_static_framework_info.generated_header
    swiftdocs = swift_static_framework_info.swiftdocs
    swiftinterfaces = swift_static_framework_info.swiftinterfaces

    bundle_files = []
    modules_parent = paths.join("Modules", "{}.swiftmodule".format(expected_module_name))

    for arch, swiftinterface in swiftinterfaces.items():
        bundle_interface = intermediates.file(
            actions,
            label_name,
            "{}.swiftinterface".format(arch),
        )
        actions.symlink(
            target_file = swiftinterface,
            output = bundle_interface,
        )
        bundle_files.append((processor.location.bundle, modules_parent, depset([bundle_interface])))

    for arch, swiftdoc in swiftdocs.items():
        bundle_doc = intermediates.file(actions, label_name, "{}.swiftdoc".format(arch))
        actions.symlink(
            target_file = swiftdoc,
            output = bundle_doc,
        )
        bundle_files.append((processor.location.bundle, modules_parent, depset([bundle_doc])))

    if generated_header:
        bundle_header = intermediates.file(
            actions,
            label_name,
            "{}.h".format(expected_module_name),
        )
        actions.symlink(
            target_file = generated_header,
            output = bundle_header,
        )
        bundle_files.append((processor.location.bundle, "Headers", depset([bundle_header])))

        modulemap = intermediates.file(actions, label_name, "module.modulemap")
        actions.write(modulemap, _modulemap_contents(expected_module_name))
        bundle_files.append((processor.location.bundle, "Modules", depset([modulemap])))

    return struct(bundle_files = bundle_files)

def swift_static_framework_partial(
        *,
        actions,
        bundle_name,
        label_name,
        swift_static_framework_info):
    """Constructor for the Swift static framework processing partial.

    This partial collects and bundles the necessary files to construct a Swift based static
    framework.

    Args:
        actions: The actions provider from `ctx.actions`.
        bundle_name: The name of the output bundle.
        label_name: Name of the target being built.
        swift_static_framework_info: The SwiftStaticFrameworkInfo provider containing the required
            artifacts.

    Returns:
        A partial that returns the bundle location of the supporting Swift artifacts needed in a
        Swift based static framework.
    """
    return partial.make(
        _swift_static_framework_partial_impl,
        actions = actions,
        bundle_name = bundle_name,
        label_name = label_name,
        swift_static_framework_info = swift_static_framework_info,
    )
