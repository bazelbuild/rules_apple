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
    ":rules/common_verification_tests.bzl",
    "archive_contents_test",
)
load(
    ":rules/analysis_xcasset_argv_test.bzl",
    "analysis_xcasset_argv_test",
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

    # Test the expected values in a watchOS app's Info.plist when compiling for simulators.
    archive_contents_test(
        name = "{}_app_plist_simulator_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app",
        build_type = "simulator",
        plist_test_file = "$BUNDLE_ROOT/Info.plist",
        plist_test_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "app",
            "CFBundleIdentifier": "com.google.example.watch",
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

    # Test the expected values in a watchOS app's Info.plist when compiling for devices.
    archive_contents_test(
        name = "{}_app_plist_device_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app",
        build_type = "device",
        plist_test_file = "$BUNDLE_ROOT/Info.plist",
        plist_test_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "app",
            "CFBundleIdentifier": "com.google.example.watch",
            "CFBundleName": "app",
            "CFBundleSupportedPlatforms:0": "WatchOS*",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "watchos",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "watchos*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "MinimumOSVersion": "3.0",
            "UIDeviceFamily:0": "4",
        },
        tags = [name],
    )

    # Test the expected values in a watchOS extension's Info.plist when compiling for devices.
    archive_contents_test(
        name = "{}_extension_plist_device_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app",
        build_type = "device",
        plist_test_file = "$BUNDLE_ROOT/PlugIns/ext.appex/Info.plist",
        plist_test_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "ext",
            # "CFBundleIdentifier": "com.google.example.ext",
            "CFBundleName": "ext",
            "CFBundleSupportedPlatforms:0": "WatchOS*",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "watchos",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "watchos*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "MinimumOSVersion": "3.0",
            "UIDeviceFamily:0": "4",
        },
        tags = [name],
    )

    # Test the expected values in a watchOS extension's Info.plist when compiling for simulators.
    archive_contents_test(
        name = "{}_extension_plist_simulator_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app",
        build_type = "simulator",
        plist_test_file = "$BUNDLE_ROOT/PlugIns/ext.appex/Info.plist",
        plist_test_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "ext",
            # "CFBundleIdentifier": "com.google.example.ext",
            "CFBundleName": "ext",
            "CFBundleSupportedPlatforms:0": "WatchSimulator*",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "watchsimulator",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "watchsimulator*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "MinimumOSVersion": "3.0",
            "UIDeviceFamily:0": "4",
        },
        tags = [name],
    )

    # Tests that the provisioning profile is present when built for device.
    archive_contents_test(
        name = "{}_contains_provisioning_profile_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        contains = [
            "$BUNDLE_ROOT/embedded.mobileprovision",
            "$BUNDLE_ROOT/PlugIns/ext.appex/embedded.mobileprovision",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app",
        tags = [name],
    )

    # Tests that the watch application and IPA contain the WatchKit stub executable
    # in the appropriate bundle and top-level support directories.
    archive_contents_test(
        name = "{}_contains_stub_executable_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        contains = [
            "$BUNDLE_ROOT/Watch/app.app/_WatchKitStub/WK",
            "$ARCHIVE_ROOT/WatchKitSupport2/WK",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app",
        tags = [name],
    )

    # Tests xcasset tool is passed the correct arguments.
    analysis_xcasset_argv_test(
        name = "{}_xcasset_actool_argv".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app",
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
