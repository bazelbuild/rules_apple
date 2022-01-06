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

"""watchos_unit_test Starlark tests."""

load(
    ":rules/apple_verification_test.bzl",
    "apple_verification_test",
)
load(
    ":rules/dsyms_test.bzl",
    "dsyms_test",
)
load(
    ":rules/infoplist_contents_test.bzl",
    "infoplist_contents_test",
)

def watchos_unit_test_test_suite(name):
    """Test suite for watchos_unit_test.

    Args:
      name: the base name to be used in things created by this macro
    """
    apple_verification_test(
        name = "{}_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:unit_test",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name, "manual", "notap"],  # TODO(b/179148169) Remove "notap" when Xcode 12.5 becomes the default.
    )

    dsyms_test(
        name = "{}_dsyms_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:unit_test",
        expected_dsyms = ["unit_test.xctest"],
        tags = [name, "manual", "notap"],  # TODO(b/179148169) Remove "notap" when Xcode 12.5 becomes the default.
    )

    infoplist_contents_test(
        name = "{}_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:unit_test",
        expected_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "unit_test",
            "CFBundleIdentifier": "com.bazelbuild.rulesapple.Tests",
            "CFBundleName": "unit_test",
            "CFBundlePackageType": "BNDL",
            "CFBundleSupportedPlatforms:0": "Watch*",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "watchsimulator",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "watchsimulator*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "MinimumOSVersion": "7.4",
            "UIDeviceFamily:0": "4",
        },
        tags = [name, "manual", "notap"],  # TODO(b/179148169) Remove "notap" when Xcode 12.5 becomes the default.
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
