# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""macos_bundle Starlark tests."""

load(
    ":rules/apple_verification_test.bzl",
    "apple_verification_test",
)
load(
    ":rules/common_verification_tests.bzl",
    "archive_contents_test",
)
load(
    ":rules/dsyms_test.bzl",
    "dsyms_test",
)

def macos_bundle_test_suite(name):
    """Test suite for macos_bundle.

    Args:
      name: the base name to be used in things created by this macro
    """
    apple_verification_test(
        name = "{}_codesign_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:bundle",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_additional_contents_test".format(name),
        build_type = "device",
        contains = [
            "$CONTENT_ROOT/Additional/additional.txt",
            "$CONTENT_ROOT/Nested/non_nested.txt",
            "$CONTENT_ROOT/Nested/nested/nested.txt",
        ],
        plist_test_file = "$CONTENT_ROOT/Info.plist",
        plist_test_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "bundle",
            "CFBundleIdentifier": "com.google.example",
            "CFBundleName": "bundle",
            "CFBundlePackageType": "BNDL",
            "CFBundleSupportedPlatforms:0": "MacOSX",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "macosx",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "macosx*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "LSMinimumSystemVersion": "10.10",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/macos:bundle",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_correct_rpath_header_value_test".format(name),
        build_type = "device",
        binary_test_file = "$CONTENT_ROOT/MacOS/bundle",
        macho_load_commands_contain = ["path @executable_path/../Frameworks (offset 12)"],
        target_under_test = "//test/starlark_tests/targets_under_test/macos:bundle",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_loader_macos_application_symbols_deduped_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:bundle_for_app",
        binary_test_file = "$CONTENT_ROOT/MacOS/bundle_for_app",
        compilation_mode = "opt",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_OBJC_CLASS_$_ObjectiveCSharedClass"],
        binary_not_contains_symbols = ["_OBJC_CLASS_$_ObjectiveCCommonClass"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_loader_macos_command_line_application_symbols_deduped_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:bundle_for_cmd_app",
        binary_test_file = "$CONTENT_ROOT/MacOS/bundle_for_cmd_app",
        compilation_mode = "opt",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_OBJC_CLASS_$_ObjectiveCSharedClass"],
        binary_not_contains_symbols = ["_OBJC_CLASS_$_ObjectiveCCommonClass"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_exported_symbols_list_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:bundle_dead_stripped",
        binary_test_file = "$CONTENT_ROOT/MacOS/bundle_dead_stripped",
        compilation_mode = "opt",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_anotherFunctionShared"],
        binary_not_contains_symbols = ["_dontCallMeShared", "_anticipatedDeadCode"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_custom_linkopts_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:bundle_special_linkopts",
        binary_test_file = "$CONTENT_ROOT/MacOS/bundle_special_linkopts",
        compilation_mode = "opt",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_linkopts_test_anotherFunctionShared"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_bundle_name_with_different_extension_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:bundle_with_different_extension",
        compilation_mode = "opt",
        contains = [
            "$ARCHIVE_ROOT/bundle_with_different_extension.prefPane",
        ],
        not_contains = [
            "$ARCHIVE_ROOT/bundle_with_different_extension.bundle",
        ],
        tags = [name],
    )

    dsyms_test(
        name = "{}_dsyms_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:bundle",
        expected_dsyms = ["bundle.bundle"],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
