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

"""watchos_extension Starlark tests."""

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
load(
    ":rules/infoplist_contents_test.bzl",
    "infoplist_contents_test",
)

def watchos_extension_test_suite():
    """Test suite for watchos_extension."""
    name = "watchos_extension"

    apple_verification_test(
        name = "{}_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_entitlements_simulator_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext",
        verifier_script = "verifier_scripts/entitlements_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_entitlements_device_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext",
        verifier_script = "verifier_scripts/entitlements_verifier.sh",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_resources_simulator_test".format(name),
        build_type = "simulator",
        contains = [
            "$RESOURCE_ROOT/resource_bundle.bundle/Info.plist",
            "$RESOURCE_ROOT/Another.plist",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_strings_simulator_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext",
        contains = [
            "$RESOURCE_ROOT/localization.bundle/en.lproj/files.stringsdict",
            "$RESOURCE_ROOT/localization.bundle/en.lproj/greetings.strings",
        ],
        tags = [name],
    )

    dsyms_test(
        name = "{}_dsyms_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/tvos:ext",
        expected_dsyms = ["ext.appex"],
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext",
        expected_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "ext",
            "CFBundleIdentifier": "com.google.example.ext",
            "CFBundleName": "ext",
            "CFBundleSupportedPlatforms:0": "WatchSimulator*",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "watchsimulator*",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "watchsimulator*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "MinimumOSVersion": "4.0",
            "NSExtension:NSExtensionAttributes:WKAppBundleIdentifier": "com.google.example",
            "NSExtension:NSExtensionPointIdentifier": "com.apple.watchkit",
            "UIDeviceFamily:0": "4",
        },
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_multiple_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext_multiple_infoplists",
        expected_values = {
            "AnotherKey": "AnotherValue",
            "CFBundleExecutable": "ext_multiple_infoplists",
        },
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
