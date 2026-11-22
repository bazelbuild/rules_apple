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

"""Starlark test rules for the test bundle and test host passed to test runners."""

load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@bazel_skylib//lib:unittest.bzl",
    "analysistest",
    "asserts",
)
load(
    "//apple:providers.bzl",
    "AppleTestInfo",
)
load(
    "//test/starlark_tests/rules:analysis_provider_test.bzl",
    "make_provider_test_rule",
)

visibility("//test/starlark_tests/...")

def _assert_artifact(*, env, artifact, expected_path, expected_is_directory, description):
    """Asserts the package-relative path of an artifact and whether it's a tree artifact."""
    target_under_test = analysistest.target_under_test(env)
    asserts.equals(
        env,
        expected_path,
        paths.relativize(artifact.short_path, target_under_test.label.package),
        "Unexpected {} path".format(description),
    )
    asserts.equals(
        env,
        expected_is_directory,
        artifact.is_directory,
        "Expected the {} to {}be a tree artifact".format(
            description,
            "" if expected_is_directory else "not ",
        ),
    )

def _assert_apple_test_info(ctx, env, apple_test_info):
    """Asserts the test bundle and test host in AppleTestInfo."""
    _assert_artifact(
        env = env,
        artifact = apple_test_info.test_bundle,
        expected_path = ctx.attr.expected_test_bundle,
        expected_is_directory = ctx.attr.expected_test_bundle_is_directory,
        description = "test bundle",
    )
    _assert_artifact(
        env = env,
        artifact = apple_test_info.test_host,
        expected_path = ctx.attr.expected_test_host,
        expected_is_directory = ctx.attr.expected_test_host_is_directory,
        description = "test host",
    )

def make_apple_test_info_test(config_settings = {}):
    """Returns a new `apple_test_info_test`-like rule with custom configs.

    Args:
        config_settings: A dictionary of configuration settings and their values
            that should be applied during tests.

    Returns:
        A rule returned by `analysistest.make` that has the `apple_test_info_test`
        interface and the given config settings.
    """
    return make_provider_test_rule(
        provider = AppleTestInfo,
        assertion_fn = _assert_apple_test_info,
        attrs = {
            "expected_test_bundle": attr.string(
                mandatory = True,
                doc = "Package-relative path of the test bundle passed to the test runner.",
            ),
            "expected_test_bundle_is_directory": attr.bool(
                mandatory = True,
                doc = "Whether the test bundle is expected to be a tree artifact.",
            ),
            "expected_test_host": attr.string(
                mandatory = True,
                doc = "Package-relative path of the test host passed to the test runner.",
            ),
            "expected_test_host_is_directory": attr.bool(
                mandatory = True,
                doc = "Whether the test host is expected to be a tree artifact.",
            ),
        },
        config_settings = config_settings,
    )

# Default apple_test_info_test.
apple_test_info_test = make_apple_test_info_test()
