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

def _macos_ui_test_impl(ctx):
    """Implementation of macos_ui_test."""
    return apple_test_rule_support.apple_test_impl(
        ctx,
        "xcuitest",
        extra_providers = [MacosXcTestBundleInfo()],
    )

def _macos_unit_test_impl(ctx):
    """Implementation of macos_unit_test."""
    return apple_test_rule_support.apple_test_impl(
        ctx,
        "xctest",
        extra_providers = [MacosXcTestBundleInfo()],
    )

macos_ui_test = rule_factory.create_apple_bundling_rule(
    implementation = _macos_ui_test_impl,
    platform_type = str(apple_common.platform_type.macos),
    product_type = apple_product_type.ui_test_bundle,
    doc = "Builds and bundles a macOS UI Test Bundle.",
)

macos_unit_test = rule_factory.create_apple_bundling_rule(
    implementation = _macos_unit_test_impl,
    platform_type = str(apple_common.platform_type.macos),
    product_type = apple_product_type.unit_test_bundle,
    doc = "Builds and bundles a macOS Unit Test Bundle.",
)
