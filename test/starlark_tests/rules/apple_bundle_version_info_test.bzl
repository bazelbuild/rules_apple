# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""Starlark test rules for bundle version info providers."""

load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleVersionInfo",
)
load(
    "@build_bazel_rules_apple//test/starlark_tests/rules:analysis_provider_test.bzl",
    "make_provider_test_rule",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@bazel_skylib//lib:unittest.bzl",
    "analysistest",
)

visibility("//test/starlark_tests/...")

def _assert_contains_version_info(
        ctx,
        env,
        apple_bundle_version_info):
    """Assert AppleBundleVersionInfo contains the correct strings and the expected filename."""

    if ctx.attr.expected_build_version != apple_bundle_version_info.build_version:
        fail("Found mismatched build_version string; expected '{}' but found '{}'".format(
            ctx.attr.expected_build_version,
            apple_bundle_version_info.build_version,
        ))

    if ctx.attr.expected_short_version_string != apple_bundle_version_info.short_version_string:
        fail("Found mismatched short_version_string string; expected '{}' but found '{}'".format(
            ctx.attr.expected_short_version_string,
            apple_bundle_version_info.short_version_string,
        ))

    target_under_test = analysistest.target_under_test(env)
    version_file_path = paths.relativize(
        apple_bundle_version_info.version_file.short_path,
        target_under_test.label.package,
    )

    if ctx.attr.expected_version_file != version_file_path:
        fail("Found mismatched version_file file name; expected '{}' but found '{}'".format(
            ctx.attr.expected_version_file,
            version_file_path,
        ))

apple_bundle_version_info_test = make_provider_test_rule(
    provider = AppleBundleVersionInfo,
    assertion_fn = _assert_contains_version_info,
    attrs = {
        "expected_build_version": attr.string(
            mandatory = True,
            doc = """
A string expected to match the value of build_version found in the AppleBundleVersionInfo provider.
""",
        ),
        "expected_short_version_string": attr.string(
            mandatory = True,
            doc = """
A string expected to match the value of short_version_string found in the AppleBundleVersionInfo
provider.
""",
        ),
        "expected_version_file": attr.string(
            mandatory = True,
            doc = """
A string representing the file name of the JSON file expected to propagate version information from
the AppleBundleVersionInfo provider.
""",
        ),
    },
)
