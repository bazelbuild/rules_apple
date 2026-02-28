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

"""apple_mergeable_strings Starlark tests."""

load(
    "//test/starlark_tests/rules:analysis_target_actions_test.bzl",
    "analysis_target_actions_test",
)
load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "archive_contents_test",
)

visibility("private")

def apple_mergeable_strings_test_suite(name):
    """Test suite for apple_mergeable_strings.

    Args:
      name: the base name to be used in things created by this macro
    """

    # Tests that mergeable strings are merged into a single strings file.
    archive_contents_test(
        name = "{}_ios_merged_strings_test".format(name),
        build_type = "device",
        contains = [
            "$BUNDLE_ROOT/en.lproj/m1.strings",
            "$BUNDLE_ROOT/fr.lproj/m1.strings",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_mergeable_strings",
        tags = [name],
    )

    # Tests that mergeable strings are merged into a single strings file for macOS with the slightly
    # different bundle structure.
    archive_contents_test(
        name = "{}_macos_merged_strings_test".format(name),
        build_type = "device",
        contains = [
            "$BUNDLE_ROOT/Contents/Resources/en.lproj/m1.strings",
            "$BUNDLE_ROOT/Contents/Resources/fr.lproj/m1.strings",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_mergeable_strings",
        tags = [name],
    )

    # Tests that the MergeStrings action is registered.
    analysis_target_actions_test(
        name = "{}_merge_strings_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_mergeable_strings",
        target_mnemonic = "MergeStrings",
        expected_argv = [
            "mergeable_strings_control.json",
        ],
        tags = [name],
    )

    # Tests that the VerifyingMergeableStrings action is registered.
    analysis_target_actions_test(
        name = "{}_verifying_mergeable_strings_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_mergeable_strings",
        target_mnemonic = "VerifyMergeStrings",
        tags = [name],
    )

    # Tests that the actions are also registered for the mismatched case (failure test).
    analysis_target_actions_test(
        name = "{}_mismatched_merge_strings_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_mismatched_mergeable_strings",
        target_mnemonic = "MergeStrings",
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
