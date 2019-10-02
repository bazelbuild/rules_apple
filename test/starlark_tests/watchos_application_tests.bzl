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

"""watchos_application Starlark tests."""

load(
    ":rules/apple_verification_test.bzl",
    "apple_verification_test",
)
load(
    ":rules/infoplist_contents_test.bzl",
    "infoplist_contents_test",
)

def watchos_application_test_suite():
    """Test suite for watchos_application."""
    name = "watchos_application"

    apple_verification_test(
        name = "{}_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app",
        expected_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "app",
            "CFBundleIdentifier": "com.google.example",
            "CFBundleName": "app",
            "CFBundleSupportedPlatforms:0": "WatchSimulator*",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "watchsimulator",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "watchsimulator*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "MinimumOSVersion": "4.0",
            "UIDeviceFamily:0": "4",
        },
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
