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
    ":rules/output_group_test.bzl",
    "output_group_test",
)

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

    dsyms_test(
        name = "{}_dsyms_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:dylib",
        expected_dsyms = ["dylib"],
        tags = [name],
    )

    output_group_test(
        name = "{}_output_group_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:dylib",
        expected_output_groups = ["dylib"],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
