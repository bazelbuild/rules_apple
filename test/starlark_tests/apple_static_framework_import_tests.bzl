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
    "//test/starlark_tests/rules:action_inputs_test.bzl",
    "make_action_inputs_test_rule",
)

_action_inputs_with_ios_x86_64_platform_test = make_action_inputs_test_rule({
    "//command_line_option:platforms": str(Label("@build_bazel_apple_support//platforms:ios_x86_64")),
})

def apple_static_framework_import_test_suite(name):
    """Test suite for apple_static_framework_import.

    Args:
      name: the base name to be used in things created by this macro
    """

    # Make sure the SwiftCompileModuleInterface action codepath is used
    _action_inputs_with_ios_x86_64_platform_test(
        name = "{}_compiles_module_from_swiftinterface".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:iOSImportedSwiftStaticFramework",
        mnemonic = "SwiftCompileModuleInterface",
        expected_inputs = [
            "iOSSwiftStaticFramework.framework/Modules/iOSSwiftStaticFramework.swiftmodule/x86_64-apple-ios-simulator.swiftinterface",
        ],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
