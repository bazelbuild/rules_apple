# Copyright 2020 The Bazel Authors. All rights reserved.
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

"""macos_command_line_application Starlark tests."""

load(
    ":rules/apple_verification_test.bzl",
    "apple_verification_test",
)
load(
    ":rules/common_verification_tests.bzl",
    "binary_contents_test",
)
load(
    ":rules/dsyms_test.bzl",
    "dsyms_test",
)
load(
    ":rules/infoplist_contents_test.bzl",
    "infoplist_contents_test",
)

def macos_command_line_application_test_suite(name):
    """Test suite for macos_command_line_application.

    Args:
      name: the base name to be used in things created by this macro
    """
    apple_verification_test(
        name = "{}_codesign_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:cmd_app_basic",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_swift_codesign_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:cmd_app_basic_swift",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    binary_contents_test(
        name = "{}_merged_info_plist_binary_contents_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:cmd_app_info_plists",
        binary_test_file = "$BINARY",
        compilation_mode = "opt",
        embedded_plist_test_values = {
            "AnotherKey": "AnotherValue",
            "BuildMachineOSBuild": "*",
            "CFBundleIdentifier": "com.google.example",
            "CFBundleName": "cmd_app_info_plists",
            "CFBundleVersion": "1.0",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "macosx",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "macosx*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "LSMinimumSystemVersion": "10.11",
        },
        tags = [name],
    )

    binary_contents_test(
        name = "{}_merged_info_and_launchd_plists_info_plist_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:cmd_app_info_and_launchd_plists",
        binary_test_file = "$BINARY",
        compilation_mode = "opt",
        embedded_plist_test_values = {
            "AnotherKey": "AnotherValue",
            "BuildMachineOSBuild": "*",
            "CFBundleIdentifier": "com.google.example",
            "CFBundleName": "cmd_app_info_and_launchd_plists",
            "CFBundleVersion": "1.0",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "macosx",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "macosx*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "LSMinimumSystemVersion": "10.11",
        },
        tags = [name],
    )

    binary_contents_test(
        name = "{}_merged_info_and_launchd_plists_launchd_plist_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:cmd_app_info_and_launchd_plists",
        binary_test_file = "$BINARY",
        compilation_mode = "opt",
        embedded_plist_test_values = {
            "AnotherKey": "AnotherValue",
            "Label": "com.test.bundle",
        },
        plist_section_name = "__launchd_plist",
        tags = [name],
    )

    binary_contents_test(
        name = "{}_custom_linkopts_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:cmd_app_special_linkopts",
        binary_test_file = "$BINARY",
        compilation_mode = "opt",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_linkopts_test_main"],
        tags = [name],
    )

    binary_contents_test(
        name = "{}_exported_symbols_list_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:cmd_app_dead_stripped",
        binary_test_file = "$BINARY",
        compilation_mode = "opt",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_anotherFunctionMain"],
        binary_not_contains_symbols = ["_dontCallMeMain"],
        tags = [name],
    )

    dsyms_test(
        name = "{}_dsyms_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:cmd_app_basic",
        expected_dsyms = ["cmd_app_basic"],
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_infoplist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:cmd_app_info_plists",
        expected_values = {
            "AnotherKey": "AnotherValue",
            "BuildMachineOSBuild": "*",
            "CFBundleIdentifier": "com.google.example",
            "CFBundleName": "cmd_app_info_plists",
            "CFBundleShortVersionString": "1.0",
            "CFBundleSupportedPlatforms:0": "MacOSX",
            "CFBundleVersion": "1.0",
            "DTPlatformVersion": "*",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "DTPlatformName": "macosx",
            "DTSDKBuild": "*",
            "DTSDKName": "macosx*",
            "LSMinimumSystemVersion": "10.11",
        },
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
