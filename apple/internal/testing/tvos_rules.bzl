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

"""Implementation of tvOS test rules."""

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
    "TvosXcTestBundleInfo",
)

def _tvos_ui_test_bundle_impl(ctx):
    """Implementation of tvos_ui_test."""
    return apple_test_bundle_support.apple_test_bundle_impl(ctx) + [
        TvosXcTestBundleInfo(),
    ]

def _tvos_unit_test_bundle_impl(ctx):
    """Implementation of tvos_unit_test."""
    return apple_test_bundle_support.apple_test_bundle_impl(ctx) + [
        TvosXcTestBundleInfo(),
    ]

def _tvos_ui_test_impl(ctx):
    """Implementation of tvos_ui_test."""
    return apple_test_rule_support.apple_test_rule_impl(ctx, "xcuitest") + [
        TvosXcTestBundleInfo(),
    ]

def _tvos_unit_test_impl(ctx):
    """Implementation of tvos_unit_test."""
    return apple_test_rule_support.apple_test_rule_impl(ctx, "xctest") + [
        TvosXcTestBundleInfo(),
    ]

tvos_ui_test_bundle = rule_factory.create_apple_bundling_rule(
    implementation = _tvos_ui_test_bundle_impl,
    platform_type = str(apple_common.platform_type.tvos),
    product_type = apple_product_type.ui_test_bundle,
    doc = "Builds and bundles an tvOS UI Test Bundle.  Internal target not to be depended upon.",
)

tvos_ui_test = rule_factory.create_apple_test_rule(
    implementation = _tvos_ui_test_impl,
    doc = "tvOS UI Test rule.",
    platform_type = str(apple_common.platform_type.tvos),
)

tvos_unit_test_bundle = rule_factory.create_apple_bundling_rule(
    implementation = _tvos_unit_test_bundle_impl,
    platform_type = str(apple_common.platform_type.tvos),
    product_type = apple_product_type.unit_test_bundle,
    doc = "Builds and bundles an tvOS Unit Test Bundle. Internal target not to be depended upon.",
)

tvos_unit_test = rule_factory.create_apple_test_rule(
    implementation = _tvos_unit_test_impl,
    doc = "tvOS Unit Test rule.",
    platform_type = str(apple_common.platform_type.tvos),
)
