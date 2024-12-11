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
    "//test/starlark_tests/rules:analysis_failure_message_test.bzl",
    "analysis_failure_message_test",
)
load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "archive_contents_test",
)
load(
    "//test/starlark_tests/rules:infoplist_contents_test.bzl",
    "infoplist_contents_test",
)
load(
    ":common.bzl",
    "common",
)

visibility("private")

def apple_static_xcframework_test_suite(name):
    """Test suite for apple_static_xcframework.

    Args:
      name: the base name to be used in things created by this macro
    """

    # Test Objective-C(++) XCFramework Info.plist contents with and without public headers.
    infoplist_contents_test(
        name = "{}_objc_without_public_headers_infoplist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcframework_objc_with_no_public_headers",
        expected_values = {
            "AvailableLibraries:0:LibraryIdentifier": "ios-arm64",
            "AvailableLibraries:0:LibraryPath": "ios_static_xcframework_objc_with_no_public_headers.a",
            "AvailableLibraries:0:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:0:SupportedPlatform": "ios",
            "AvailableLibraries:1:LibraryIdentifier": "ios-arm64_x86_64-simulator",
            "AvailableLibraries:1:LibraryPath": "ios_static_xcframework_objc_with_no_public_headers.a",
            "AvailableLibraries:1:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:1:SupportedArchitectures:1": "x86_64",
            "AvailableLibraries:1:SupportedPlatform": "ios",
            "AvailableLibraries:1:SupportedPlatformVariant": "simulator",
            "CFBundlePackageType": "XFWK",
            "XCFrameworkFormatVersion": "1.0",
        },
        not_expected_keys = [
            "AvailableLibraries:0:HeadersPath",
            "AvailableLibraries:1:HeadersPath",
        ],
        tags = [name],
    )
    infoplist_contents_test(
        name = "{}_objc_with_public_headers_infoplist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcframework_oldest_supported",
        expected_values = {
            "AvailableLibraries:0:LibraryIdentifier": "ios-arm64",
            "AvailableLibraries:0:LibraryPath": "ios_static_xcframework_oldest_supported.a",
            "AvailableLibraries:0:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:0:SupportedPlatform": "ios",
            "AvailableLibraries:0:HeadersPath": "Headers",
            "AvailableLibraries:1:LibraryIdentifier": "ios-arm64_x86_64-simulator",
            "AvailableLibraries:1:LibraryPath": "ios_static_xcframework_oldest_supported.a",
            "AvailableLibraries:1:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:1:SupportedArchitectures:1": "x86_64",
            "AvailableLibraries:1:SupportedPlatform": "ios",
            "AvailableLibraries:1:SupportedPlatformVariant": "simulator",
            "AvailableLibraries:1:HeadersPath": "Headers",
            "CFBundlePackageType": "XFWK",
            "XCFrameworkFormatVersion": "1.0",
        },
        tags = [name],
    )

    # Test Swift XCFramework Info.plist contents with and without Swift generated headers.
    infoplist_contents_test(
        name = "{}_swift_without_generated_headers_infoplist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcfmwk_with_swift",
        expected_values = {
            "AvailableLibraries:0:LibraryIdentifier": "ios-arm64",
            "AvailableLibraries:0:LibraryPath": "ios_static_xcfmwk_with_swift.a",
            "AvailableLibraries:0:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:0:SupportedPlatform": "ios",
            "AvailableLibraries:1:LibraryIdentifier": "ios-arm64_x86_64-simulator",
            "AvailableLibraries:1:LibraryPath": "ios_static_xcfmwk_with_swift.a",
            "AvailableLibraries:1:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:1:SupportedArchitectures:1": "x86_64",
            "AvailableLibraries:1:SupportedPlatform": "ios",
            "AvailableLibraries:1:SupportedPlatformVariant": "simulator",
            "CFBundlePackageType": "XFWK",
            "XCFrameworkFormatVersion": "1.0",
        },
        not_expected_keys = [
            "AvailableLibraries:0:HeadersPath",
            "AvailableLibraries:1:HeadersPath",
        ],
        tags = [name],
    )
    infoplist_contents_test(
        name = "{}_with_swift_generated_header_infoplist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcfmwk_with_swift_generated_headers",
        expected_values = {
            "AvailableLibraries:0:LibraryIdentifier": "ios-arm64",
            "AvailableLibraries:0:LibraryPath": "ios_static_xcfmwk_with_swift_generated_headers.a",
            "AvailableLibraries:0:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:0:SupportedPlatform": "ios",
            "AvailableLibraries:0:HeadersPath": "Headers",
            "AvailableLibraries:1:LibraryIdentifier": "ios-arm64_x86_64-simulator",
            "AvailableLibraries:1:LibraryPath": "ios_static_xcfmwk_with_swift_generated_headers.a",
            "AvailableLibraries:1:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:1:SupportedArchitectures:1": "x86_64",
            "AvailableLibraries:1:SupportedPlatform": "ios",
            "AvailableLibraries:1:SupportedPlatformVariant": "simulator",
            "AvailableLibraries:1:HeadersPath": "Headers",
            "CFBundlePackageType": "XFWK",
            "XCFrameworkFormatVersion": "1.0",
        },
        tags = [name],
    )

    archive_contents_test(
        name = "{}_ios_root_plist_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcframework",
        plist_test_file = "$BUNDLE_ROOT/Info.plist",
        plist_test_values = {
            "AvailableLibraries:0:HeadersPath": "Headers",
            "AvailableLibraries:0:LibraryIdentifier": "ios-arm64",
            "AvailableLibraries:0:LibraryPath": "ios_static_xcframework.a",
            "AvailableLibraries:0:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:0:SupportedPlatform": "ios",
            "AvailableLibraries:1:HeadersPath": "Headers",
            "AvailableLibraries:1:LibraryIdentifier": "ios-arm64_x86_64-simulator",
            "AvailableLibraries:1:LibraryPath": "ios_static_xcframework.a",
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
            "$BUNDLE_ROOT/ios-arm64/Headers/ios_static_xcframework/shared.h",
            "$BUNDLE_ROOT/ios-arm64/Headers/ios_static_xcframework/ios_static_xcframework.h",
            "$BUNDLE_ROOT/ios-arm64/Headers/ios_static_xcframework/module.modulemap",
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcframework.a",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/Headers/ios_static_xcframework/shared.h",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/Headers/ios_static_xcframework/ios_static_xcframework.h",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/Headers/ios_static_xcframework/module.modulemap",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcframework.a",
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
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcfmwk_with_avoid_deps.a",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_avoid_deps.a",
            "$BUNDLE_ROOT/Info.plist",
        ],
        not_contains = [
            "$BUNDLE_ROOT/ios-arm64/Headers/ios_static_xcfmwk_with_avoid_deps/DummyFmwk.h",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/Headers/ios_static_xcfmwk_with_avoid_deps/DummyFmwk.h",
        ],
        binary_test_file = "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_avoid_deps.a",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_doStuff"],
        binary_not_contains_symbols = ["_frameworkDependent"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_objc_generated_modulemap_file_content_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcfmwk_with_objc_sdk_dylibs_and_and_sdk_frameworks",
        text_test_file = "$BUNDLE_ROOT/ios-arm64/Headers/ios_static_xcfmwk_with_objc_sdk_dylibs_and_and_sdk_frameworks/module.modulemap",
        text_test_values = [
            "module ios_static_xcfmwk_with_objc_sdk_dylibs_and_and_sdk_frameworks",
            "umbrella header \"ios_static_xcfmwk_with_objc_sdk_dylibs_and_and_sdk_frameworks.h\"",
            "link \"c++\"",
            "link \"sqlite3\"",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_swift_ios_arm64_x86_64_archive_contents_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcfmwk_with_swift",
        contains = [
            "$BUNDLE_ROOT/Info.plist",
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcfmwk_with_swift.swiftmodule/arm64.swiftdoc",
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcfmwk_with_swift.swiftmodule/arm64.swiftinterface",
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcfmwk_with_swift.a",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_swift.swiftmodule/arm64.swiftdoc",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_swift.swiftmodule/arm64.swiftinterface",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_swift.swiftmodule/x86_64.swiftdoc",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_swift.swiftmodule/x86_64.swiftinterface",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_swift.a",
        ],
        tags = [name],
    )

    # Test that the Swift generated header is propagated to the Headers directory visible within
    # this iOS static XCFramework along with the Swift interfaces and modulemap files.
    archive_contents_test(
        name = "{}_swift_generates_header_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcfmwk_with_swift_generated_headers",
        contains = [
            "$BUNDLE_ROOT/Info.plist",
            "$BUNDLE_ROOT/ios-arm64/Headers/ios_static_xcfmwk_with_swift_generated_headers/ios_static_xcfmwk_with_swift_generated_headers.h",
            "$BUNDLE_ROOT/ios-arm64/Headers/ios_static_xcfmwk_with_swift_generated_headers/module.modulemap",
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcfmwk_with_swift_generated_headers.swiftmodule/arm64.swiftdoc",
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcfmwk_with_swift_generated_headers.swiftmodule/arm64.swiftinterface",
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcfmwk_with_swift_generated_headers.a",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/Headers/ios_static_xcfmwk_with_swift_generated_headers/ios_static_xcfmwk_with_swift_generated_headers.h",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/Headers/ios_static_xcfmwk_with_swift_generated_headers/module.modulemap",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_swift_generated_headers.swiftmodule/arm64.swiftdoc",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_swift_generated_headers.swiftmodule/arm64.swiftinterface",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_swift_generated_headers.swiftmodule/x86_64.swiftdoc",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_swift_generated_headers.swiftmodule/x86_64.swiftinterface",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_swift_generated_headers.a",
        ],
        tags = [name],
    )

    # Test that headers specified from a swift_library's hdrs are propagated to the Headers
    # directory along with the Swift generated header within this iOS static library XCFramework
    # along with the Swift interfaces and modulemap files.
    archive_contents_test(
        name = "{}_swift_generates_header_and_custom_headers_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcfmwk_with_swift_generated_header_and_custom_headers",
        contains = [
            "$BUNDLE_ROOT/Info.plist",
            "$BUNDLE_ROOT/ios-arm64/Headers/ios_static_xcfmwk_with_swift_generated_header_and_custom_headers/DummyFmwk.h",
            "$BUNDLE_ROOT/ios-arm64/Headers/ios_static_xcfmwk_with_swift_generated_header_and_custom_headers/ios_static_xcfmwk_with_swift_generated_header_and_custom_headers.h",
            "$BUNDLE_ROOT/ios-arm64/Headers/ios_static_xcfmwk_with_swift_generated_header_and_custom_headers/module.modulemap",
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcfmwk_with_swift_generated_header_and_custom_headers.swiftmodule/arm64.swiftdoc",
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcfmwk_with_swift_generated_header_and_custom_headers.swiftmodule/arm64.swiftinterface",
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcfmwk_with_swift_generated_header_and_custom_headers.a",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/Headers/ios_static_xcfmwk_with_swift_generated_header_and_custom_headers/DummyFmwk.h",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/Headers/ios_static_xcfmwk_with_swift_generated_header_and_custom_headers/ios_static_xcfmwk_with_swift_generated_header_and_custom_headers.h",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/Headers/ios_static_xcfmwk_with_swift_generated_header_and_custom_headers/module.modulemap",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_swift_generated_header_and_custom_headers.swiftmodule/arm64.swiftdoc",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_swift_generated_header_and_custom_headers.swiftmodule/arm64.swiftinterface",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_swift_generated_header_and_custom_headers.swiftmodule/x86_64.swiftdoc",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_swift_generated_header_and_custom_headers.swiftmodule/x86_64.swiftinterface",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_swift_generated_header_and_custom_headers.a",
        ],
        tags = [name],
    )

    # Test that headers specified from a swift_library's hdrs are propagated to the Headers
    # directory along with the Swift generated header within this iOS static framework XCFramework
    # along with the Swift interfaces and modulemap files.
    archive_contents_test(
        name = "{}_swift_framework_generates_header_and_custom_headers_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers",
        contains = [
            "$BUNDLE_ROOT/Info.plist",
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers.framework/Headers/DummyFmwk.h",
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers.framework/Headers/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers.h",
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers.framework/Headers/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers-Swift.h",
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers.framework/Modules/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers.swiftmodule/arm64.swiftdoc",
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers.framework/Modules/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers.swiftmodule/arm64.swiftinterface",
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers.framework/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers.framework/Headers/DummyFmwk.h",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers.framework/Headers/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers.h",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers.framework/Headers/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers-Swift.h",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers.framework/Modules/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers.swiftmodule/arm64.swiftdoc",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers.framework/Modules/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers.swiftmodule/arm64.swiftinterface",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers.framework/Modules/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers.swiftmodule/x86_64.swiftdoc",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers.framework/Modules/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers.swiftmodule/x86_64.swiftinterface",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers.framework/ios_static_xcfmwk_framework_with_swift_generated_header_and_custom_headers",
        ],
        tags = [name],
    )

    # Tests below verify device/simulator builds for static libraries using Mach-O load commands.
    # Logic behind which load command gets written, and platform information can be found on LLVM's:
    #     - llvm/include/llvm/BinaryFormat/MachO.h
    #     - llvm/llvm-project/llvm/lib/MC/MCStreamer.cpp

    # Verify device/simulator static libraries with Mach-O load commands:
    #   - LC_BUILD_VERSION: Present if target minimum version is above 12.0 or is arm64 sim.
    archive_contents_test(
        name = "{}_ios_arm64_macho_load_cmd_for_simulator".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcframework_oldest_supported",
        binary_test_architecture = "arm64",
        binary_test_file = "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcframework_oldest_supported.a",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_ios.arm_sim_support, "platform IOSSIMULATOR"],
        macho_load_commands_not_contain = ["cmd LC_VERSION_MIN_IPHONEOS"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_ios_x86_64_above_12_0_macho_load_cmd_for_simulator".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcframework",
        binary_test_architecture = "x86_64",
        binary_test_file = "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcframework.a",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform IOSSIMULATOR"],
        macho_load_commands_not_contain = ["cmd LC_VERSION_MIN_IPHONEOS"],
        tags = [name],
    )

    # Verifies device static libraries build with Mach-O load commands.
    #   - LC_BUILD_VERSION: Present if target minimum version is above 12.0.
    archive_contents_test(
        name = "{}_ios_x86_64_arm64_above_12_0_macho_load_cmd_for_device".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcframework",
        binary_test_file = "$BUNDLE_ROOT/ios-arm64/ios_static_xcframework.a",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_ios.baseline, "platform IOS"],
        macho_load_commands_not_contain = ["cmd LC_VERSION_MIN_IPHONEOS"],
        tags = [name],
    )

    # Verifies that the include scanning feature builds for the given XCFramework rule.
    archive_contents_test(
        name = "{}_ios_arm64_cc_include_scanning_test".format(name),
        build_type = "device",
        target_features = ["cc_include_scanning"],
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcframework",
        contains = [
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcframework.a",
        ],
        tags = [name],
    )

    # Verifies that bundle_name changes the embedded static libraries and the modulemap file as well
    # as the name of the bundle for the xcframeworks.
    archive_contents_test(
        name = "{}_ios_bundle_name_contents_swift_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcfmwk_with_swift_and_bundle_name",
        contains = [
            "$ARCHIVE_ROOT/ios_static_xcfmwk_with_custom_bundle_name.xcframework/",
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcfmwk_with_custom_bundle_name.a",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_custom_bundle_name.a",
        ],
        text_test_file = "$BUNDLE_ROOT/ios-arm64/Headers/ios_static_xcfmwk_with_custom_bundle_name/module.modulemap",
        text_test_values = [
            "module ios_static_xcfmwk_with_custom_bundle_name",
            "header \"ios_static_xcfmwk_with_custom_bundle_name.h\"",
            "requires objc",
        ],
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_overreaching_avoid_deps_swift_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_swift_static_xcframework_with_broad_avoid_deps",
        expected_error = "Error: Could not find a Swift module to build a Swift framework. This could be because \"avoid_deps\" is too broadly defined.",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_with_two_top_level_swift_modules_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_swift_static_xcframework_with_two_top_level_modules",
        expected_error = "Error: Found more than one non-system Swift module in the deps of this XCFramework rule. Check that you are not directly referencing more than one swift_library rule in the deps of the rule.",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_with_invalid_swift_module_deps_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_swift_static_xcframework_with_invalid_module_deps",
        expected_error = "Error: Found more than one Swift module dependency in this XCFramework's deps: SwiftSecondModuleForFmwk, SwiftFmwkWithInvalidModuleDeps\n\nCheck that you are only referencing ONE Swift module, such as from a a swift_library rule, and that there are no additional Swift modules referenced outside of its private_deps, such as from an additional swift_library dependency.",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_with_invalid_attrs_for_library_outputs_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_swift_static_xcframework_with_invalid_attrs_for_library_outputs",
        expected_error = "Error: Attempted to build a library XCFramework, but the resource attribute bundle_id was set.",
        tags = [name],
    )

    # Tests that resource bundles and files assigned through "data" are respected.
    archive_contents_test(
        name = "{}_framework_dbg_resources_data_test".format(name),
        build_type = "device",
        compilation_mode = "dbg",
        is_binary_plist = [
            "$BUNDLE_ROOT/ios-arm64/ios_static_framework_xcframework_with_data_resource_bundle.framework/resource_bundle.bundle/Info.plist",
            "$BUNDLE_ROOT/ios-x86_64-simulator/ios_static_framework_xcframework_with_data_resource_bundle.framework/resource_bundle.bundle/Info.plist",
        ],
        is_not_binary_plist = [
            "$BUNDLE_ROOT/ios-arm64/ios_static_framework_xcframework_with_data_resource_bundle.framework/Another.plist",
            "$BUNDLE_ROOT/ios-x86_64-simulator/ios_static_framework_xcframework_with_data_resource_bundle.framework/Another.plist",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_framework_xcframework_with_data_resource_bundle",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_framework_opt_resources_data_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        is_binary_plist = [
            "$BUNDLE_ROOT/ios-arm64/ios_static_framework_xcframework_with_data_resource_bundle.framework/resource_bundle.bundle/Info.plist",
            "$BUNDLE_ROOT/ios-arm64/ios_static_framework_xcframework_with_data_resource_bundle.framework/Another.plist",
            "$BUNDLE_ROOT/ios-x86_64-simulator/ios_static_framework_xcframework_with_data_resource_bundle.framework/resource_bundle.bundle/Info.plist",
            "$BUNDLE_ROOT/ios-x86_64-simulator/ios_static_framework_xcframework_with_data_resource_bundle.framework/Another.plist",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_framework_xcframework_with_data_resource_bundle",
        tags = [name],
    )

    # Tests that resource bundles assigned through "deps" are respected.
    archive_contents_test(
        name = "{}_framework_dbg_resources_deps_test".format(name),
        build_type = "device",
        compilation_mode = "dbg",
        is_binary_plist = [
            "$BUNDLE_ROOT/ios-arm64/ios_static_framework_xcframework_with_deps_resource_bundle.framework/resource_bundle.bundle/Info.plist",
            "$BUNDLE_ROOT/ios-x86_64-simulator/ios_static_framework_xcframework_with_deps_resource_bundle.framework/resource_bundle.bundle/Info.plist",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_framework_xcframework_with_deps_resource_bundle",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_framework_opt_resources_deps_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        is_binary_plist = [
            "$BUNDLE_ROOT/ios-arm64/ios_static_framework_xcframework_with_deps_resource_bundle.framework/resource_bundle.bundle/Info.plist",
            "$BUNDLE_ROOT/ios-x86_64-simulator/ios_static_framework_xcframework_with_deps_resource_bundle.framework/resource_bundle.bundle/Info.plist",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_framework_xcframework_with_deps_resource_bundle",
        tags = [name],
    )

    # This tests that 2 files which have the same target path into nested bundles do not get
    # deduplicated from the framework even if one is referenced by avoid_deps, as long as they are
    # different files.
    archive_contents_test(
        name = "{}_framework_different_resource_with_same_target_path_is_not_deduped_device_test".format(name),
        build_type = "device",
        plist_test_file = "$BUNDLE_ROOT/ios-arm64/ios_static_framework_xcframework_with_avoid_deps_non_localized_assets.framework/nonlocalized.plist",
        plist_test_values = {
            "SomeKey": "Somevalue",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_framework_xcframework_with_avoid_deps_non_localized_assets",
        tags = [name],
    )
    archive_contents_test(
        name = "{}_framework_different_resource_with_same_target_path_is_not_deduped_simulator_test".format(name),
        build_type = "device",
        plist_test_file = "$BUNDLE_ROOT/ios-x86_64-simulator/ios_static_framework_xcframework_with_avoid_deps_non_localized_assets.framework/nonlocalized.plist",
        plist_test_values = {
            "SomeKey": "Somevalue",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_framework_xcframework_with_avoid_deps_non_localized_assets",
        tags = [name],
    )

    # Tests that if avoid_deps have resource bundles they are not in the framework.
    archive_contents_test(
        name = "{}_framework_resource_bundle_in_avoid_deps_not_in_framework".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_framework_xcframework_with_avoid_deps_resource_bundle",
        not_contains = [
            "$BUNDLE_ROOT/ios-arm64/ios_static_framework_xcframework_with_avoid_deps_resource_bundle.framework/basic.bundle/basic_bundle.txt",
            "$BUNDLE_ROOT/ios-arm64/ios_static_framework_xcframework_with_avoid_deps_resource_bundle.framework/basic.bundle/nested/should_be_nested.strings",
            "$BUNDLE_ROOT/ios-x86_64-simulator/ios_static_framework_xcframework_with_avoid_deps_resource_bundle.framework/basic.bundle/basic_bundle.txt",
            "$BUNDLE_ROOT/ios-x86_64-simulator/ios_static_framework_xcframework_with_avoid_deps_resource_bundle.framework/basic.bundle/nested/should_be_nested.strings",
        ],
        tags = [name],
    )

    # Tests that resources that both frameworks and avoid_deps depend on are present in the
    # .framework directory if both have explicit owners for the resources. As with apps and
    # frameworks, this "explicit owners" relationship comes from an objc_library without sources.
    archive_contents_test(
        name = "{}_framework_shared_resources_with_explicit_owners_in_avoid_deps_and_framework_contains_resources".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_framework_xcframework_with_explicit_owners_structured_resources_in_deps_and_avoid_deps",
        contains = [
            "$BUNDLE_ROOT/ios-arm64/ios_static_framework_xcframework_with_explicit_owners_structured_resources_in_deps_and_avoid_deps.framework/Another.plist",
            "$BUNDLE_ROOT/ios-x86_64-simulator/ios_static_framework_xcframework_with_explicit_owners_structured_resources_in_deps_and_avoid_deps.framework/Another.plist",
        ],
        tags = [name],
    )

    # Tests that resources that both frameworks and avoid_deps depend on are omitted from the
    # framework.
    archive_contents_test(
        name = "{}_framework_resources_in_avoid_deps_stays_in_avoid_deps".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_framework_xcframework_with_resource_bundle_in_deps_and_avoid_deps",
        not_contains = [
            "$BUNDLE_ROOT/ios-arm64/ios_static_framework_xcframework_with_resource_bundle_in_deps_and_avoid_deps.framework/Another.plist",
            "$BUNDLE_ROOT/ios-x86_64-simulator/ios_static_framework_xcframework_with_resource_bundle_in_deps_and_avoid_deps.framework/Another.plist",
        ],
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_framework_overreaching_avoid_deps_swift_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_swift_static_framework_xcframework_with_broad_avoid_deps",
        expected_error = "Error: Could not find a Swift module to build a Swift framework. This could be because \"avoid_deps\" is too broadly defined.",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_ios_swift_framework_arm64_arch_dependent_swiftinterfaces_in_deps".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_swift_static_framework_xcframework_with_arch_dependent_swift_in_deps",
        text_file_not_contains = ["FooX86_64"],
        text_test_file = "$BUNDLE_ROOT/ios-arm64/arch_dependent_swift.framework/Modules/arch_dependent_swift.swiftmodule/arm64.swiftinterface",
        text_test_values = ["FooArm64"],
        contains = [
            "$BUNDLE_ROOT/ios-arm64/arch_dependent_swift.framework/arch_dependent_swift",
            "$BUNDLE_ROOT/ios-arm64/arch_dependent_swift.framework/Modules/arch_dependent_swift.swiftmodule/arm64.swiftinterface",
            "$BUNDLE_ROOT/ios-arm64/arch_dependent_swift.framework/Modules/arch_dependent_swift.swiftmodule/arm64.swiftdoc",
            "$BUNDLE_ROOT/ios-arm64/arch_dependent_swift.framework/Info.plist",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_ios_swift_framework_x86_64_arch_dependent_swiftinterfaces_in_deps".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_swift_static_framework_xcframework_with_arch_dependent_swift_in_deps",
        text_file_not_contains = ["FooArm64"],
        text_test_file = "$BUNDLE_ROOT/ios-x86_64-simulator/arch_dependent_swift.framework/Modules/arch_dependent_swift.swiftmodule/x86_64.swiftinterface",
        text_test_values = ["FooX86_64"],
        contains = [
            "$BUNDLE_ROOT/ios-x86_64-simulator/arch_dependent_swift.framework/arch_dependent_swift",
            "$BUNDLE_ROOT/ios-x86_64-simulator/arch_dependent_swift.framework/Modules/arch_dependent_swift.swiftmodule/x86_64.swiftdoc",
            "$BUNDLE_ROOT/ios-x86_64-simulator/arch_dependent_swift.framework/Modules/arch_dependent_swift.swiftmodule/x86_64.swiftinterface",
            "$BUNDLE_ROOT/ios-x86_64-simulator/arch_dependent_swift.framework/Info.plist",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_framework_environment_dependent_resources_in_deps".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:static_framework_xcframework_with_device_dependent_resources_in_deps",
        contains = [
            "$BUNDLE_ROOT/tvos-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/static_framework_xcframework_with_device_dependent_resources_in_deps",
            "$BUNDLE_ROOT/tvos-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/tvos_device_dependent_text_file.bundle/tvos_foo_device.txt",
            "$BUNDLE_ROOT/tvos-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/Headers/static_framework_xcframework_with_device_dependent_resources_in_deps.h",
            "$BUNDLE_ROOT/tvos-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/Headers/shared.h",
            "$BUNDLE_ROOT/tvos-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/tvos-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/Info.plist",
            "$BUNDLE_ROOT/tvos-x86_64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/static_framework_xcframework_with_device_dependent_resources_in_deps",
            "$BUNDLE_ROOT/tvos-x86_64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/tvos_device_dependent_text_file.bundle/tvos_foo_sim.txt",
            "$BUNDLE_ROOT/tvos-x86_64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/Headers/static_framework_xcframework_with_device_dependent_resources_in_deps.h",
            "$BUNDLE_ROOT/tvos-x86_64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/Headers/shared.h",
            "$BUNDLE_ROOT/tvos-x86_64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/tvos-x86_64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/Info.plist",
            "$BUNDLE_ROOT/xros-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/static_framework_xcframework_with_device_dependent_resources_in_deps",
            "$BUNDLE_ROOT/xros-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/visionos_device_dependent_text_file.bundle/visionos_foo_device.txt",
            "$BUNDLE_ROOT/xros-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/Headers/static_framework_xcframework_with_device_dependent_resources_in_deps.h",
            "$BUNDLE_ROOT/xros-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/Headers/shared.h",
            "$BUNDLE_ROOT/xros-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/xros-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/Info.plist",
            "$BUNDLE_ROOT/xros-arm64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/static_framework_xcframework_with_device_dependent_resources_in_deps",
            "$BUNDLE_ROOT/xros-arm64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/visionos_device_dependent_text_file.bundle/visionos_foo_sim.txt",
            "$BUNDLE_ROOT/xros-arm64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/Headers/static_framework_xcframework_with_device_dependent_resources_in_deps.h",
            "$BUNDLE_ROOT/xros-arm64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/Headers/shared.h",
            "$BUNDLE_ROOT/xros-arm64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/xros-arm64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/Info.plist",
            "$BUNDLE_ROOT/ios-x86_64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/ios_device_dependent_text_file.bundle/ios_foo_sim.txt",
            "$BUNDLE_ROOT/ios-x86_64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/static_framework_xcframework_with_device_dependent_resources_in_deps",
            "$BUNDLE_ROOT/ios-x86_64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/Headers/static_framework_xcframework_with_device_dependent_resources_in_deps.h",
            "$BUNDLE_ROOT/ios-x86_64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/Headers/shared.h",
            "$BUNDLE_ROOT/ios-x86_64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/ios-x86_64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/Info.plist",
            "$BUNDLE_ROOT/ios-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/ios_device_dependent_text_file.bundle/ios_foo_device.txt",
            "$BUNDLE_ROOT/ios-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/static_framework_xcframework_with_device_dependent_resources_in_deps",
            "$BUNDLE_ROOT/ios-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/Headers/static_framework_xcframework_with_device_dependent_resources_in_deps.h",
            "$BUNDLE_ROOT/ios-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/Headers/shared.h",
            "$BUNDLE_ROOT/ios-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/ios-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps.framework/Info.plist",
            "$BUNDLE_ROOT/Info.plist",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_framework_environment_dependent_resources_in_deps_and_avoid_deps".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps",
        contains = [
            "$BUNDLE_ROOT/tvos-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps",
            "$BUNDLE_ROOT/tvos-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/Headers/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.h",
            "$BUNDLE_ROOT/tvos-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/Headers/shared.h",
            "$BUNDLE_ROOT/tvos-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/tvos-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/Info.plist",
            "$BUNDLE_ROOT/tvos-x86_64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps",
            "$BUNDLE_ROOT/tvos-x86_64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/Headers/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.h",
            "$BUNDLE_ROOT/tvos-x86_64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/Headers/shared.h",
            "$BUNDLE_ROOT/tvos-x86_64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/tvos-x86_64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/Info.plist",
            "$BUNDLE_ROOT/xros-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps",
            "$BUNDLE_ROOT/xros-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/Headers/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.h",
            "$BUNDLE_ROOT/xros-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/Headers/shared.h",
            "$BUNDLE_ROOT/xros-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/xros-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/Info.plist",
            "$BUNDLE_ROOT/xros-arm64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps",
            "$BUNDLE_ROOT/xros-arm64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/Headers/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.h",
            "$BUNDLE_ROOT/xros-arm64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/Headers/shared.h",
            "$BUNDLE_ROOT/xros-arm64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/xros-arm64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/Info.plist",
            "$BUNDLE_ROOT/ios-x86_64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/ios_device_dependent_text_file.bundle/ios_foo_sim.txt",
            "$BUNDLE_ROOT/ios-x86_64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps",
            "$BUNDLE_ROOT/ios-x86_64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/Headers/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.h",
            "$BUNDLE_ROOT/ios-x86_64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/Headers/shared.h",
            "$BUNDLE_ROOT/ios-x86_64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/ios-x86_64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/Info.plist",
            "$BUNDLE_ROOT/ios-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/ios_device_dependent_text_file.bundle/ios_foo_device.txt",
            "$BUNDLE_ROOT/ios-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps",
            "$BUNDLE_ROOT/ios-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/Headers/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.h",
            "$BUNDLE_ROOT/ios-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/Headers/shared.h",
            "$BUNDLE_ROOT/ios-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/ios-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/Info.plist",
            "$BUNDLE_ROOT/Info.plist",
        ],
        not_contains = [
            "$BUNDLE_ROOT/tvos-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/tvos_device_dependent_text_file.bundle/tvos_foo_device.txt",
            "$BUNDLE_ROOT/tvos-x86_64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/tvos_device_dependent_text_file.bundle/tvos_foo_sim.txt",
            "$BUNDLE_ROOT/xros-arm64/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/visionos_device_dependent_text_file.bundle/visionos_foo_device.txt",
            "$BUNDLE_ROOT/xros-arm64-simulator/static_framework_xcframework_with_device_dependent_resources_in_deps_and_avoid_deps.framework/visionos_device_dependent_text_file.bundle/visionos_foo_sim.txt",
        ],
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_framework_has_no_bundle_id_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_framework_xcframework_with_no_bundle_id",
        expected_error = "No bundle ID was given for the target \"ios_static_framework_xcframework_with_no_bundle_id\". Please add one by setting a valid bundle_id on the target.",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_framework_has_invalid_character_bundle_id_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_framework_xcframework_with_invalid_character_bundle_id",
        expected_error = "Error in fail: Invalid character(s) in bundle_id: \"my#bundle\"",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_does_not_define_platforms_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcframework_without_platforms",
        expected_error = """received a minimum OS version for ios, but the platforms to build for that OS were not supplied by a corresponding ios attribute.

Please add a ios attribute to the rule to declare the platforms to build for that OS.""",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_does_not_define_correct_ios_minimum_os_versions_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcframework_without_correct_minimum_os_versions",
        expected_error = """received a minimum OS version for tvos, but the platforms to build for that OS were not supplied by a corresponding tvos attribute.

Please add a tvos attribute to the rule to declare the platforms to build for that OS.""",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_does_not_define_valid_minimum_os_versions_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcframework_without_valid_minimum_os_versions",
        expected_error = "received a minimum OS version for xros, but this is not supported by the XCFramework rules.",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_framework_does_not_define_platforms_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcframework_framework_without_platforms",
        expected_error = """received a minimum OS version for ios, but the platforms to build for that OS were not supplied by a corresponding ios attribute.

Please add a ios attribute to the rule to declare the platforms to build for that OS.""",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_framework_does_not_define_correct_ios_minimum_os_versions_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcframework_framework_without_correct_minimum_os_versions",
        expected_error = """received a minimum OS version for tvos, but the platforms to build for that OS were not supplied by a corresponding tvos attribute.

Please add a tvos attribute to the rule to declare the platforms to build for that OS.""",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_framework_does_not_define_valid_minimum_os_versions_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcframework_framework_without_valid_minimum_os_versions",
        expected_error = "received a minimum OS version for xros, but this is not supported by the XCFramework rules.",
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
