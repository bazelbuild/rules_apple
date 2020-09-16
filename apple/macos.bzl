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

"""Bazel rules for creating macOS applications and bundles."""

load(
    "@build_bazel_rules_apple//apple/internal/testing:apple_test_assembler.bzl",
    "apple_test_assembler",
)
load(
    "@build_bazel_rules_apple//apple/internal/testing:build_test_rules.bzl",
    "apple_build_test_rule",
)
load(
    "@build_bazel_rules_apple//apple/internal/testing:macos_rules.bzl",
    _macos_internal_ui_test_bundle = "macos_internal_ui_test_bundle",
    _macos_internal_unit_test_bundle = "macos_internal_unit_test_bundle",
    _macos_ui_test = "macos_ui_test",
    _macos_unit_test = "macos_unit_test",
)
load(
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/internal:binary_support.bzl",
    "binary_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:macos_binary_support.bzl",
    "macos_binary_infoplist",
    "macos_command_line_launchdplist",
)
load(
    "@build_bazel_rules_apple//apple/internal:macos_rules.bzl",
    _macos_application = "macos_application",
    _macos_bundle = "macos_bundle",
    _macos_command_line_application = "macos_command_line_application",
    _macos_dylib = "macos_dylib",
    _macos_extension = "macos_extension",
    _macos_kernel_extension = "macos_kernel_extension",
    _macos_quick_look_plugin = "macos_quick_look_plugin",
    _macos_spotlight_importer = "macos_spotlight_importer",
    _macos_xpc_service = "macos_xpc_service",
)

def macos_application(name, **kwargs):
    # buildifier: disable=function-docstring-args
    """Packages a macOS application."""
    binary_args = dict(kwargs)
    features = binary_args.pop("features", [])
    features.append("link_cocoa")

    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.macos),
        product_type = apple_product_type.application,
        features = features,
        **binary_args
    )

    _macos_application(
        name = name,
        **bundling_args
    )

def macos_bundle(name, **kwargs):
    # buildifier: disable=function-docstring-args
    """Packages a macOS loadable bundle."""
    binary_args = dict(kwargs)
    features = binary_args.pop("features", [])
    features.append("link_cocoa")

    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.macos),
        product_type = apple_product_type.bundle,
        features = features,
        exported_symbols_lists = binary_args.pop("exported_symbols_lists", None),
        **binary_args
    )

    _macos_bundle(
        name = name,
        **bundling_args
    )

def macos_quick_look_plugin(name, **kwargs):
    # buildifier: disable=function-docstring-args
    """Builds and bundles an macOS Quick Look plugin."""
    binary_args = dict(kwargs)

    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.macos),
        product_type = apple_product_type.quicklook_plugin,
        include_entitlements = False,
        exported_symbols_lists = binary_args.pop("exported_symbols_lists", None),
        **binary_args
    )

    _macos_quick_look_plugin(
        name = name,
        **bundling_args
    )

def macos_kernel_extension(name, **kwargs):
    # buildifier: disable=function-docstring-args
    """Packages a macOS Kernel Extension."""
    binary_args = dict(kwargs)
    features = binary_args.pop("features", [])
    features.append("kernel_extension")

    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.macos),
        product_type = apple_product_type.kernel_extension,
        features = features,
        exported_symbols_lists = binary_args.pop("exported_symbols_lists", None),
        **binary_args
    )

    _macos_kernel_extension(
        name = name,
        **bundling_args
    )

def macos_spotlight_importer(name, **kwargs):
    """Packages a macOS Spotlight Importer Bundle."""
    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.macos),
        product_type = apple_product_type.spotlight_importer,
        **kwargs
    )

    _macos_spotlight_importer(
        name = name,
        **bundling_args
    )

def macos_xpc_service(name, **kwargs):
    """Packages a macOS XPC Service Application."""
    binary_args = dict(kwargs)

    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.macos),
        product_type = apple_product_type.xpc_service,
        **binary_args
    )

    _macos_xpc_service(
        name = name,
        **bundling_args
    )

