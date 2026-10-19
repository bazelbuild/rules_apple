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

"""macos_dmg Starlark tests."""

load(
    "//test/starlark_tests/rules:action_command_line_test.bzl",
    "action_command_line_test",
)
load(
    "//test/starlark_tests/rules:analysis_failure_message_test.bzl",
    "analysis_failure_message_test",
)
load(
    "//test/starlark_tests/rules:analysis_target_outputs_test.bzl",
    "analysis_target_outputs_test",
    "analysis_target_tree_artifacts_outputs_test",
)

def dmg_test_suite(name):
    """Test suite for the macos_dmg rule.

    Args:
      name: the base name to be used in things created by this macro
    """
    analysis_target_outputs_test(
        name = "{}_output_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_dmg",
        expected_outputs = ["app_dmg.dmg"],
        tags = [name],
    )

    analysis_target_tree_artifacts_outputs_test(
        name = "{}_tree_artifact_output_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_dmg",
        expected_outputs = ["app_dmg.dmg"],
        tags = [name],
    )

    action_command_line_test(
        name = "{}_default_arguments_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_dmg",
        mnemonic = "MacosDmg",
        expected_argv = [
            "-name",
            "app_min_os_baseline",
            "-mode",
            "udzo",
            "-time",
            "946684800",
            "-partition=true",
        ],
        not_expected_argv = [
            "-background",
        ],
        tags = [name],
    )

    action_command_line_test(
        name = "{}_custom_arguments_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_dmg_custom",
        mnemonic = "MacosDmg",
        expected_argv = [
            "-name",
            "Minimal App",
            "-mode",
            "udro",
            "-time",
            "1234567890",
            "-partition=false",
            "-background",
        ],
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_rejects_non_app_bundle_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:bundle_dmg",
        expected_error = "macos_dmg can only package a macOS `.app` bundle",
        tags = [name],
    )

    action_command_line_test(
        name = "{}_zip_archive_arguments_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:zip_archive_dmg",
        mnemonic = "MacosDmg",
        expected_argv = [
            "-name",
            "app_min_os_baseline",
        ],
        tags = [name],
    )

    action_command_line_test(
        name = "{}_tar_gz_archive_arguments_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:tar_gz_archive_dmg",
        mnemonic = "MacosDmg",
        expected_argv = [
            "-name",
            "app_min_os_baseline-1.0-arm64",
        ],
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_rejects_app_and_archive_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_and_archive_dmg",
        expected_error = "macos_dmg needs exactly one of `app` or `archive`.",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_rejects_no_input_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:no_input_dmg",
        expected_error = "macos_dmg needs exactly one of `app` or `archive`.",
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
