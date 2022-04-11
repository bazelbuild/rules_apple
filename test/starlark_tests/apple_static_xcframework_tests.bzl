# Copyright 2021 The Bazel Authors. All rights reserved.
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

"""xcframework Starlark tests."""

load(
    ":rules/common_verification_tests.bzl",
    "archive_contents_test",
)

def apple_static_xcframework_test_suite(name):
    """Test suite for apple_static_xcframework.

    Args:
      name: the base name to be used in things created by this macro
    """
    archive_contents_test(
        name = "{}_ios_root_plist_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcframework",
        plist_test_file = "$BUNDLE_ROOT/Info.plist",
        plist_test_values = {
            "AvailableLibraries:0:HeadersPath": "Headers",
            "AvailableLibraries:0:LibraryIdentifier": "ios-arm64",
            "AvailableLibraries:0:LibraryPath": "ios_static_xcframework_ios_device.a",
            "AvailableLibraries:0:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:0:SupportedPlatform": "ios",
            "AvailableLibraries:1:HeadersPath": "Headers",
            "AvailableLibraries:1:LibraryIdentifier": "ios-arm64_x86_64-simulator",
            "AvailableLibraries:1:LibraryPath": "ios_static_xcframework_ios_simulator.a",
            "AvailableLibraries:1:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:1:SupportedArchitectures:1": "x86_64",
            "AvailableLibraries:1:SupportedPlatform": "ios",
            "CFBundlePackageType": "XFWK",
            "XCFrameworkFormatVersion": "1.0",
        },
        tags = [name],
    )

    archive_contents_test(
        name = "{}_ios_arm64_archive_contents_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcframework",
        contains = [
            "$BUNDLE_ROOT/ios-arm64/Headers/shared.h",
            "$BUNDLE_ROOT/ios-arm64/Headers/ios_static_xcframework.h",
            "$BUNDLE_ROOT/ios-arm64/Headers/module.modulemap",
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcframework_ios_device.a",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/Headers/shared.h",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/Headers/ios_static_xcframework.h",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/Headers/module.modulemap",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcframework_ios_simulator.a",
            "$BUNDLE_ROOT/Info.plist",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_ios_avoid_deps_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcfmwk_with_avoid_deps",
        contains = [
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcfmwk_with_avoid_deps_ios_device.a",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_avoid_deps_ios_simulator.a",
            "$BUNDLE_ROOT/Info.plist",
        ],
        not_contains = [
            "$BUNDLE_ROOT/ios-arm64/Headers/DummyFmwk.h",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/Headers/DummyFmwk.h",
        ],
        binary_test_file = "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_avoid_deps_ios_simulator.a",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_doStuff"],
        binary_not_contains_symbols = ["_frameworkDependent"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_objc_generated_modulemap_file_content_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcfmwk_with_objc_sdk_dylibs_and_and_sdk_frameworks",
        text_test_file = "$BUNDLE_ROOT/ios-arm64/Headers/module.modulemap",
        text_test_values = [
            "framework module ios_static_xcfmwk_with_objc_sdk_dylibs_and_and_sdk_frameworks",
            "umbrella header \"ios_static_xcfmwk_with_objc_sdk_dylibs_and_and_sdk_frameworks.h\"",
            "link \"c++\"",
            "link \"sqlite3\"",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_swift_generated_modulemap_file_content_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcfmwk_with_swift_sdk_dylibs_and_and_sdk_frameworks",
        text_test_file = "$BUNDLE_ROOT/ios-arm64/Headers/module.modulemap",
        text_test_values = [
            "framework module ios_static_xcfmwk_with_swift_sdk_dylibs_and_and_sdk_frameworks",
            "umbrella header \"ios_static_xcfmwk_with_swift_sdk_dylibs_and_and_sdk_frameworks.h\"",
            "link \"c++\"",
        ],
        tags = [name],
    )

    # Verifies that the include scanning feature builds for the given XCFramework rule.
    archive_contents_test(
        name = "{}_ios_arm64_cc_include_scanning_test".format(name),
        build_type = "device",
        target_features = ["cc_include_scanning"],
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcframework",
        contains = [
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcframework_ios_device.a",
        ],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
