# Copyright 2017 The Bazel Authors. All rights reserved.
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

"""
# Bazel rules for creating macOS applications and bundles.
"""

load(
    "//apple/internal:macos_binary_support.bzl",
    "macos_binary_infoplist",
    "macos_command_line_launchdplist",
)
load(
    "//apple/internal:macos_rules.bzl",
    _macos_application = "macos_application",
    _macos_bundle = "macos_bundle",
    _macos_command_line_application = "macos_command_line_application",
    _macos_dylib = "macos_dylib",
    _macos_dynamic_framework = "macos_dynamic_framework",
    _macos_extension = "macos_extension",
    _macos_framework = "macos_framework",
    _macos_kernel_extension = "macos_kernel_extension",
    _macos_quick_look_plugin = "macos_quick_look_plugin",
    _macos_spotlight_importer = "macos_spotlight_importer",
    _macos_static_framework = "macos_static_framework",
    _macos_xpc_service = "macos_xpc_service",
)
load(
    "//apple/internal:macro_factory.bzl",
    "macro_factory",
)
load(
    "//apple/internal/testing:apple_test_assembler.bzl",
    "apple_test_assembler",
)
load(
    "//apple/internal/testing:build_test_rules.bzl",
    "apple_build_test_rule",
)
load(
    "//apple/internal/testing:macos_rules.bzl",
    _macos_internal_ui_test_bundle = "macos_internal_ui_test_bundle",
    _macos_internal_unit_test_bundle = "macos_internal_unit_test_bundle",
    _macos_ui_test = "macos_ui_test",
    _macos_unit_test = "macos_unit_test",
)

# TODO(b/118104491): Remove these re-exports and move the rule definitions into this file.
macos_quick_look_plugin = _macos_quick_look_plugin
macos_spotlight_importer = _macos_spotlight_importer
macos_xpc_service = _macos_xpc_service

def _macos_application_impl(name, visibility, **kwargs):
    features = (kwargs.pop("features", None) or []) + ["link_cocoa"]

    _macos_application(
        name = name,
        features = features,
        visibility = visibility,
        **kwargs
    )

macos_application = macro(
    implementation = _macos_application_impl,
    inherit_attrs = _macos_application,
    doc = """
Packages a macOS application.
""",
)

def _macos_bundle_impl(name, visibility, **kwargs):
    features = (kwargs.pop("features", None) or []) + ["link_cocoa"]

    _macos_bundle(
        name = name,
        features = features,
        visibility = visibility,
        **kwargs
    )

macos_bundle = macro(
    implementation = _macos_bundle_impl,
    inherit_attrs = _macos_bundle,
    doc = """
Packages a macOS loadable bundle.
""",
)

def _macos_kernel_extension_impl(name, visibility, **kwargs):
    features = (kwargs.pop("features", None) or []) + ["kernel_extension"]

    _macos_kernel_extension(
        name = name,
        features = features,
        visibility = visibility,
        **kwargs
    )

macos_kernel_extension = macro(
    implementation = _macos_kernel_extension_impl,
    inherit_attrs = _macos_kernel_extension,
    doc = """
Packages a macOS Kernel Extension.
""",
)

def _macos_command_line_application_impl(name, visibility, **kwargs):
    deps = (kwargs.pop("deps", None) or [])
    additional_deps = []

    # If any of the Info.plist-affecting attributes is provided, create a merged
    # Info.plist target. This target also propagates CcInfo with the linkopts
    # necessary to add the Info.plist to the binary, so it must become a
    # dependency of the binary as well.
    base_bundle_id = kwargs.get("base_bundle_id")
    bundle_id = kwargs.get("bundle_id")
    infoplists = kwargs.get("infoplists")
    launchdplists = kwargs.get("launchdplists")
    version = kwargs.get("version")

    if base_bundle_id or bundle_id or infoplists or version:
        merged_infoplist_name = name + ".merged_infoplist"

        macos_binary_infoplist(
            name = merged_infoplist_name,
            base_bundle_id = base_bundle_id,
            bundle_id = bundle_id,
            bundle_id_suffix = kwargs.get("bundle_id_suffix"),
            infoplists = infoplists,
            minimum_os_version = kwargs.get("minimum_os_version"),
            version = version,
        )
        additional_deps.append(":" + merged_infoplist_name)

    if launchdplists:
        merged_launchdplists_name = name + ".merged_launchdplists"

        macos_command_line_launchdplist(
            name = merged_launchdplists_name,
            launchdplists = launchdplists,
            minimum_os_version = kwargs.get("minimum_os_version"),
        )
        additional_deps.append(":" + merged_launchdplists_name)

    _macos_command_line_application(
        name = name,
        deps = deps + additional_deps,
        visibility = visibility,
        **kwargs
    )

macos_command_line_application = macro(
    implementation = _macos_command_line_application_impl,
    inherit_attrs = _macos_command_line_application,
    doc = """
Builds a macOS command line application.
""",
)

