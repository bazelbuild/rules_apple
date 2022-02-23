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

"""Implementation of iOS test rules."""

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
    "IosXcTestBundleInfo",
)

def _ios_ui_test_bundle_impl(ctx):
    """Implementation of ios_ui_test."""
    return apple_test_bundle_support.apple_test_bundle_impl(ctx) + [
        IosXcTestBundleInfo(),
    ]

def _ios_unit_test_bundle_impl(ctx):
    """Implementation of ios_unit_test."""
    return apple_test_bundle_support.apple_test_bundle_impl(ctx) + [
        IosXcTestBundleInfo(),
    ]

def _ios_ui_test_impl(ctx):
    """Implementation of ios_ui_test."""
    return apple_test_rule_support.apple_test_rule_impl(ctx, "xcuitest") + [
        IosXcTestBundleInfo(),
    ]

def _ios_unit_test_impl(ctx):
    """Implementation of ios_unit_test."""
    return apple_test_rule_support.apple_test_rule_impl(ctx, "xctest") + [
        IosXcTestBundleInfo(),
    ]

# Declare it with an underscore so it shows up that way in queries.
_ios_internal_ui_test_bundle = rule_factory.create_apple_bundling_rule(
    implementation = _ios_ui_test_bundle_impl,
    platform_type = "ios",
    product_type = apple_product_type.ui_test_bundle,
    doc = "Builds and bundles an iOS UI Test Bundle. Internal target not to be depended upon.",
)

# Alias to import it.
ios_internal_ui_test_bundle = _ios_internal_ui_test_bundle

ios_ui_test = rule_factory.create_apple_test_rule(
    implementation = _ios_ui_test_impl,
    doc = """iOS UI Test rule.

Builds and bundles an iOS UI `.xctest` test bundle. Runs the tests using the
provided test runner when invoked with `bazel test`. When using Tulsi to run
tests built with this target, `runner` will not be used since Xcode is the test
runner in that case.

To run the same test on multiple simulators/devices see
[ios_ui_test_suite](#ios_ui_test_suite).

The following is a list of the `ios_ui_test` specific attributes; for a list
of the attributes inherited by all test rules, please check the
[Bazel documentation](https://bazel.build/reference/be/common-definitions#common-attributes-tests).
""",
    platform_type = "ios",
)

# Declare it with an underscore so it shows up that way in queries.
_ios_internal_unit_test_bundle = rule_factory.create_apple_bundling_rule(
    implementation = _ios_unit_test_bundle_impl,
    platform_type = "ios",
    product_type = apple_product_type.unit_test_bundle,
    doc = "Builds and bundles an iOS Unit Test Bundle. Internal target not to be depended upon.",
)

# Alias to import it.
ios_internal_unit_test_bundle = _ios_internal_unit_test_bundle

ios_unit_test = rule_factory.create_apple_test_rule(
    implementation = _ios_unit_test_impl,
    doc = """Builds and bundles an iOS Unit `.xctest` test bundle. Runs the tests using the
provided test runner when invoked with `bazel test`. When using Tulsi to run
tests built with this target, `runner` will not be used since Xcode is the test
runner in that case.

`ios_unit_test` targets can work in two modes: as app or library
tests. If the `test_host` attribute is set to an `ios_application` target, the
tests will run within that application's context. If no `test_host` is provided,
the tests will run outside the context of an iOS application. Because of this,
certain functionalities might not be present (e.g. UI layout, NSUserDefaults).
You can find more information about app and library testing for Apple platforms
[here](https://developer.apple.com/library/content/documentation/DeveloperTools/Conceptual/testing_with_xcode/chapters/03-testing_basics.html).

To run the same test on multiple simulators/devices see
[ios_unit_test_suite](#ios_unit_test_suite).

The following is a list of the `ios_unit_test` specific attributes; for a list
of the attributes inherited by all test rules, please check the
[Bazel documentation](https://bazel.build/reference/be/common-definitions#common-attributes-tests).""",
    platform_type = "ios",
)
