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

"""Implementation of macOS test rules."""

load(
    "@build_bazel_rules_apple//apple/internal/testing:apple_test_rule_support.bzl",
    "apple_test_rule_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/testing:apple_test_bundle_support.bzl",
    "apple_test_bundle_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_factory.bzl",
    "rule_factory",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "MacosXcTestBundleInfo",
)

def _macos_ui_test_bundle_impl(ctx):
    """Implementation of macos_ui_test."""
    return apple_test_bundle_support.apple_test_bundle_impl(ctx) + [
        MacosXcTestBundleInfo(),
    ]

def _macos_unit_test_bundle_impl(ctx):
    """Implementation of macos_unit_test."""
    return apple_test_bundle_support.apple_test_bundle_impl(ctx) + [
        MacosXcTestBundleInfo(),
    ]

def _macos_ui_test_impl(ctx):
    """Implementation of macos_ui_test."""
    return apple_test_rule_support.apple_test_rule_impl(ctx, "xcuitest") + [
        MacosXcTestBundleInfo(),
    ]

def _macos_unit_test_impl(ctx):
    """Implementation of macos_unit_test."""
    return apple_test_rule_support.apple_test_rule_impl(ctx, "xctest") + [
        MacosXcTestBundleInfo(),
    ]

# Declare it with an underscore so it shows up that way in queries.
_macos_internal_ui_test_bundle = rule_factory.create_apple_bundling_rule(
    implementation = _macos_ui_test_bundle_impl,
    platform_type = "macos",
    product_type = apple_product_type.ui_test_bundle,
    doc = "Builds and bundles an macOS UI Test Bundle.  Internal target not to be depended upon.",
)

# Alias to import it.
macos_internal_ui_test_bundle = _macos_internal_ui_test_bundle

macos_ui_test = rule_factory.create_apple_test_rule(
    implementation = _macos_ui_test_impl,
    doc = """Builds and bundles an iOS UI `.xctest` test bundle. Runs the tests using the
provided test runner when invoked with `bazel test`. When using Tulsi to run
tests built with this target, `runner` will not be used since Xcode is the test
runner in that case.

Note: macOS UI tests are not currently supported in the default test runner.""",
    platform_type = "macos",
)

# Declare it with an underscore so it shows up that way in queries.
_macos_internal_unit_test_bundle = rule_factory.create_apple_bundling_rule(
    implementation = _macos_unit_test_bundle_impl,
    platform_type = "macos",
    product_type = apple_product_type.unit_test_bundle,
    doc = "Builds and bundles an macOS Unit Test Bundle.  Internal target not to be depended upon.",
)

# Alias to import it.
macos_internal_unit_test_bundle = _macos_internal_unit_test_bundle

macos_unit_test = rule_factory.create_apple_test_rule(
    implementation = _macos_unit_test_impl,
    doc = """Builds and bundles a macOS unit `.xctest` test bundle. Runs the tests using the
provided test runner when invoked with `bazel test`. When using Tulsi to run
tests built with this target, `runner` will not be used since Xcode is the test
runner in that case.

`macos_unit_test` targets can work in two modes: as app or library tests. If the
`test_host` attribute is set to an `macos_application` target, the tests will
run within that application's context. If no `test_host` is provided, the tests
will run outside the context of an macOS application. Because of this, certain
functionalities might not be present (e.g. UI layout, NSUserDefaults). You can
find more information about testing for Apple platforms
[here](https://developer.apple.com/library/content/documentation/DeveloperTools/Conceptual/testing_with_xcode/chapters/03-testing_basics.html).""",
    platform_type = "macos",
)
