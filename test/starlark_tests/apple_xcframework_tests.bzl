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
    "bitcode_symbol_map_test",
)
load(
    ":rules/dsyms_test.bzl",
    "dsyms_test",
)
load(
    ":rules/infoplist_contents_test.bzl",
    "infoplist_contents_test",
)
load(
    ":rules/linkmap_test.bzl",
    "linkmap_test",
)

def apple_xcframework_test_suite(name):
    """Test suite for apple_xcframework.

    Args:
      name: the base name to be used in things created by this macro
    """
    infoplist_contents_test(
        name = "{}_ios_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework",
        expected_values = {
            "AvailableLibraries:0:LibraryIdentifier": "ios-arm64",
            "AvailableLibraries:0:LibraryPath": "ios_dynamic_xcframework.framework",
            "AvailableLibraries:0:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:0:SupportedPlatform": "ios",
            "AvailableLibraries:1:LibraryIdentifier": "ios-x86_64-simulator",
            "AvailableLibraries:1:LibraryPath": "ios_dynamic_xcframework.framework",
            "AvailableLibraries:1:SupportedArchitectures:0": "x86_64",
            "AvailableLibraries:1:SupportedPlatform": "ios",
            "AvailableLibraries:1:SupportedPlatformVariant": "simulator",
            "CFBundlePackageType": "XFWK",
            "XCFrameworkFormatVersion": "1.0",
        },
        not_expected_keys = [
            "AvailableLibraries:0:BitcodeSymbolMapsPath",
            "AvailableLibraries:1:BitcodeSymbolMapsPath",
        ],
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_ios_fat_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_lipoed_xcframework",
        expected_values = {
            "AvailableLibraries:0:LibraryIdentifier": "ios-arm64_armv7",
            "AvailableLibraries:0:LibraryPath": "ios_dynamic_lipoed_xcframework.framework",
            "AvailableLibraries:0:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:0:SupportedArchitectures:1": "armv7",
            "AvailableLibraries:0:SupportedPlatform": "ios",
            "AvailableLibraries:1:LibraryIdentifier": "ios-i386_arm64_x86_64-simulator",
            "AvailableLibraries:1:LibraryPath": "ios_dynamic_lipoed_xcframework.framework",
            "AvailableLibraries:1:SupportedArchitectures:0": "i386",
            "AvailableLibraries:1:SupportedArchitectures:1": "arm64",
            "AvailableLibraries:1:SupportedArchitectures:2": "x86_64",
            "AvailableLibraries:1:SupportedPlatform": "ios",
            "AvailableLibraries:1:SupportedPlatformVariant": "simulator",
            "CFBundlePackageType": "XFWK",
            "XCFrameworkFormatVersion": "1.0",
        },
        not_expected_keys = [
            "AvailableLibraries:0:BitcodeSymbolMapsPath",
            "AvailableLibraries:1:BitcodeSymbolMapsPath",
        ],
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_ios_plist_bitcode_test".format(name),
        apple_bitcode = "embedded",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework",
        expected_values = {
            "AvailableLibraries:0:LibraryIdentifier": "ios-arm64",
            "AvailableLibraries:0:BitcodeSymbolMapsPath": "BCSymbolMaps",
            "AvailableLibraries:1:LibraryIdentifier": "ios-x86_64-simulator",
        },
        not_expected_keys = [
            "AvailableLibraries:1:BitcodeSymbolMapsPath",
        ],
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_ios_fat_plist_bitcode_test".format(name),
        apple_bitcode = "embedded",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_lipoed_xcframework",
        expected_values = {
            "AvailableLibraries:0:LibraryIdentifier": "ios-arm64_armv7",
            "AvailableLibraries:0:BitcodeSymbolMapsPath": "BCSymbolMaps",
            "AvailableLibraries:1:LibraryIdentifier": "ios-i386_arm64_x86_64-simulator",
        },
        not_expected_keys = [
            "AvailableLibraries:1:BitcodeSymbolMapsPath",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_ios_generated_modulemap_file_content_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework",
        text_test_file = "$BUNDLE_ROOT/ios-arm64/ios_dynamic_xcframework.framework/Modules/module.modulemap",
        text_test_values = [
            "framework module ios_dynamic_xcframework",
            "header \"ios_dynamic_xcframework.h\"",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_ios_arm64_device_archive_contents_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework",
        binary_test_file = "$BUNDLE_ROOT/ios-arm64/ios_dynamic_xcframework.framework/ios_dynamic_xcframework",
        macho_load_commands_contain = ["name @rpath/ios_dynamic_xcframework.framework/ios_dynamic_xcframework (offset 24)"],
        contains = [
            "$BUNDLE_ROOT/ios-arm64/ios_dynamic_xcframework.framework/Headers/shared.h",
            "$BUNDLE_ROOT/ios-arm64/ios_dynamic_xcframework.framework/Headers/ios_dynamic_xcframework.h",
            "$BUNDLE_ROOT/ios-arm64/ios_dynamic_xcframework.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/ios-arm64/ios_dynamic_xcframework.framework/ios_dynamic_xcframework",
            "$BUNDLE_ROOT/ios-arm64/ios_dynamic_xcframework.framework/Info.plist",
            "$BUNDLE_ROOT/Info.plist",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_ios_x86_64_sim_archive_contents_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework",
        binary_test_file = "$BUNDLE_ROOT/ios-x86_64-simulator/ios_dynamic_xcframework.framework/ios_dynamic_xcframework",
        macho_load_commands_contain = ["name @rpath/ios_dynamic_xcframework.framework/ios_dynamic_xcframework (offset 24)"],
        contains = [
            "$BUNDLE_ROOT/ios-x86_64-simulator/ios_dynamic_xcframework.framework/Headers/shared.h",
            "$BUNDLE_ROOT/ios-x86_64-simulator/ios_dynamic_xcframework.framework/Headers/ios_dynamic_xcframework.h",
            "$BUNDLE_ROOT/ios-x86_64-simulator/ios_dynamic_xcframework.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/ios-x86_64-simulator/ios_dynamic_xcframework.framework/ios_dynamic_xcframework",
            "$BUNDLE_ROOT/ios-x86_64-simulator/ios_dynamic_xcframework.framework/Info.plist",
            "$BUNDLE_ROOT/Info.plist",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_ios_fat_device_archive_contents_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_lipoed_xcframework",
        binary_test_file = "$BUNDLE_ROOT/ios-arm64_armv7/ios_dynamic_lipoed_xcframework.framework/ios_dynamic_lipoed_xcframework",
        macho_load_commands_contain = ["name @rpath/ios_dynamic_lipoed_xcframework.framework/ios_dynamic_lipoed_xcframework (offset 24)"],
        contains = [
            "$BUNDLE_ROOT/ios-arm64_armv7/ios_dynamic_lipoed_xcframework.framework/Headers/shared.h",
            "$BUNDLE_ROOT/ios-arm64_armv7/ios_dynamic_lipoed_xcframework.framework/Headers/ios_dynamic_lipoed_xcframework.h",
            "$BUNDLE_ROOT/ios-arm64_armv7/ios_dynamic_lipoed_xcframework.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/ios-arm64_armv7/ios_dynamic_lipoed_xcframework.framework/ios_dynamic_lipoed_xcframework",
            "$BUNDLE_ROOT/ios-arm64_armv7/ios_dynamic_lipoed_xcframework.framework/Info.plist",
            "$BUNDLE_ROOT/Info.plist",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_ios_fat_sim_archive_contents_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_lipoed_xcframework",
        binary_test_file = "$BUNDLE_ROOT/ios-i386_arm64_x86_64-simulator/ios_dynamic_lipoed_xcframework.framework/ios_dynamic_lipoed_xcframework",
        macho_load_commands_contain = ["name @rpath/ios_dynamic_lipoed_xcframework.framework/ios_dynamic_lipoed_xcframework (offset 24)"],
        contains = [
            "$BUNDLE_ROOT/ios-i386_arm64_x86_64-simulator/ios_dynamic_lipoed_xcframework.framework/Headers/shared.h",
            "$BUNDLE_ROOT/ios-i386_arm64_x86_64-simulator/ios_dynamic_lipoed_xcframework.framework/Headers/ios_dynamic_lipoed_xcframework.h",
            "$BUNDLE_ROOT/ios-i386_arm64_x86_64-simulator/ios_dynamic_lipoed_xcframework.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/ios-i386_arm64_x86_64-simulator/ios_dynamic_lipoed_xcframework.framework/ios_dynamic_lipoed_xcframework",
            "$BUNDLE_ROOT/ios-i386_arm64_x86_64-simulator/ios_dynamic_lipoed_xcframework.framework/Info.plist",
            "$BUNDLE_ROOT/Info.plist",
        ],
        tags = [name],
    )

    dsyms_test(
        name = "{}_device_dsyms_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework",
        expected_dsyms = ["ios_dynamic_xcframework_ios_device.framework"],
        architectures = ["arm64"],
        tags = [name],
    )

    dsyms_test(
        name = "{}_simulator_dsyms_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework",
        expected_dsyms = ["ios_dynamic_xcframework_ios_simulator.framework"],
        architectures = ["x86_64"],
        tags = [name],
    )

    dsyms_test(
        name = "{}_fat_device_dsyms_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_lipoed_xcframework",
        expected_dsyms = ["ios_dynamic_lipoed_xcframework_ios_device.framework"],
        architectures = ["arm64", "armv7"],
        tags = [name],
    )

    dsyms_test(
        name = "{}_fat_simulator_dsyms_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_lipoed_xcframework",
        expected_dsyms = ["ios_dynamic_lipoed_xcframework_ios_simulator.framework"],
        architectures = ["x86_64", "arm64", "i386"],
        tags = [name],
    )

    linkmap_test(
        name = "{}_device_linkmap_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework",
        expected_linkmap_names = ["ios_dynamic_xcframework_ios_device"],
        architectures = ["arm64"],
        tags = [name],
    )

    linkmap_test(
        name = "{}_simulator_linkmap_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework",
        expected_linkmap_names = ["ios_dynamic_xcframework_ios_simulator"],
        architectures = ["x86_64"],
        tags = [name],
    )

    linkmap_test(
        name = "{}_fat_device_linkmap_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_lipoed_xcframework",
        expected_linkmap_names = ["ios_dynamic_lipoed_xcframework_ios_device"],
        architectures = ["arm64", "armv7"],
        tags = [name],
    )

    linkmap_test(
        name = "{}_fat_simulator_linkmap_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_lipoed_xcframework",
        expected_linkmap_names = ["ios_dynamic_lipoed_xcframework_ios_simulator"],
        architectures = ["x86_64", "arm64", "i386"],
        tags = [name],
    )

    bitcode_symbol_map_test(
        name = "{}_archive_contains_bitcode_symbol_maps_test".format(name),
        bc_symbol_maps_root = "ios_dynamic_xcframework.xcframework/ios-arm64",
        binary_paths = [
            "ios_dynamic_xcframework.xcframework/ios-arm64/ios_dynamic_xcframework.framework/ios_dynamic_xcframework",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework",
        tags = [name],
    )

    bitcode_symbol_map_test(
        name = "{}_fat_archive_contains_bitcode_symbol_maps_test".format(name),
        bc_symbol_maps_root = "ios_dynamic_lipoed_xcframework.xcframework/ios-arm64_armv7",
        binary_paths = [
            "ios_dynamic_lipoed_xcframework.xcframework/ios-arm64_armv7/ios_dynamic_lipoed_xcframework.framework/ios_dynamic_lipoed_xcframework",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_lipoed_xcframework",
        tags = [name],
    )

    # Tests that minimum os versions values are respected by the embedded frameworks.
    archive_contents_test(
        name = "{}_ios_minimum_os_versions_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework_min_ver_10",
        plist_test_file = "$BUNDLE_ROOT/ios-x86_64-simulator/ios_dynamic_xcframework_min_ver_10.framework/Info.plist",
        plist_test_values = {
            "MinimumOSVersion": "10.0",
        },
        tags = [name],
    )

    # Tests that options to override the device family (in this case, exclusively "ipad" for the iOS
    # platform) are respected by the embedded frameworks.
    archive_contents_test(
        name = "{}_ios_exclusively_ipad_device_family_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework_exclusively_ipad_device_family",
        plist_test_file = "$BUNDLE_ROOT/ios-x86_64-simulator/ios_dynamic_xcframework_exclusively_ipad_device_family.framework/Info.plist",
        plist_test_values = {
            "UIDeviceFamily:0": "2",
        },
        tags = [name],
    )

    # Tests that info plist merging is respected by XCFrameworks.
    archive_contents_test(
        name = "{}_multiple_infoplist_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework_multiple_infoplists",
        plist_test_file = "$BUNDLE_ROOT/ios-x86_64-simulator/ios_dynamic_xcframework_multiple_infoplists.framework/Info.plist",
        plist_test_values = {
            "AnotherKey": "AnotherValue",
            "CFBundleExecutable": "ios_dynamic_xcframework_multiple_infoplists",
        },
        tags = [name],
    )

    # Tests that resource bundles and files assigned through "data" are respected.
    archive_contents_test(
        name = "{}_dbg_resources_data_test".format(name),
        build_type = "device",
        compilation_mode = "dbg",
        is_binary_plist = [
            "$BUNDLE_ROOT/ios-arm64/ios_dynamic_xcframework_with_data_resource_bundle.framework/resource_bundle.bundle/Info.plist",
            "$BUNDLE_ROOT/ios-x86_64-simulator/ios_dynamic_xcframework_with_data_resource_bundle.framework/resource_bundle.bundle/Info.plist",
        ],
        is_not_binary_plist = [
            "$BUNDLE_ROOT/ios-arm64/ios_dynamic_xcframework_with_data_resource_bundle.framework/Another.plist",
            "$BUNDLE_ROOT/ios-x86_64-simulator/ios_dynamic_xcframework_with_data_resource_bundle.framework/Another.plist",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework_with_data_resource_bundle",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_opt_resources_data_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        is_binary_plist = [
            "$BUNDLE_ROOT/ios-arm64/ios_dynamic_xcframework_with_data_resource_bundle.framework/resource_bundle.bundle/Info.plist",
            "$BUNDLE_ROOT/ios-arm64/ios_dynamic_xcframework_with_data_resource_bundle.framework/Another.plist",
            "$BUNDLE_ROOT/ios-x86_64-simulator/ios_dynamic_xcframework_with_data_resource_bundle.framework/resource_bundle.bundle/Info.plist",
            "$BUNDLE_ROOT/ios-x86_64-simulator/ios_dynamic_xcframework_with_data_resource_bundle.framework/Another.plist",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework_with_data_resource_bundle",
        tags = [name],
    )

    # Tests that resource bundles assigned through "deps" are respected.
    archive_contents_test(
        name = "{}_dbg_resources_deps_test".format(name),
        build_type = "device",
        compilation_mode = "dbg",
        is_binary_plist = [
            "$BUNDLE_ROOT/ios-arm64/ios_dynamic_xcframework_with_deps_resource_bundle.framework/resource_bundle.bundle/Info.plist",
            "$BUNDLE_ROOT/ios-x86_64-simulator/ios_dynamic_xcframework_with_deps_resource_bundle.framework/resource_bundle.bundle/Info.plist",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework_with_deps_resource_bundle",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_opt_resources_deps_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        is_binary_plist = [
            "$BUNDLE_ROOT/ios-arm64/ios_dynamic_xcframework_with_deps_resource_bundle.framework/resource_bundle.bundle/Info.plist",
            "$BUNDLE_ROOT/ios-x86_64-simulator/ios_dynamic_xcframework_with_deps_resource_bundle.framework/resource_bundle.bundle/Info.plist",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework_with_deps_resource_bundle",
        tags = [name],
    )

    # Tests that the exported symbols list works for XCFrameworks.
    archive_contents_test(
        name = "{}_exported_symbols_lists_stripped_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework_stripped",
        binary_test_file = "$BUNDLE_ROOT/ios-x86_64-simulator/ios_dynamic_xcframework_stripped.framework/ios_dynamic_xcframework_stripped",
        compilation_mode = "opt",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_anotherFunctionShared"],
        binary_not_contains_symbols = ["_dontCallMeShared", "_anticipatedDeadCode"],
        tags = [name],
    )

    # Tests that multiple exported symbols lists works for XCFrameworks.
    archive_contents_test(
        name = "{}_two_exported_symbols_lists_stripped_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework_stripped_two_exported_symbols_lists",
        binary_test_file = "$BUNDLE_ROOT/ios-x86_64-simulator/ios_dynamic_xcframework_stripped_two_exported_symbols_lists.framework/ios_dynamic_xcframework_stripped_two_exported_symbols_lists",
        compilation_mode = "opt",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_anotherFunctionShared", "_dontCallMeShared"],
        binary_not_contains_symbols = ["_anticipatedDeadCode"],
        tags = [name],
    )

    # Tests that dead stripping + exported symbols lists works for XCFrameworks just as it does for
    # dynamic frameworks.
    archive_contents_test(
        name = "{}_exported_symbols_list_dead_stripped_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework_dead_stripped",
        binary_test_file = "$BUNDLE_ROOT/ios-x86_64-simulator/ios_dynamic_xcframework_dead_stripped.framework/ios_dynamic_xcframework_dead_stripped",
        compilation_mode = "opt",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_anotherFunctionShared"],
        binary_not_contains_symbols = ["_dontCallMeShared", "_anticipatedDeadCode"],
        tags = [name],
    )

    # Tests that generated swift interfaces work for XCFrameworks when a swift_library is included.
    archive_contents_test(
        name = "{}_swift_interface_generation_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_lipoed_swift_xcframework",
        contains = [
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_dynamic_lipoed_swift_xcframework.framework/Modules/ios_dynamic_lipoed_swift_xcframework.swiftmodule/arm64.swiftdoc",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_dynamic_lipoed_swift_xcframework.framework/Modules/ios_dynamic_lipoed_swift_xcframework.swiftmodule/arm64.swiftinterface",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_dynamic_lipoed_swift_xcframework.framework/Modules/ios_dynamic_lipoed_swift_xcframework.swiftmodule/x86_64.swiftdoc",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_dynamic_lipoed_swift_xcframework.framework/Modules/ios_dynamic_lipoed_swift_xcframework.swiftmodule/x86_64.swiftinterface",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_dynamic_lipoed_swift_xcframework.framework/ios_dynamic_lipoed_swift_xcframework",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_dynamic_lipoed_swift_xcframework.framework/Info.plist",
            "$BUNDLE_ROOT/ios-arm64/ios_dynamic_lipoed_swift_xcframework.framework/Modules/ios_dynamic_lipoed_swift_xcframework.swiftmodule/arm64.swiftdoc",
            "$BUNDLE_ROOT/ios-arm64/ios_dynamic_lipoed_swift_xcframework.framework/Modules/ios_dynamic_lipoed_swift_xcframework.swiftmodule/arm64.swiftinterface",
            "$BUNDLE_ROOT/ios-arm64/ios_dynamic_lipoed_swift_xcframework.framework/ios_dynamic_lipoed_swift_xcframework",
            "$BUNDLE_ROOT/ios-arm64/ios_dynamic_lipoed_swift_xcframework.framework/Info.plist",
            "$BUNDLE_ROOT/Info.plist",
        ],
        tags = [name],
    )

    # Test that the Swift generated header is propagated to the Headers visible within this iOS
    # framework along with the swift interfaces and modulemap.
    archive_contents_test(
        name = "{}_swift_generates_header_test".format(name),
        build_type = "simulator",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_swift_xcframework_with_generated_header",
        contains = [
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/SwiftFmwkWithGenHeader.framework/Headers/SwiftFmwkWithGenHeader.h",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/SwiftFmwkWithGenHeader.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/SwiftFmwkWithGenHeader.framework/Modules/SwiftFmwkWithGenHeader.swiftmodule/arm64.swiftdoc",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/SwiftFmwkWithGenHeader.framework/Modules/SwiftFmwkWithGenHeader.swiftmodule/arm64.swiftinterface",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/SwiftFmwkWithGenHeader.framework/Modules/SwiftFmwkWithGenHeader.swiftmodule/x86_64.swiftdoc",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/SwiftFmwkWithGenHeader.framework/Modules/SwiftFmwkWithGenHeader.swiftmodule/x86_64.swiftinterface",
            "$BUNDLE_ROOT/ios-arm64/SwiftFmwkWithGenHeader.framework/Headers/SwiftFmwkWithGenHeader.h",
            "$BUNDLE_ROOT/ios-arm64/SwiftFmwkWithGenHeader.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/ios-arm64/SwiftFmwkWithGenHeader.framework/Modules/SwiftFmwkWithGenHeader.swiftmodule/arm64.swiftdoc",
            "$BUNDLE_ROOT/ios-arm64/SwiftFmwkWithGenHeader.framework/Modules/SwiftFmwkWithGenHeader.swiftmodule/arm64.swiftinterface",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_ios_bundle_name_contents_swift_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_swift_xcframework_with_generated_header",
        text_test_file = "$BUNDLE_ROOT/ios-arm64/SwiftFmwkWithGenHeader.framework/Modules/module.modulemap",
        text_test_values = [
            "framework module SwiftFmwkWithGenHeader",
            "header \"SwiftFmwkWithGenHeader.h\"",
            "requires objc",
        ],
        tags = [name],
    )

    # Verifies that the include scanning feature builds for the given XCFramework rule.
    archive_contents_test(
        name = "{}_ios_arm64_cc_include_scanning_test".format(name),
        build_type = "device",
        target_features = ["cc_include_scanning"],
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework",
        contains = [
            "$BUNDLE_ROOT/ios-arm64/ios_dynamic_xcframework.framework/ios_dynamic_xcframework",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_custom_umbrella_header_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework_umbrella_header",
        text_test_file = "$BUNDLE_ROOT/ios-arm64/ios_dynamic_xcframework_umbrella_header.framework/Modules/module.modulemap",
        text_test_values = [
            "framework module ios_dynamic_xcframework",
            "header \"Umbrella.h\"",
        ],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
