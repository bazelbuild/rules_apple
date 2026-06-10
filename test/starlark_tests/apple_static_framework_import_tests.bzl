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

"""apple_static_framework_import Starlark tests."""

load(
    "//test/starlark_tests/rules:action_command_line_test.bzl",
    "make_action_command_line_test_rule",
)
load(
    "//test/starlark_tests/rules:action_inputs_test.bzl",
    "make_action_inputs_test_rule",
)
load(
    "//test/starlark_tests/rules:analysis_target_actions_test.bzl",
    "make_analysis_target_actions_test",
)

_action_inputs_with_ios_x86_64_import_via_swiftinterface_platform_test = make_action_inputs_test_rule({
    "//command_line_option:features": [
        "apple._import_framework_via_swiftinterface",
    ],
    "//command_line_option:platforms": str(Label("@apple_support//platforms:ios_x86_64")),
})

_action_command_line_with_ios_sim_arm64_platform_test = make_action_command_line_test_rule({
    "//command_line_option:platforms": str(Label("@apple_support//platforms:ios_sim_arm64")),
})

_action_inputs_with_ios_sim_arm64_platform_test = make_action_inputs_test_rule({
    "//command_line_option:platforms": str(Label("@apple_support//platforms:ios_sim_arm64")),
})

_analysis_actions_with_ios_x86_64_platform_test = make_analysis_target_actions_test({
    "//command_line_option:platforms": str(Label("@apple_support//platforms:ios_x86_64")),
})

def apple_static_framework_import_test_suite(name):
    """Test suite for apple_static_framework_import.

    Args:
      name: the base name to be used in things created by this macro
    """

    _analysis_actions_with_ios_x86_64_platform_test(
        name = "{}_does_not_compile_module_from_swiftinterface_implicit_modules".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:iOSImportedSwiftStaticFramework",
        target_mnemonic = "CppModuleMap",
        not_expected_mnemonic = ["SwiftCompileModuleInterface"],
        tags = [name],
    )

    _action_inputs_with_ios_x86_64_import_via_swiftinterface_platform_test(
        name = "{}_compiles_module_from_swiftinterface".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:iOSImportedSwiftStaticFramework",
        mnemonic = "SwiftCompileModuleInterface",
        expected_inputs = [
            "iOSSwiftStaticFramework.framework/Modules/iOSSwiftStaticFramework.swiftmodule/x86_64-apple-ios-simulator.swiftinterface",
            "iOSSwiftStaticFramework.framework/Modules/iOSSwiftStaticFramework.swiftmodule/x86_64-apple-ios-simulator.private.swiftinterface",
        ],
        tags = [name],
    )

    _action_command_line_with_ios_sim_arm64_platform_test(
        name = "{}_binary_links_imported_swiftmodule_ast_path".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_static_framework_binary_swiftmodule",
        mnemonic = "ObjcLink",
        expected_argv = [
            "-Wl,-add_ast_path",
            "Swift3PFmwkBinarySwiftmodule.framework/Modules/Swift3PFmwkBinarySwiftmodule.swiftmodule/arm64.swiftmodule",
        ],
        tags = [name],
    )

    _action_inputs_with_ios_sim_arm64_platform_test(
        name = "{}_binary_links_imported_swiftmodule_ast_input".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_static_framework_binary_swiftmodule",
        mnemonic = "ObjcLink",
        expected_inputs = [
            "Swift3PFmwkBinarySwiftmodule.framework/Modules/Swift3PFmwkBinarySwiftmodule.swiftmodule/arm64.swiftmodule",
        ],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
