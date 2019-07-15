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
    "@build_bazel_rules_apple//apple/internal/testing:macos_rules.bzl",
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
    """Packages a macOS application."""
    bundling_args = binary_support.create_binary(
        name,
        str(apple_common.platform_type.macos),
        apple_product_type.application,
        features = ["link_cocoa"],
        **kwargs
    )

    _macos_application(
        name = name,
        **bundling_args
    )

def macos_bundle(name, **kwargs):
    """Packages a macOS loadable bundle."""
    binary_args = dict(kwargs)

    # If a bundle loader was passed, re-write it to use the underlying
    # apple_binary target instead. When migrating to rules, we should validate
    # the attribute with providers.
    bundle_loader = binary_args.pop("bundle_loader", None)
    if bundle_loader:
        bundle_loader = "%s.__internal__.apple_binary" % bundle_loader
        binary_args["bundle_loader"] = bundle_loader

    features = binary_args.pop("features", [])
    features += ["link_cocoa"]

    bundling_args = binary_support.create_binary(
        name,
        str(apple_common.platform_type.macos),
        apple_product_type.bundle,
        binary_type = "loadable_bundle",
        features = features,
        **binary_args
    )

    _macos_bundle(
        name = name,
        **bundling_args
    )

def macos_quick_look_plugin(name, **kwargs):
    """Builds and bundles an macOS Quick Look plugin."""
    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.macos),
        include_entitlements = False,
        **kwargs
    )

    _macos_quick_look_plugin(
        name = name,
        **bundling_args
    )

def macos_kernel_extension(name, **kwargs):
    """Packages a macOS Kernel Extension."""
    binary_args = dict(kwargs)
    features = binary_args.pop("features", [])
    features += ["kernel_extension"]

    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.macos),
        features = features,
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
        **binary_args
    )

    _macos_xpc_service(
        name = name,
        **bundling_args
    )

def macos_command_line_application(name, **kwargs):
    """Builds a macOS command line application."""

    # Xcode will happily apply entitlements during code signing for a command line
    # tool even though it doesn't have a Capabilities tab in the project settings.
    # Until there's official support for it, we'll fail if we see those attributes
    # (which are added to the rule because of the code_signing_attributes usage in
    # the rule definition).
    if "entitlements" in kwargs or "provisioning_profile" in kwargs:
        fail("macos_command_line_application does not support entitlements or " +
             "provisioning profiles at this time")

    binary_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        include_entitlements = False,
        link_swift_statically = True,
        platform_type = str(apple_common.platform_type.macos),
        **kwargs
    )

    _macos_command_line_application(
        name = name,
        **binary_args
    )

def macos_dylib(name, **kwargs):
    """Builds a macOS dylib."""

    # Xcode will happily apply entitlements during code signing for a dylib even
    # though it doesn't have a Capabilities tab in the project settings.
    # Until there's official support for it, we'll fail if we see those attributes
    # (which are added to the rule because of the code_signing_attributes usage in
    # the rule definition).
    if "entitlements" in kwargs or "provisioning_profile" in kwargs:
        fail("macos_dylib does not support entitlements or provisioning " +
             "profiles at this time")

    binary_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        include_entitlements = False,
        link_swift_statically = True,
        platform_type = str(apple_common.platform_type.macos),
        **kwargs
    )

    _macos_dylib(
        name = name,
        **binary_args
    )

def macos_extension(name, **kwargs):
    """Packages a macOS Extension Bundle."""
    binary_args = dict(kwargs)

    features = binary_args.pop("features", [])
    features += ["link_cocoa"]

    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.macos),
        features = features,
        **binary_args
    )

    _macos_extension(
        name = name,
        **bundling_args
    )

def macos_unit_test(
        name,
        test_host = None,
        **kwargs):
    """Builds macOS XCTest test target."""

    # Discard binary_tags for now, as there is no apple_binary target any more to apply them to.
    # TODO(kaipi): Cleanup binary_tags for tests and remove this.
    kwargs.pop("binary_tags", None)

    # Discard any testonly attributes that may have been passed in kwargs. Since this is a test
    # rule, testonly should be a noop. Instead, force the add_entitlements_and_swift_linkopts method
    # to have testonly to True since it's always going to be a dependency of a test target. This can
    # be removed when we migrate the swift linkopts targets into the rule implementations.
    testonly = kwargs.pop("testonly", None)

    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.macos),
        include_entitlements = False,
        testonly = True,
        **kwargs
    )

    bundle_loader = None
    if test_host:
        bundle_loader = test_host
    _macos_unit_test(
        name = name,
        bundle_loader = bundle_loader,
        test_host = test_host,
        **bundling_args
    )

def macos_ui_test(
        name,
        **kwargs):
    """Builds an macOS XCUITest test target."""

    # Discard binary_tags for now, as there is no apple_binary target any more to apply them to.
    # TODO(kaipi): Cleanup binary_tags for tests and remove this.
    kwargs.pop("binary_tags", None)

    # Discard any testonly attributes that may have been passed in kwargs. Since this is a test
    # rule, testonly should be a noop. Instead, force the add_entitlements_and_swift_linkopts method
    # to have testonly to True since it's always going to be a dependency of a test target. This can
    # be removed when we migrate the swift linkopts targets into the rule implementations.
    testonly = kwargs.pop("testonly", None)

    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.macos),
        include_entitlements = False,
        testonly = True,
        **kwargs
    )

    _macos_ui_test(name = name, **bundling_args)
