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

"""Implementation of tvOS test bundle rules."""

load(
    "@build_bazel_rules_apple//apple/internal/testing:apple_test_bundle_support.bzl",
    "apple_test_bundle_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/testing:apple_test_rules.bzl",
    "apple_unit_test",
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

# TODO(b/38350264): Remove these linkopts once bazel adds the
# @loader_path/Frameworks rpath by default.
_EXTRA_TEST_LINKOPTS = [
    "-rpath",
    "@loader_path/Frameworks",
]

def _tvos_test_bundle_impl(ctx):
    """Experimental implementation of tvos_application."""
    return apple_test_bundle_support.apple_test_bundle_impl(
        ctx,
        extra_providers = [TvosXcTestBundleInfo()],
    )

_tvos_unit_test_bundle = rule_factory.create_apple_bundling_rule(
    implementation = _tvos_test_bundle_impl,
    platform_type = "tvos",
    product_type = apple_product_type.unit_test_bundle,
    doc = "Builds and bundles a tvOS Unit Test Bundle.",
)

def tvos_unit_test(
        name,
        test_host = None,
        **kwargs):
    bundle_loader = None
    if test_host:
        bundle_loader = test_host
    apple_test_bundle_support.assemble_test_targets(
        name = name,
        bundle_loader = bundle_loader,
        platform_type = "tvos",
        platform_default_runner = "@build_bazel_rules_apple//apple/testing/default_runner:tvos_default_runner",
        bundling_rule = _tvos_unit_test_bundle,
        extra_linkopts = _EXTRA_TEST_LINKOPTS,
        test_host = test_host,
        test_rule = apple_unit_test,
        **kwargs
    )
