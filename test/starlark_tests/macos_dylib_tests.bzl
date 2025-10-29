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

"""macos_dylib Starlark tests."""

load(
    "//test/starlark_tests/rules:analysis_output_group_info_files_test.bzl",
    "analysis_output_group_info_dsymutil_bundle_files_test",
    "analysis_output_group_info_files_test",
)
load(
    "//test/starlark_tests/rules:apple_dsym_bundle_info_test.bzl",
    "apple_dsym_bundle_info_dsymutil_bundle_test",
    "apple_dsym_bundle_info_test",
)
load(
    "//test/starlark_tests/rules:apple_verification_test.bzl",
    "apple_verification_test",
)
load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "binary_contents_test",
)

visibility("private")

def macos_dylib_test_suite(name):
    """Test suite for macos_dylib.

    Args:
      name: the base name to be used in things created by this macro
    """
    apple_verification_test(
        name = "{}_codesign_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:dylib",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    binary_contents_test(
        name = "{}_binary_contents_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:dylib",
        binary_test_file = "$BINARY",
        compilation_mode = "opt",
        embedded_plist_test_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleIdentifier": "com.google.example",
            "CFBundleName": "dylib",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "macosx",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "macosx*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
        },
        tags = [name],
    )

    binary_contents_test(
        name = "{}_exported_symbols_list_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:dylib_dead_stripped",
        binary_test_file = "$BINARY",
        compilation_mode = "opt",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_anotherFunctionShared"],
        binary_not_contains_symbols = ["_dontCallMeShared"],
        tags = [name],
    )

    analysis_output_group_info_files_test(
        name = "{}_dsyms_output_group_files_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:dylib",
        output_group_name = "dsyms",
        expected_outputs = [
            "dylib.dSYM/Contents/Info.plist",
            "dylib.dSYM/Contents/Resources/DWARF/dylib_x86_64",
            "dylib.dSYM/Contents/Resources/DWARF/dylib_arm64",
        ],
        tags = [name],
    )
    analysis_output_group_info_dsymutil_bundle_files_test(
        name = "{}_dsyms_output_group_info_dsymutil_bundle_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:dylib",
        output_group_name = "dsyms",
        expected_outputs = [
            "dylib.dSYM",
        ],
        tags = [name],
    )
    apple_dsym_bundle_info_test(
        name = "{}_dsym_bundle_info_files_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:dylib",
        expected_direct_dsyms = ["dSYMs/dylib.dSYM"],
        expected_transitive_dsyms = ["dSYMs/dylib.dSYM"],
        tags = [name],
    )
    apple_dsym_bundle_info_dsymutil_bundle_test(
        name = "{}_dsym_bundle_info_dsymutil_bundle_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:dylib",
        expected_direct_dsyms = ["dylib.dSYM"],
        expected_transitive_dsyms = ["dylib.dSYM"],
        tags = [name],
    )

    binary_contents_test(
        name = "{}_capability_set_derived_bundle_id_plist_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:dylib_with_capability_set_derived_bundle_id",
        binary_test_file = "$BINARY",
        compilation_mode = "opt",
        embedded_plist_test_values = {
            "CFBundleIdentifier": "com.bazel.app.example.dylib-with-capability-set-derived-bundle-id",
        },
        tags = [name],
    )

    apple_verification_test(
        name = "{}_bundle_id_in_codesigning_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:dylib",
        verifier_script = "verifier_scripts/bundle_id_codesigning_verifier.sh",
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