def macos_command_line_application(name, **kwargs):
    # buildifier: disable=function-docstring-args
    """Builds a macOS command line application."""

    # Xcode will happily apply entitlements during code signing for a command line
    # tool even though it doesn't have a Capabilities tab in the project settings.
    # Until there's official support for it, we'll fail if we see those attributes
    # (which are added to the rule because of the code_signing_attributes usage in
    # the rule definition).
    if "entitlements" in kwargs or "provisioning_profile" in kwargs:
        fail("macos_command_line_application does not support entitlements or " +
             "provisioning profiles at this time")

    binary_args = dict(kwargs)

    original_deps = binary_args.pop("deps")
    binary_deps = list(original_deps)

    # If any of the Info.plist-affecting attributes is provided, create a merged
    # Info.plist target. This target also propagates an objc provider that
    # contains the linkopts necessary to add the Info.plist to the binary, so it
    # must become a dependency of the binary as well.
    bundle_id = binary_args.get("bundle_id")
    infoplists = binary_args.get("infoplists")
    launchdplists = binary_args.get("launchdplists")
    version = binary_args.get("version")

    if bundle_id or infoplists or version:
        merged_infoplist_name = name + ".merged_infoplist"

        macos_binary_infoplist(
            name = merged_infoplist_name,
            bundle_id = bundle_id,
            infoplists = infoplists,
            minimum_os_version = binary_args.get("minimum_os_version"),
            version = version,
        )
        binary_deps.extend([":" + merged_infoplist_name])

    if launchdplists:
        merged_launchdplists_name = name + ".merged_launchdplists"

        macos_command_line_launchdplist(
            name = merged_launchdplists_name,
            launchdplists = launchdplists,
        )
        binary_deps.extend([":" + merged_launchdplists_name])

    cmd_line_app_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.macos),
        product_type = apple_product_type.tool,
        link_swift_statically = True,
        include_entitlements = False,
        exported_symbols_lists = binary_args.pop("exported_symbols_lists", None),
        deps = binary_deps,
        **binary_args
    )

    _macos_command_line_application(
        name = name,
        **cmd_line_app_args
    )

def macos_dylib(name, **kwargs):
    # buildifier: disable=function-docstring-args
    """Builds a macOS dylib."""

    # Xcode will happily apply entitlements during code signing for a dylib even
    # though it doesn't have a Capabilities tab in the project settings.
    # Until there's official support for it, we'll fail if we see those attributes
    # (which are added to the rule because of the code_signing_attributes usage in
    # the rule definition).
    if "entitlements" in kwargs or "provisioning_profile" in kwargs:
        fail("macos_dylib does not support entitlements or provisioning " +
             "profiles at this time")

    binary_args = dict(kwargs)

    original_deps = binary_args.pop("deps")
    binary_deps = list(original_deps)

    # If any of the Info.plist-affecting attributes is provided, create a merged
    # Info.plist target. This target also propagates an objc provider that
    # contains the linkopts necessary to add the Info.plist to the binary, so it
    # must become a dependency of the binary as well.
    bundle_id = binary_args.get("bundle_id")
    infoplists = binary_args.get("infoplists")
    version = binary_args.get("version")

    if bundle_id or infoplists or version:
        merged_infoplist_name = name + ".merged_infoplist"

        macos_binary_infoplist(
            name = merged_infoplist_name,
            bundle_id = bundle_id,
            infoplists = infoplists,
            minimum_os_version = binary_args.get("minimum_os_version"),
            version = version,
        )
        binary_deps.extend([":" + merged_infoplist_name])

    dylib_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.macos),
        product_type = apple_product_type.dylib,
        link_swift_statically = True,
        include_entitlements = False,
        exported_symbols_lists = binary_args.pop("exported_symbols_lists", None),
        deps = binary_deps,
        **binary_args
    )

    _macos_dylib(
        name = name,
        **dylib_args
    )

def macos_extension(name, **kwargs):
    # buildifier: disable=function-docstring-args
    """Packages a macOS Extension Bundle."""
    binary_args = dict(kwargs)

    features = binary_args.pop("features", [])
    features.append("link_cocoa")

    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.macos),
        product_type = apple_product_type.app_extension,
        features = features,
        **binary_args
    )

    _macos_extension(
        name = name,
        **bundling_args
    )

_DEFAULT_TEST_RUNNER = "@build_bazel_rules_apple//apple/testing/default_runner:macos_default_runner"

def macos_unit_test(name, **kwargs):
    runner = kwargs.pop("runner", _DEFAULT_TEST_RUNNER)
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _macos_internal_unit_test_bundle,
        test_rule = _macos_unit_test,
        runner = runner,
        bundle_loader = kwargs.get("test_host"),
        dylibs = kwargs.get("frameworks"),
        **kwargs
    )

def macos_ui_test(name, **kwargs):
    runner = kwargs.pop("runner", _DEFAULT_TEST_RUNNER)
    apple_test_assembler.assemble(
        name = name,
        bundle_rule = _macos_internal_ui_test_bundle,
        test_rule = _macos_ui_test,
        runner = runner,
        dylibs = kwargs.get("frameworks"),
        **kwargs
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
