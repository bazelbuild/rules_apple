# Copyright 2026 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Tests for the Apple resource symbol generation rules."""

load(
    "//test/starlark_tests/rules:analysis_target_actions_test.bzl",
    "make_analysis_target_actions_test",
)
load(
    "//test/starlark_tests/rules:analysis_target_outputs_test.bzl",
    "make_analysis_target_outputs_test",
)

visibility("private")

_config_settings = {
    "//command_line_option:platforms": [
        str(Label("@apple_support//platforms:darwin_arm64")),
    ],
}

_target_actions_test = make_analysis_target_actions_test(
    config_settings = _config_settings,
)
_target_outputs_test = make_analysis_target_outputs_test(
    config_settings = _config_settings,
)

def apple_resource_symbols_test_suite(name):
    """Test suite for Apple resource symbol generation rules."""
    _target_outputs_test(
        name = "{}_asset_output".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:asset_catalog_symbols",
        expected_outputs = ["asset_catalog_symbols/GeneratedAssetSymbols.swift"],
        tags = [name],
    )
    _target_actions_test(
        name = "{}_asset_action".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:asset_catalog_symbols",
        target_mnemonic = "GenerateAssetSymbols",
        expected_argv = [
            "actool --compile",
            "--generate-swift-asset-symbols",
            "asset_catalog_symbols/GeneratedAssetSymbols.swift",
            "--bundle-identifier com.example.ResourceSymbols",
            "--platform macosx",
            "test/starlark_tests/resources/assets.xcassets",
        ],
        tags = [name],
    )
    _target_outputs_test(
        name = "{}_string_output".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:string_catalog_symbols",
        expected_outputs = ["string_catalog_symbols/GeneratedStringSymbols_greetings.swift"],
        tags = [name],
    )
    _target_actions_test(
        name = "{}_string_action".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:string_catalog_symbols",
        target_mnemonic = "GenerateXCStringsSymbols",
        expected_argv = [
            "xcstringstool generate-symbols",
            "test/starlark_tests/resources/greetings.xcstrings",
            "--output-directory",
            "string_catalog_symbols",
            "--language swift",
        ],
        tags = [name],
    )
    _target_actions_test(
        name = "{}_string_compile_action".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:string_catalog_symbols",
        target_mnemonic = "CompileXCStrings",
        expected_argv = [
            "xcstringstool compile --output-directory",
            "string_catalog_symbols.stringcatalog-resources",
            "test/starlark_tests/resources/greetings.xcstrings",
        ],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
