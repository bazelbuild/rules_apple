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

"""Tests for client-derived framework exported-symbol lists."""

load(
    "//test/starlark_tests/rules:action_inputs_test.bzl",
    "action_inputs_test",
)
load(
    "//test/starlark_tests/rules:analysis_target_outputs_test.bzl",
    "analysis_target_outputs_test",
)
load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "archive_contents_test",
)

def exported_symbols_list_test_suite(name):
    """Test suite for apple_exported_symbols_list.

    Args:
      name: The base name to use for tests created by this macro.
    """
    target = "//test/starlark_tests/targets_under_test/ios:client_export_framework_exports"

    analysis_target_outputs_test(
        name = "{}_output_test".format(name),
        target_under_test = target,
        expected_outputs = ["client_export_framework_exports.exported_symbols"],
        tags = [name],
    )

    action_inputs_test(
        name = "{}_graph_inputs_test".format(name),
        target_under_test = target,
        expected_inputs = [
            "client_export_client_lib",
            "client_export_framework_lib",
            "client_export_runtime_lib",
        ],
        mnemonic = "AppleExportedSymbolsList",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_unrestricted_control_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:client_export_framework_unrestricted",
        binary_contains_symbols = [
            "_$s21ClientExportFramework06unusedcB0SiyF",
            "_$s21ClientExportFramework08retainedcB0SiyF",
        ],
        binary_test_architecture = "x86_64",
        binary_test_file = "$BUNDLE_ROOT/client_export_framework_unrestricted",
        build_type = "simulator",
        compilation_mode = "opt",
        tags = [name],
    )

    # This final-product test verifies the framework link, not just the
    # intermediate list: the used Swift API is exported and the unused public
    # Swift API is hidden from the Mach-O symbol/export metadata.
    archive_contents_test(
        name = "{}_framework_exports_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:client_export_framework",
        binary_contains_symbols = [
            "_$s21ClientExportFramework08retainedcB0SiyF",
            "_runtimeDiscoveredEntry",
        ],
        binary_not_contains_symbols = [
            "_$s21ClientExportFramework06unusedcB0SiyF",
        ],
        binary_test_architecture = "x86_64",
        binary_test_file = "$BUNDLE_ROOT/client_export_framework",
        build_type = "simulator",
        compilation_mode = "opt",
        tags = [name],
    )

    # The generated list must be derived independently for each architecture.
    # Otherwise one slice can receive a symbol that only exists in another
    # slice, which makes Apple's linker reject the fat framework build.
    for architecture, expected_symbol, other_symbol in [
        ("arm64", "_arm64RuntimeDiscoveredEntry", "_x8664RuntimeDiscoveredEntry"),
        ("x86_64", "_x8664RuntimeDiscoveredEntry", "_arm64RuntimeDiscoveredEntry"),
    ]:
        archive_contents_test(
            name = "{}_multi_arch_{}_framework_exports_test".format(name, architecture),
            target_under_test = "//test/starlark_tests/targets_under_test/ios:client_export_framework",
            binary_contains_symbols = [
                expected_symbol,
                "_runtimeDiscoveredEntry",
            ],
            binary_not_contains_symbols = [other_symbol],
            binary_test_architecture = architecture,
            binary_test_file = "$BUNDLE_ROOT/client_export_framework",
            build_type = "simulator",
            compilation_mode = "opt",
            cpus = {
                "ios_multi_cpus": ["sim_arm64", "x86_64"],
            },
            tags = [name],
        )

    native.test_suite(
        name = name,
        tags = [name],
    )
