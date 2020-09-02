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

"""macos_kernel_extension Starlark tests."""

load(
    ":rules/apple_verification_test.bzl",
    "apple_verification_test",
)
load(
    ":rules/common_verification_tests.bzl",
    "archive_contents_test",
)

# buildifier: disable=unnamed-macro
def macos_kernel_extension_test_suite():
    """Test suite for macos_kernel_extension."""
    name = "macos_kernel_extension"

    apple_verification_test(
        name = "{}_codesign_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:kext",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_plist_test".format(name),
        build_type = "device",
        plist_test_file = "$CONTENT_ROOT/Info.plist",
        plist_test_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "kext",
            "CFBundleIdentifier": "com.google.kext",
            "CFBundleName": "kext",
            "CFBundlePackageType": "KEXT",
            "CFBundleSupportedPlatforms:0": "MacOSX",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "macosx",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "macosx*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "LSMinimumSystemVersion": "10.13",
            "IOKitPersonalities": "*",
            "OSBundleLibraries": "*",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/macos:kext",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_exported_symbols_list_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:kext_dead_stripped",
        binary_test_file = "$CONTENT_ROOT/MacOS/kext_dead_stripped",
        compilation_mode = "opt",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_anotherFunctionShared"],
        binary_not_contains_symbols = ["_dontCallMeShared"],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
