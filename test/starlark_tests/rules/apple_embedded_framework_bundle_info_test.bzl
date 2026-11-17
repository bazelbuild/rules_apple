# Copyright 2026 The Bazel Authors. All rights reserved.
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

"""Starlark test rules for AppleEmbeddedFrameworkBundleInfo."""

load(
    "@bazel_skylib//lib:unittest.bzl",
    "asserts",
)
load(
    "@build_bazel_rules_apple//apple/internal/providers:embedded_framework_bundle_info.bzl",
    "AppleEmbeddedFrameworkBundleInfo",
)
load(
    "@build_bazel_rules_apple//test/starlark_tests/rules:analysis_provider_test.bzl",
    "make_provider_test_rule",
)

visibility("//test/starlark_tests/...")

def _assert_expected_signed_frameworks(
        ctx,
        env,
        apple_embedded_framework_bundle_info):
    """Assert AppleEmbeddedFrameworkBundleInfo contains expected signed_frameworks."""
    actual_signed_frameworks = sorted(
        apple_embedded_framework_bundle_info.signed_frameworks.to_list(),
    )
    expected_signed_frameworks = sorted(ctx.attr.expected_signed_frameworks)

    asserts.equals(
        env,
        expected_signed_frameworks,
        actual_signed_frameworks,
        "Expected signed_frameworks {expected}, but got {actual}".format(
            actual = actual_signed_frameworks,
            expected = expected_signed_frameworks,
        ),
    )

_SHARED_ATTRS = {
    "expected_signed_frameworks": attr.string_list(
        mandatory = False,
        doc = """
List of framework bundle names expected in AppleEmbeddedFrameworkBundleInfo.signed_frameworks.
""",
    ),
}

def make_apple_embedded_framework_bundle_info_test(config_settings = {}):
    """Returns a new `apple_embedded_framework_bundle_info_test`-like rule with custom configs.

    Args:
        config_settings: A dictionary of configuration settings and their values
            that should be applied during tests.

    Returns:
        A rule returned by `make_provider_test_rule` that inspects
        `AppleEmbeddedFrameworkBundleInfo`.
    """
    return make_provider_test_rule(
        provider = AppleEmbeddedFrameworkBundleInfo,
        assertion_fn = _assert_expected_signed_frameworks,
        attrs = _SHARED_ATTRS,
        config_settings = config_settings,
    )

apple_embedded_framework_bundle_info_test = make_apple_embedded_framework_bundle_info_test(
    config_settings = {
        "//command_line_option:macos_cpus": "arm64,x86_64",
        "//command_line_option:ios_multi_cpus": "sim_arm64,x86_64",
        "//command_line_option:tvos_cpus": "sim_arm64,x86_64",
        "//command_line_option:visionos_cpus": "sim_arm64",
        "//command_line_option:watchos_cpus": "sim_arm64,x86_64",
    },
)