def _macos_dylib_impl(name, visibility, **kwargs):
    # Xcode will happily apply entitlements during code signing for a dylib even
    # though it doesn't have a Capabilities tab in the project settings.
    # Until there's official support for it, we'll fail if we see those attributes
    # (which are added to the rule because of the code_signing_attributes usage in
    # the rule definition).
    if kwargs.get("entitlements") or kwargs.get("provisioning_profile"):
        fail("macos_dylib does not support entitlements or provisioning " +
             "profiles at this time")

    deps = (kwargs.pop("deps", None) or [])
    additional_deps = []

    # If any of the Info.plist-affecting attributes is provided, create a merged
    # Info.plist target. This target also propagates CcInfo with the linkopts
    # necessary to add the Info.plist to the binary, so it must become a
    # dependency of the binary as well.
    base_bundle_id = kwargs.get("base_bundle_id")
    bundle_id = kwargs.get("bundle_id")
    infoplists = kwargs.get("infoplists")
    version = kwargs.get("version")

    if base_bundle_id or bundle_id or infoplists or version:
        merged_infoplist_name = name + ".merged_infoplist"

        macos_binary_infoplist(
            name = merged_infoplist_name,
            base_bundle_id = base_bundle_id,
            bundle_id = bundle_id,
            bundle_id_suffix = kwargs.get("bundle_id_suffix"),
            infoplists = infoplists,
            minimum_os_version = kwargs.get("minimum_os_version"),
            version = version,
        )
        additional_deps.append(":" + merged_infoplist_name)

    _macos_dylib(
        name = name,
        deps = deps + additional_deps,
        visibility = visibility,
        **kwargs
    )

macos_dylib = macro(
    implementation = _macos_dylib_impl,
    inherit_attrs = _macos_dylib,
    doc = """
Builds a macOS dylib.
""",
)

def _macos_extension_impl(name, visibility, **kwargs):
    features = (kwargs.pop("features", None) or []) + ["link_cocoa"]

    _macos_extension(
        name = name,
        features = features,
        visibility = visibility,
        **kwargs
    )

macos_extension = macro(
    implementation = _macos_extension_impl,
    inherit_attrs = _macos_extension,
    doc = """
Packages a macOS Extension Bundle.
""",
)

def _macos_framework_impl(name, visibility, **kwargs):
    features = (kwargs.pop("features", None) or []) + ["link_cocoa"]

    _macos_framework(
        name = name,
        features = features,
        visibility = visibility,
        **kwargs
    )

macos_framework = macro(
    implementation = _macos_framework_impl,
    inherit_attrs = _macos_framework,
    doc = """
Packages a macOS framework.
""",
)

def _macos_static_framework_impl(name, visibility, **kwargs):
    features = (kwargs.pop("features", None) or []) + ["link_cocoa"]

    _macos_static_framework(
        name = name,
        features = features,
        visibility = visibility,
        **kwargs
    )

macos_static_framework = macro(
    implementation = _macos_static_framework_impl,
    inherit_attrs = _macos_static_framework,
    doc = """
Packages a macOS framework.
""",
)

def _macos_dynamic_framework_impl(name, visibility, **kwargs):
    features = (kwargs.pop("features", None) or []) + ["link_cocoa"]

    _macos_dynamic_framework(
        name = name,
        features = features,
        visibility = visibility,
        **kwargs
    )

macos_dynamic_framework = macro(
    implementation = _macos_dynamic_framework_impl,
    inherit_attrs = _macos_dynamic_framework,
    doc = """
Packages a macOS framework.
""",
)

_DEFAULT_TEST_RUNNER = Label("//apple/testing/default_runner:macos_default_runner")

def _macos_unit_test_impl(name, visibility, runner, **kwargs):
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _macos_internal_unit_test_bundle,
        test_rule = _macos_unit_test,
        runner = runner,
        visibility = visibility,
        **kwargs
    )

macos_unit_test = macro_factory.create_apple_test_macro(
    implementation = _macos_unit_test_impl,
    inherit_attrs = _macos_unit_test,
    default_runner = _DEFAULT_TEST_RUNNER,
    platform_attrs = "macos",
    doc = """
Builds and bundles a macOS unit `.xctest` test bundle. Runs the tests using the
provided test runner when invoked with `bazel test`.

`macos_unit_test` targets can work in two modes: as app or library tests. If the
`test_host` attribute is set to an `macos_application` target, the tests will
run within that application's context. If no `test_host` is provided, the tests
will run outside the context of an macOS application. Because of this, certain
functionalities might not be present (e.g. UI layout, NSUserDefaults). You can
find more information about testing for Apple platforms
[here](https://developer.apple.com/library/content/documentation/DeveloperTools/Conceptual/testing_with_xcode/chapters/03-testing_basics.html).
""",
)

def _macos_ui_test_impl(name, visibility, runner, **kwargs):
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _macos_internal_ui_test_bundle,
        test_rule = _macos_ui_test,
        runner = runner,
        visibility = visibility,
        **kwargs
    )

macos_ui_test = macro_factory.create_apple_test_macro(
    implementation = _macos_ui_test_impl,
    inherit_attrs = _macos_ui_test,
    default_runner = _DEFAULT_TEST_RUNNER,
    platform_attrs = "macos",
    doc = """
Builds and bundles an iOS UI `.xctest` test bundle. Runs the tests using the
provided test runner when invoked with `bazel test`.

Note: macOS UI tests are not currently supported in the default test runner.
""",
)

macos_build_test = apple_build_test_rule(
    doc = """\
Test rule to check that the given library targets (Swift, Objective-C, C++)
build for macOS.

Typical usage:

```starlark
macos_build_test(
    name = "my_build_test",
    minimum_os_version = "10.14",
    targets = [
        "//some/package:my_library",
    ],
)
```
""",
    platform_type = "macos",
)
