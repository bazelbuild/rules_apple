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
            "$BUNDLE_ROOT/ios-arm64/Headers/shared.h",
            "$BUNDLE_ROOT/ios-arm64/Headers/ios_static_xcframework.h",
            "$BUNDLE_ROOT/ios-arm64/Headers/module.modulemap",
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcframework.a",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/Headers/shared.h",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/Headers/ios_static_xcframework.h",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/Headers/module.modulemap",
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
            "$BUNDLE_ROOT/ios-arm64/Headers/DummyFmwk.h",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/Headers/DummyFmwk.h",
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
        text_test_file = "$BUNDLE_ROOT/ios-arm64/Headers/module.modulemap",
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
    # this iOS statix XCFramework along with the Swift interfaces and modulemap files.
    archive_contents_test(
        name = "{}_swift_generates_header_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcfmwk_with_swift_generated_headers",
        contains = [
            "$BUNDLE_ROOT/Info.plist",
            "$BUNDLE_ROOT/ios-arm64/Headers/ios_static_xcfmwk_with_swift_generated_headers.h",
            "$BUNDLE_ROOT/ios-arm64/Headers/module.modulemap",
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcfmwk_with_swift_generated_headers.swiftmodule/arm64.swiftdoc",
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcfmwk_with_swift_generated_headers.swiftmodule/arm64.swiftinterface",
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcfmwk_with_swift_generated_headers.a",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/Headers/ios_static_xcfmwk_with_swift_generated_headers.h",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/Headers/module.modulemap",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_swift_generated_headers.swiftmodule/arm64.swiftdoc",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_swift_generated_headers.swiftmodule/arm64.swiftinterface",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_swift_generated_headers.swiftmodule/x86_64.swiftdoc",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_swift_generated_headers.swiftmodule/x86_64.swiftinterface",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_swift_generated_headers.a",
        ],
        tags = [name],
    )

    # Tests below verify device/simulator builds for static libraries using Mach-O load commands.
    # Logic behind which load command gets written, and platform information can be found on LLVM's:
    #     - llvm/include/llvm/BinaryFormat/MachO.h
    #     - llvm/llvm-project/llvm/lib/MC/MCStreamer.cpp

    # Verify device/simulator static libraries with Mach-O load commands:
    #   - LC_VERSION_MIN_IOS: Present if target minimum version is below 12.0 and is not arm64 sim.
    #   - LC_BUILD_VERSION: Present if target minimum version is above 12.0 or is arm64 sim.
    archive_contents_test(
        name = "{}_ios_arm64_macho_load_cmd_for_simulator".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcframework",
        binary_test_architecture = "arm64",
        binary_test_file = "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcframework.a",
        macho_load_commands_not_contain = ["cmd LC_VERSION_MIN_IPHONEOS"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_ios_x86_64_below_12_0_macho_load_cmd_for_simulator".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcframework",
        binary_test_architecture = "x86_64",
        binary_test_file = "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcframework.a",
        macho_load_commands_contain = ["cmd LC_VERSION_MIN_IPHONEOS"],
        macho_load_commands_not_contain = ["cmd LC_BUILD_VERSION"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_ios_x86_64_above_12_0_macho_load_cmd_for_simulator".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcframework_min_os_12",
        binary_test_architecture = "x86_64",
        binary_test_file = "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcframework_min_os_12.a",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform 7"],
        macho_load_commands_not_contain = ["cmd LC_VERSION_MIN_IPHONEOS"],
        tags = [name],
    )

    # Verifies device static libraries build with Mach-O load commands.
    #   - LC_VERSION_MIN_IOS: Present if target minimum version is below 12.0.
    #   - LC_BUILD_VERSION: Present if target minimum version is above 12.0.
    archive_contents_test(
        name = "{}_ios_x86_64_arm64_below_12_0_macho_load_cmd_for_device".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcframework",
        binary_test_file = "$BUNDLE_ROOT/ios-arm64/ios_static_xcframework.a",
        macho_load_commands_contain = ["cmd LC_VERSION_MIN_IPHONEOS"],
        macho_load_commands_not_contain = ["cmd LC_BUILD_VERSION"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_ios_x86_64_arm64_above_12_0_macho_load_cmd_for_device".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcframework_min_os_12",
        binary_test_file = "$BUNDLE_ROOT/ios-arm64/ios_static_xcframework_min_os_12.a",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform 2"],
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
        text_test_file = "$BUNDLE_ROOT/ios-arm64/Headers/module.modulemap",
        text_test_values = [
            "module ios_static_xcfmwk_with_custom_bundle_name",
            "header \"ios_static_xcfmwk_with_custom_bundle_name.h\"",
            "requires objc",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_custom_umbrella_header_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_static_xcframework_umbrella_header",
        text_test_file = "$BUNDLE_ROOT/ios-arm64/Headers/module.modulemap",
        text_test_values = [
            "module ios_static_xcframework_umbrella_header",
            "umbrella header \"Umbrella.h\"",
        ],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
