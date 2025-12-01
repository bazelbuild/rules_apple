# Copyright 2024 The Bazel Authors. All rights reserved.
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

"""Starlark test rule for files found in AppleBundleArchiveSupportInfo fields."""

load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@bazel_skylib//lib:unittest.bzl",
    "asserts",
)
load(
    "@build_bazel_rules_apple//apple/build_settings:build_settings.bzl",
    "build_settings_labels",
)
load(
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "AppleBundleArchiveSupportInfo",
)  # buildifier: disable=bzl-visibility
load(
    "@build_bazel_rules_apple//test/starlark_tests/rules:analysis_provider_test.bzl",
    "make_provider_test_rule",
)

visibility("//test/starlark_tests/...")

def _assert_outputs_in_set(*, actual_outputs, env, expected_outputs):
    """Assert the expected set of outputs is within actual_outputs."""

    actual_set = set(actual_outputs)
    expected_set = set(expected_outputs)

    asserts.equals(
        env,
        expected_set,
        actual_set & expected_set,
        "{expected_list} not contained in {actual_list}".format(
            actual_list = list(actual_set),
            expected_list = list(expected_set),
        ),
    )

def _assert_contains_expected_bundle_files_and_zips(
        ctx,
        env,
        apple_bundle_archive_support_info):
    """Assert AppleBundleArchiveSupportInfo contains expected bundle files and zips."""

    _assert_outputs_in_set(
        env = env,
        expected_outputs = ctx.attr.expected_archive_bundle_files,
        actual_outputs = [
            paths.join(parent_dir, file.basename)
            for parent_dir, files in apple_bundle_archive_support_info.bundle_files
            for file in files.to_list()
        ],
    )

    _assert_outputs_in_set(
        env = env,
        expected_outputs = ctx.attr.expected_archive_bundle_zips,
        actual_outputs = [
            paths.join(parent_dir, file.basename)
            for parent_dir, files in apple_bundle_archive_support_info.bundle_zips
            for file in files.to_list()
        ],
    )

apple_bundle_archive_support_info_device_test = make_provider_test_rule(
    provider = AppleBundleArchiveSupportInfo,
    assertion_fn = _assert_contains_expected_bundle_files_and_zips,
    attrs = {
        "expected_archive_bundle_files": attr.string_list(
            mandatory = False,
            doc = """
List of archive-relative bundle file paths expected as outputs of AppleBundleArchiveSupportInfo.
""",
        ),
        "expected_archive_bundle_zips": attr.string_list(
            mandatory = False,
            doc = """
List of archive-relative bundle zip paths expected as outputs of AppleBundleArchiveSupportInfo.
""",
        ),
    },
    config_settings = {
        build_settings_labels.use_tree_artifacts_outputs: True,
        build_settings_labels.require_pointer_authentication_attribute: True,
        "//command_line_option:macos_cpus": "arm64,x86_64",
        "//command_line_option:ios_multi_cpus": "arm64",
        "//command_line_option:tvos_cpus": "arm64",
        "//command_line_option:visionos_cpus": "arm64",
        "//command_line_option:watchos_cpus": "arm64_32",
    },
)
