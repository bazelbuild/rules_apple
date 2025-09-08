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
    "//apple/build_settings:build_settings.bzl",
    "build_settings_labels",
)
load(
    "//test/starlark_tests/rules:analysis_failure_message_test.bzl",
    "analysis_failure_message_test",
)
load(
    "//test/starlark_tests/rules:analysis_output_group_info_files_test.bzl",
    "analysis_output_group_info_dsymutil_bundle_files_test",
    "analysis_output_group_info_files_test",
)
load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "archive_contents_test",
)
load(
    "//test/starlark_tests/rules:directory_test.bzl",
    "directory_test",
)
load(
    "//test/starlark_tests/rules:infoplist_contents_test.bzl",
    "infoplist_contents_test",
)
load(
    "//test/starlark_tests/rules:linkmap_test.bzl",
    "linkmap_test",
)
load(
    ":common.bzl",
    "common",
)

visibility("private")

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
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_ios_universal_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_lipoed_xcframework",
        expected_values = {
            "AvailableLibraries:0:LibraryIdentifier": "ios-arm64_arm64e",
            "AvailableLibraries:0:LibraryPath": "ios_dynamic_lipoed_xcframework.framework",
            "AvailableLibraries:0:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:0:SupportedArchitectures:1": "arm64e",
            "AvailableLibraries:0:SupportedPlatform": "ios",
            "AvailableLibraries:1:LibraryIdentifier": "ios-arm64_x86_64-simulator",
            "AvailableLibraries:1:LibraryPath": "ios_dynamic_lipoed_xcframework.framework",
            "AvailableLibraries:1:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:1:SupportedArchitectures:1": "x86_64",
            "AvailableLibraries:1:SupportedPlatform": "ios",
            "AvailableLibraries:1:SupportedPlatformVariant": "simulator",
            "CFBundlePackageType": "XFWK",
            "XCFrameworkFormatVersion": "1.0",
        },
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_tvos_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:tvos_dynamic_xcframework",
        expected_values = {
            "AvailableLibraries:0:LibraryIdentifier": "tvos-arm64",
            "AvailableLibraries:0:LibraryPath": "tvos_dynamic_xcframework.framework",
            "AvailableLibraries:0:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:0:SupportedPlatform": "tvos",
            "AvailableLibraries:1:LibraryIdentifier": "tvos-arm64_x86_64-simulator",
            "AvailableLibraries:1:LibraryPath": "tvos_dynamic_xcframework.framework",
            "AvailableLibraries:1:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:1:SupportedArchitectures:1": "x86_64",
            "AvailableLibraries:1:SupportedPlatform": "tvos",
            "AvailableLibraries:1:SupportedPlatformVariant": "simulator",
            "CFBundlePackageType": "XFWK",
            "XCFrameworkFormatVersion": "1.0",
        },
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_visionos_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:visionos_dynamic_xcframework",
        expected_values = {
            "AvailableLibraries:0:LibraryIdentifier": "xros-arm64",
            "AvailableLibraries:0:LibraryPath": "visionos_dynamic_xcframework.framework",
            "AvailableLibraries:0:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:0:SupportedPlatform": "xros",
            "AvailableLibraries:1:LibraryIdentifier": "xros-arm64-simulator",
            "AvailableLibraries:1:LibraryPath": "visionos_dynamic_xcframework.framework",
            "AvailableLibraries:1:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:1:SupportedPlatform": "xros",
            "AvailableLibraries:1:SupportedPlatformVariant": "simulator",
            "CFBundlePackageType": "XFWK",
            "XCFrameworkFormatVersion": "1.0",
        },
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_multiplatform_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:multiplatform_dynamic_xcframework",
        expected_values = {
            "AvailableLibraries:0:LibraryIdentifier": "ios-arm64",
            "AvailableLibraries:0:LibraryPath": "multiplatform_dynamic_xcframework.framework",
            "AvailableLibraries:0:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:0:SupportedPlatform": "ios",
            "AvailableLibraries:1:LibraryIdentifier": "ios-arm64_x86_64-simulator",
            "AvailableLibraries:1:LibraryPath": "multiplatform_dynamic_xcframework.framework",
            "AvailableLibraries:1:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:1:SupportedArchitectures:1": "x86_64",
            "AvailableLibraries:1:SupportedPlatform": "ios",
            "AvailableLibraries:1:SupportedPlatformVariant": "simulator",
            "AvailableLibraries:2:LibraryIdentifier": "tvos-arm64",
            "AvailableLibraries:2:LibraryPath": "multiplatform_dynamic_xcframework.framework",
            "AvailableLibraries:2:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:2:SupportedPlatform": "tvos",
            "AvailableLibraries:3:LibraryIdentifier": "tvos-arm64_x86_64-simulator",
            "AvailableLibraries:3:LibraryPath": "multiplatform_dynamic_xcframework.framework",
            "AvailableLibraries:3:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:3:SupportedArchitectures:1": "x86_64",
            "AvailableLibraries:3:SupportedPlatform": "tvos",
            "AvailableLibraries:3:SupportedPlatformVariant": "simulator",
            "AvailableLibraries:4:LibraryIdentifier": "xros-arm64",
            "AvailableLibraries:4:LibraryPath": "multiplatform_dynamic_xcframework.framework",
            "AvailableLibraries:4:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:4:SupportedPlatform": "xros",
            "AvailableLibraries:5:LibraryIdentifier": "xros-arm64-simulator",
            "AvailableLibraries:5:LibraryPath": "multiplatform_dynamic_xcframework.framework",
            "AvailableLibraries:5:SupportedArchitectures:0": "arm64",
            "AvailableLibraries:5:SupportedPlatform": "xros",
            "AvailableLibraries:5:SupportedPlatformVariant": "simulator",
            "CFBundlePackageType": "XFWK",
            "XCFrameworkFormatVersion": "1.0",
        },
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
        binary_test_architecture = "arm64",
        macho_load_commands_contain = [
            "name @rpath/ios_dynamic_xcframework.framework/ios_dynamic_xcframework (offset 24)",
            "path @executable_path/Frameworks (offset 12)",
        ],
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
        binary_test_architecture = "x86_64",
        macho_load_commands_contain = [
            "name @rpath/ios_dynamic_xcframework.framework/ios_dynamic_xcframework (offset 24)",
            "path @executable_path/Frameworks (offset 12)",
        ],
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
        name = "{}_ios_universal_device_archive_contents_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_lipoed_xcframework",
        binary_test_file = "$BUNDLE_ROOT/ios-arm64_arm64e/ios_dynamic_lipoed_xcframework.framework/ios_dynamic_lipoed_xcframework",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = [
            "name @rpath/ios_dynamic_lipoed_xcframework.framework/ios_dynamic_lipoed_xcframework (offset 24)",
            "path @executable_path/Frameworks (offset 12)",
        ],
        contains = [
            "$BUNDLE_ROOT/ios-arm64_arm64e/ios_dynamic_lipoed_xcframework.framework/Headers/shared.h",
            "$BUNDLE_ROOT/ios-arm64_arm64e/ios_dynamic_lipoed_xcframework.framework/Headers/ios_dynamic_lipoed_xcframework.h",
            "$BUNDLE_ROOT/ios-arm64_arm64e/ios_dynamic_lipoed_xcframework.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/ios-arm64_arm64e/ios_dynamic_lipoed_xcframework.framework/ios_dynamic_lipoed_xcframework",
            "$BUNDLE_ROOT/ios-arm64_arm64e/ios_dynamic_lipoed_xcframework.framework/Info.plist",
            "$BUNDLE_ROOT/Info.plist",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_ios_universal_sim_archive_contents_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_lipoed_xcframework",
        binary_test_file = "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_dynamic_lipoed_xcframework.framework/ios_dynamic_lipoed_xcframework",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = [
            "name @rpath/ios_dynamic_lipoed_xcframework.framework/ios_dynamic_lipoed_xcframework (offset 24)",
            "path @executable_path/Frameworks (offset 12)",
        ],
        contains = [
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_dynamic_lipoed_xcframework.framework/Headers/shared.h",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_dynamic_lipoed_xcframework.framework/Headers/ios_dynamic_lipoed_xcframework.h",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_dynamic_lipoed_xcframework.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_dynamic_lipoed_xcframework.framework/ios_dynamic_lipoed_xcframework",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_dynamic_lipoed_xcframework.framework/Info.plist",
            "$BUNDLE_ROOT/Info.plist",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_tvos_archive_contents_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:tvos_dynamic_xcframework",
        contains = [
            "$BUNDLE_ROOT/tvos-arm64_x86_64-simulator/tvos_dynamic_xcframework.framework/Headers/shared.h",
            "$BUNDLE_ROOT/tvos-arm64_x86_64-simulator/tvos_dynamic_xcframework.framework/Headers/tvos_dynamic_xcframework.h",
            "$BUNDLE_ROOT/tvos-arm64_x86_64-simulator/tvos_dynamic_xcframework.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/tvos-arm64_x86_64-simulator/tvos_dynamic_xcframework.framework/tvos_dynamic_xcframework",
            "$BUNDLE_ROOT/tvos-arm64_x86_64-simulator/tvos_dynamic_xcframework.framework/Info.plist",
            "$BUNDLE_ROOT/tvos-arm64/tvos_dynamic_xcframework.framework/Headers/shared.h",
            "$BUNDLE_ROOT/tvos-arm64/tvos_dynamic_xcframework.framework/Headers/tvos_dynamic_xcframework.h",
            "$BUNDLE_ROOT/tvos-arm64/tvos_dynamic_xcframework.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/tvos-arm64/tvos_dynamic_xcframework.framework/tvos_dynamic_xcframework",
            "$BUNDLE_ROOT/tvos-arm64/tvos_dynamic_xcframework.framework/Info.plist",
            "$BUNDLE_ROOT/Info.plist",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_visionos_archive_contents_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:visionos_dynamic_xcframework",
        contains = [
            "$BUNDLE_ROOT/xros-arm64-simulator/visionos_dynamic_xcframework.framework/Headers/shared.h",
            "$BUNDLE_ROOT/xros-arm64-simulator/visionos_dynamic_xcframework.framework/Headers/visionos_dynamic_xcframework.h",
            "$BUNDLE_ROOT/xros-arm64-simulator/visionos_dynamic_xcframework.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/xros-arm64-simulator/visionos_dynamic_xcframework.framework/visionos_dynamic_xcframework",
            "$BUNDLE_ROOT/xros-arm64-simulator/visionos_dynamic_xcframework.framework/Info.plist",
            "$BUNDLE_ROOT/xros-arm64/visionos_dynamic_xcframework.framework/Headers/shared.h",
            "$BUNDLE_ROOT/xros-arm64/visionos_dynamic_xcframework.framework/Headers/visionos_dynamic_xcframework.h",
            "$BUNDLE_ROOT/xros-arm64/visionos_dynamic_xcframework.framework/Modules/module.modulemap",
            "$BUNDLE_ROOT/xros-arm64/visionos_dynamic_xcframework.framework/visionos_dynamic_xcframework",
            "$BUNDLE_ROOT/xros-arm64/visionos_dynamic_xcframework.framework/Info.plist",
            "$BUNDLE_ROOT/Info.plist",
        ],
        tags = [name],
    )

    # XCFrameworks do not provide a public AppleDsymBundleInfo provider for the following reasons:
    #
    #     - All dSYMs for embedded frameworks are provided in output groups when specified with the
    #         --output_groups=+dsyms option.
    #     - There are no known end users that require the usage of dSYMs from XCFrameworks that
    #         are not already served by the output groups API.
    #     - XCFrameworks can embed dSYM bundles within the XCFramework bundle on a per-library
    #         identifier basis, which is not something that the rules have previously supported as a
    #         debugging experience, and would not be effectively represented through this particular
    #         public provider interface.
    #
    analysis_output_group_info_files_test(
        name = "{}_dsyms_output_group_files_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework",
        output_group_name = "dsyms",
        expected_outputs = [
            "ios_dynamic_xcframework_ios_device.framework.dSYM/Contents/Info.plist",
            "ios_dynamic_xcframework_ios_device.framework.dSYM/Contents/Resources/DWARF/ios_dynamic_xcframework_ios_device_arm64",
            "ios_dynamic_xcframework_ios_simulator.framework.dSYM/Contents/Info.plist",
            "ios_dynamic_xcframework_ios_simulator.framework.dSYM/Contents/Resources/DWARF/ios_dynamic_xcframework_ios_simulator_x86_64",
        ],
        tags = [name],
    )
    analysis_output_group_info_dsymutil_bundle_files_test(
        name = "{}_dsyms_output_group_dsymutil_bundle_files_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework",
        output_group_name = "dsyms",
        expected_outputs = [
            "ios_dynamic_xcframework_ios_device.framework.dSYM",
            "ios_dynamic_xcframework_ios_simulator.framework.dSYM",
        ],
        tags = [name],
    )
    analysis_output_group_info_files_test(
        name = "{}_universal_frameworks_dsyms_output_group_files_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_lipoed_xcframework",
        output_group_name = "dsyms",
        expected_outputs = [
            "ios_dynamic_lipoed_xcframework_ios_device.framework.dSYM/Contents/Info.plist",
            "ios_dynamic_lipoed_xcframework_ios_device.framework.dSYM/Contents/Resources/DWARF/ios_dynamic_lipoed_xcframework_ios_device_arm64",
            "ios_dynamic_lipoed_xcframework_ios_device.framework.dSYM/Contents/Resources/DWARF/ios_dynamic_lipoed_xcframework_ios_device_arm64e",
            "ios_dynamic_lipoed_xcframework_ios_simulator.framework.dSYM/Contents/Info.plist",
            "ios_dynamic_lipoed_xcframework_ios_simulator.framework.dSYM/Contents/Resources/DWARF/ios_dynamic_lipoed_xcframework_ios_simulator_arm64",
            "ios_dynamic_lipoed_xcframework_ios_simulator.framework.dSYM/Contents/Resources/DWARF/ios_dynamic_lipoed_xcframework_ios_simulator_x86_64",
        ],
        tags = [name],
    )
    analysis_output_group_info_dsymutil_bundle_files_test(
        name = "{}_universal_frameworks_dsyms_output_group_dsymutil_bundle_files_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_lipoed_xcframework",
        output_group_name = "dsyms",
        expected_outputs = [
            "ios_dynamic_lipoed_xcframework_ios_device.framework.dSYM",
            "ios_dynamic_lipoed_xcframework_ios_simulator.framework.dSYM",
        ],
        tags = [name],
    )

    directory_test(
        name = "{}_dsym_directory_test".format(name),
        apple_generate_dsym = True,
        build_type = "device",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_lipoed_xcframework",
        expected_directories = {
            "ios_dynamic_lipoed_xcframework_ios_device.framework.dSYM": [
                "Contents/Resources/DWARF/ios_dynamic_lipoed_xcframework_bin",
                "Contents/Info.plist",
            ],
            "ios_dynamic_lipoed_xcframework_ios_simulator.framework.dSYM": [
                "Contents/Resources/DWARF/ios_dynamic_lipoed_xcframework_bin",
                "Contents/Info.plist",
            ],
        },
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
    analysis_output_group_info_files_test(
        name = "{}_linkmaps_output_group_info_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework",
        output_group_name = "linkmaps",
        expected_outputs = [
            "ios_dynamic_xcframework_ios_simulator_x86_64.linkmap",
            "ios_dynamic_xcframework_ios_device_arm64.linkmap",
        ],
        tags = [name],
    )

    linkmap_test(
        name = "{}_universal_device_linkmap_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_lipoed_xcframework",
        expected_linkmap_names = ["ios_dynamic_lipoed_xcframework_ios_device"],
        architectures = ["arm64", "arm64e"],
        tags = [name],
    )
    linkmap_test(
        name = "{}_universal_simulator_linkmap_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_lipoed_xcframework",
        expected_linkmap_names = ["ios_dynamic_lipoed_xcframework_ios_simulator"],
        architectures = ["x86_64", "arm64"],
        tags = [name],
    )
    analysis_output_group_info_files_test(
        name = "{}_multiple_architectures_linkmaps_output_group_info_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_lipoed_xcframework",
        output_group_name = "linkmaps",
        expected_outputs = [
            "ios_dynamic_lipoed_xcframework_ios_device_arm64.linkmap",
            "ios_dynamic_lipoed_xcframework_ios_device_arm64e.linkmap",
            "ios_dynamic_lipoed_xcframework_ios_simulator_arm64.linkmap",
            "ios_dynamic_lipoed_xcframework_ios_simulator_x86_64.linkmap",
        ],
        tags = [name],
    )

    # Tests that minimum os versions values are respected by the embedded frameworks.
    archive_contents_test(
        name = "{}_ios_minimum_os_versions_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework",
        plist_test_file = "$BUNDLE_ROOT/ios-x86_64-simulator/ios_dynamic_xcframework.framework/Info.plist",
        plist_test_values = {
            "MinimumOSVersion": common.min_os_ios.baseline,
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

    # Test tvOS XCFramework binaries contain Mach-O load commands for device or simulator.
    archive_contents_test(
        name = "{}_tvos_simulator_binary_contains_macho_load_cmd_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:tvos_dynamic_xcframework",
        binary_test_file = "$BUNDLE_ROOT/tvos-arm64_x86_64-simulator/tvos_dynamic_xcframework.framework/tvos_dynamic_xcframework",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform TVOSSIMULATOR"],
        macho_load_commands_not_contain = ["cmd LC_VERSION_MIN_TVOS"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_tvos_device_binary_contains_macho_load_cmd_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:tvos_dynamic_xcframework",
        binary_test_file = "$BUNDLE_ROOT/tvos-arm64/tvos_dynamic_xcframework.framework/tvos_dynamic_xcframework",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform TVOS"],
        macho_load_commands_not_contain = ["cmd LC_VERSION_MIN_TVOS"],
        tags = [name],
    )

    # Test visionOS XCFramework binaries contain Mach-O load commands for device or simulator.
    archive_contents_test(
        name = "{}_visionos_simulator_binary_contains_macho_load_cmd_pre_xcode26_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:visionos_dynamic_xcframework",
        binary_test_file = "$BUNDLE_ROOT/xros-arm64-simulator/visionos_dynamic_xcframework.framework/visionos_dynamic_xcframework",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform XROSSIMULATOR"],
        macho_load_commands_not_contain = ["cmd LC_VERSION_MIN_XROS"],
        tags = [
            name,
        ],
    )
    archive_contents_test(
        name = "{}_visionos_device_binary_contains_macho_load_cmd_pre_xcode26_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:visionos_dynamic_xcframework",
        binary_test_file = "$BUNDLE_ROOT/xros-arm64/visionos_dynamic_xcframework.framework/visionos_dynamic_xcframework",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform XROS"],
        macho_load_commands_not_contain = ["cmd LC_VERSION_MIN_XROS"],
        tags = [
            name,
        ],
    )
    archive_contents_test(
        name = "{}_visionos_simulator_binary_contains_macho_load_cmd_post_xcode26_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:visionos_dynamic_xcframework",
        binary_test_file = "$BUNDLE_ROOT/xros-arm64-simulator/visionos_dynamic_xcframework.framework/visionos_dynamic_xcframework",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform VISIONOSSIMULATOR"],
        macho_load_commands_not_contain = ["cmd LC_VERSION_MIN_XROS"],
        tags = [
            name,
        ],
    )
    archive_contents_test(
        name = "{}_visionos_device_binary_contains_macho_load_cmd_post_xcode26_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:visionos_dynamic_xcframework",
        binary_test_file = "$BUNDLE_ROOT/xros-arm64/visionos_dynamic_xcframework.framework/visionos_dynamic_xcframework",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform VISIONOS"],
        macho_load_commands_not_contain = ["cmd LC_VERSION_MIN_XROS"],
        tags = [
            name,
        ],
    )

    # Test tvOS XCFramework binaries have the correct rpaths.
    archive_contents_test(
        name = "{}_tvos_simulator_binary_contains_arm64_rpaths_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:tvos_dynamic_xcframework",
        binary_test_file = "$BUNDLE_ROOT/tvos-arm64_x86_64-simulator/tvos_dynamic_xcframework.framework/tvos_dynamic_xcframework",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = [
            "name @rpath/tvos_dynamic_xcframework.framework/tvos_dynamic_xcframework (offset 24)",
            "path @executable_path/Frameworks (offset 12)",
        ],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_tvos_simulator_binary_contains_x86_64_rpaths_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:tvos_dynamic_xcframework",
        binary_test_file = "$BUNDLE_ROOT/tvos-arm64_x86_64-simulator/tvos_dynamic_xcframework.framework/tvos_dynamic_xcframework",
        binary_test_architecture = "x86_64",
        macho_load_commands_contain = [
            "name @rpath/tvos_dynamic_xcframework.framework/tvos_dynamic_xcframework (offset 24)",
            "path @executable_path/Frameworks (offset 12)",
        ],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_tvos_device_binary_contains_rpaths_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:tvos_dynamic_xcframework",
        binary_test_file = "$BUNDLE_ROOT/tvos-arm64/tvos_dynamic_xcframework.framework/tvos_dynamic_xcframework",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = [
            "name @rpath/tvos_dynamic_xcframework.framework/tvos_dynamic_xcframework (offset 24)",
            "path @executable_path/Frameworks (offset 12)",
        ],
        tags = [name],
    )

    # Test visionOS XCFramework binaries have the correct rpaths.
    archive_contents_test(
        name = "{}_visionos_simulator_binary_contains_arm64_rpaths_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:visionos_dynamic_xcframework",
        binary_test_file = "$BUNDLE_ROOT/xros-arm64-simulator/visionos_dynamic_xcframework.framework/visionos_dynamic_xcframework",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = [
            "name @rpath/visionos_dynamic_xcframework.framework/visionos_dynamic_xcframework (offset 24)",
            "path @executable_path/Frameworks (offset 12)",
        ],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_visionos_simulator_binary_contains_x86_64_rpaths_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:visionos_dynamic_xcframework",
        binary_test_file = "$BUNDLE_ROOT/xros-arm64-simulator/visionos_dynamic_xcframework.framework/visionos_dynamic_xcframework",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = [
            "name @rpath/visionos_dynamic_xcframework.framework/visionos_dynamic_xcframework (offset 24)",
            "path @executable_path/Frameworks (offset 12)",
        ],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_visionos_device_binary_contains_rpaths_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:visionos_dynamic_xcframework",
        binary_test_file = "$BUNDLE_ROOT/xros-arm64/visionos_dynamic_xcframework.framework/visionos_dynamic_xcframework",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = [
            "name @rpath/visionos_dynamic_xcframework.framework/visionos_dynamic_xcframework (offset 24)",
            "path @executable_path/Frameworks (offset 12)",
        ],
        tags = [name],
    )

    directory_test(
        name = "{}_ios_dynamic_xcframework_tree_artifact_test".format(name),
        build_settings = {
            build_settings_labels.use_tree_artifacts_outputs: "True",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework",
        expected_directories = {
            "ios_dynamic_xcframework.xcframework": [
                "Info.plist",
                "ios-arm64/ios_dynamic_xcframework.framework/ios_dynamic_xcframework",
                "ios-arm64/ios_dynamic_xcframework.framework/Info.plist",
                "ios-arm64/ios_dynamic_xcframework.framework/Headers/ios_dynamic_xcframework.h",
                "ios-arm64/ios_dynamic_xcframework.framework/Headers/shared.h",
                "ios-arm64/ios_dynamic_xcframework.framework/Modules/module.modulemap",
                "ios-x86_64-simulator/ios_dynamic_xcframework.framework/ios_dynamic_xcframework",
                "ios-x86_64-simulator/ios_dynamic_xcframework.framework/Info.plist",
                "ios-x86_64-simulator/ios_dynamic_xcframework.framework/Headers/ios_dynamic_xcframework.h",
                "ios-x86_64-simulator/ios_dynamic_xcframework.framework/Headers/shared.h",
                "ios-x86_64-simulator/ios_dynamic_xcframework.framework/Modules/module.modulemap",
            ],
        },
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_with_two_top_level_swift_modules_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_swift_xcframework_with_two_top_level_modules",
        expected_error = "Error: Found more than one non-system Swift module in the deps of this XCFramework rule. Check that you are not directly referencing more than one swift_library rule in the deps of the rule.",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_with_invalid_swift_module_deps_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_swift_xcframework_with_invalid_module_deps",
        expected_error = "Error: Found more than one Swift module dependency in this XCFramework's deps: SwiftSecondModuleForFmwk, SwiftFmwkWithInvalidModuleDeps\n\nCheck that you are only referencing ONE Swift module, such as from a a swift_library rule, and that there are no additional Swift modules referenced outside of its private_deps, such as from an additional swift_library dependency.",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_has_no_bundle_id_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework_with_no_bundle_id",
        expected_error = "No bundle ID was given for the target \"ios_dynamic_xcframework_with_no_bundle_id\". Please add one by setting a valid bundle_id on the target.",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_has_invalid_character_bundle_id_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework_with_invalid_character_bundle_id",
        expected_error = "Error in fail: Invalid character(s) in bundle_id: \"my#bundle\"",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_framework_does_not_define_platforms_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework_without_platforms",
        expected_error = """received a minimum OS version for ios, but the platforms to build for that OS were not supplied by a corresponding ios attribute.

Please add a ios attribute to the rule to declare the platforms to build for that OS.""",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_framework_does_not_define_correct_ios_minimum_os_versions_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework_without_correct_minimum_os_versions",
        expected_error = """received a minimum OS version for tvos, but the platforms to build for that OS were not supplied by a corresponding tvos attribute.

Please add a tvos attribute to the rule to declare the platforms to build for that OS.""",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_framework_does_not_define_valid_minimum_os_versions_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework_without_valid_minimum_os_versions",
        expected_error = "received a minimum OS version for xros, but this is not supported by the XCFramework rules.",
        tags = [name],
    )

    # Test that the XCFramework rule correctly avoids framework binary dependencies and resources,
    # across all supported platforms.
    archive_contents_test(
        name = "{}_ios_avoid_frameworks_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:multiplatform_xcframework_with_avoid_frameworks",
        contains = [
            "$BUNDLE_ROOT/ios-arm64/multiplatform_xcframework_with_avoid_frameworks.framework/Info.plist",
            "$BUNDLE_ROOT/ios-arm64/multiplatform_xcframework_with_avoid_frameworks.framework/multiplatform_xcframework_with_avoid_frameworks",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/multiplatform_xcframework_with_avoid_frameworks.framework/Info.plist",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/multiplatform_xcframework_with_avoid_frameworks.framework/multiplatform_xcframework_with_avoid_frameworks",
            "$BUNDLE_ROOT/Info.plist",
        ],
        not_contains = [
            "$BUNDLE_ROOT/ios-arm64/multiplatform_xcframework_with_avoid_frameworks.framework/Another.plist",
            "$BUNDLE_ROOT/ios-arm64/multiplatform_xcframework_with_avoid_frameworks.framework/resource_bundle.bundle/Info.plist",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/multiplatform_xcframework_with_avoid_frameworks.framework/Another.plist",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/multiplatform_xcframework_with_avoid_frameworks.framework/resource_bundle.bundle/Info.plist",
        ],
        binary_test_file = "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/multiplatform_xcframework_with_avoid_frameworks.framework/multiplatform_xcframework_with_avoid_frameworks",
        binary_test_architecture = "arm64",
        binary_contains_symbols = ["_doStuff"],
        binary_not_contains_symbols = ["_frameworkDependent"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_tvos_avoid_frameworks_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:multiplatform_xcframework_with_avoid_frameworks",
        contains = [
            "$BUNDLE_ROOT/tvos-arm64/multiplatform_xcframework_with_avoid_frameworks.framework/Info.plist",
            "$BUNDLE_ROOT/tvos-arm64/multiplatform_xcframework_with_avoid_frameworks.framework/multiplatform_xcframework_with_avoid_frameworks",
            "$BUNDLE_ROOT/tvos-arm64_x86_64-simulator/multiplatform_xcframework_with_avoid_frameworks.framework/Info.plist",
            "$BUNDLE_ROOT/tvos-arm64_x86_64-simulator/multiplatform_xcframework_with_avoid_frameworks.framework/multiplatform_xcframework_with_avoid_frameworks",
            "$BUNDLE_ROOT/Info.plist",
        ],
        not_contains = [
            "$BUNDLE_ROOT/tvos-arm64/multiplatform_xcframework_with_avoid_frameworks.framework/Another.plist",
            "$BUNDLE_ROOT/tvos-arm64/multiplatform_xcframework_with_avoid_frameworks.framework/resource_bundle.bundle/Info.plist",
            "$BUNDLE_ROOT/tvos-arm64_x86_64-simulator/multiplatform_xcframework_with_avoid_frameworks.framework/Another.plist",
            "$BUNDLE_ROOT/tvos-arm64_x86_64-simulator/multiplatform_xcframework_with_avoid_frameworks.framework/resource_bundle.bundle/Info.plist",
        ],
        binary_test_file = "$BUNDLE_ROOT/tvos-arm64_x86_64-simulator/multiplatform_xcframework_with_avoid_frameworks.framework/multiplatform_xcframework_with_avoid_frameworks",
        binary_test_architecture = "arm64",
        binary_contains_symbols = ["_doStuff"],
        binary_not_contains_symbols = ["_frameworkDependent"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_visionos_avoid_frameworks_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:multiplatform_xcframework_with_avoid_frameworks",
        contains = [
            "$BUNDLE_ROOT/xros-arm64/multiplatform_xcframework_with_avoid_frameworks.framework/Info.plist",
            "$BUNDLE_ROOT/xros-arm64/multiplatform_xcframework_with_avoid_frameworks.framework/multiplatform_xcframework_with_avoid_frameworks",
            "$BUNDLE_ROOT/xros-arm64-simulator/multiplatform_xcframework_with_avoid_frameworks.framework/Info.plist",
            "$BUNDLE_ROOT/xros-arm64-simulator/multiplatform_xcframework_with_avoid_frameworks.framework/multiplatform_xcframework_with_avoid_frameworks",
            "$BUNDLE_ROOT/Info.plist",
        ],
        not_contains = [
            "$BUNDLE_ROOT/xros-arm64/multiplatform_xcframework_with_avoid_frameworks.framework/Another.plist",
            "$BUNDLE_ROOT/xros-arm64/multiplatform_xcframework_with_avoid_frameworks.framework/resource_bundle.bundle/Info.plist",
            "$BUNDLE_ROOT/xros-arm64-simulator/multiplatform_xcframework_with_avoid_frameworks.framework/Another.plist",
            "$BUNDLE_ROOT/xros-arm64-simulator/multiplatform_xcframework_with_avoid_frameworks.framework/resource_bundle.bundle/Info.plist",
        ],
        binary_test_file = "$BUNDLE_ROOT/xros-arm64-simulator/multiplatform_xcframework_with_avoid_frameworks.framework/multiplatform_xcframework_with_avoid_frameworks",
        binary_test_architecture = "arm64",
        binary_contains_symbols = ["_doStuff"],
        binary_not_contains_symbols = ["_frameworkDependent"],
        tags = [name],
    )

    # Test for transitive XCFramework dependencies honored by avoid_frameworks, for the linked
    # binaries and resources.
    archive_contents_test(
        name = "{}_ios_transitive_avoid_frameworks_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:upper_multiplatform_xcframework_with_avoid_frameworks",
        contains = [
            "$BUNDLE_ROOT/ios-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/mapping_model.cdm",
            "$BUNDLE_ROOT/ios-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/sample.png",
            "$BUNDLE_ROOT/ios-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/versioned_datamodel.momd/VersionInfo.plist",
            "$BUNDLE_ROOT/ios-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/unversioned_datamodel.mom",
            "$BUNDLE_ROOT/ios-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/nonlocalized.plist",
            "$BUNDLE_ROOT/ios-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/Info.plist",
            "$BUNDLE_ROOT/ios-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/upper_multiplatform_xcframework_with_avoid_frameworks",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/mapping_model.cdm",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/sample.png",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/versioned_datamodel.momd/VersionInfo.plist",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/unversioned_datamodel.mom",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/nonlocalized.plist",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/Info.plist",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/upper_multiplatform_xcframework_with_avoid_frameworks",
            "$BUNDLE_ROOT/Info.plist",
        ],
        not_contains = [
            "$BUNDLE_ROOT/ios-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/Another.plist",
            "$BUNDLE_ROOT/ios-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/resource_bundle.bundle/Info.plist",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/Another.plist",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/resource_bundle.bundle/Info.plist",
        ],
        binary_test_file = "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/upper_multiplatform_xcframework_with_avoid_frameworks",
        binary_test_architecture = "arm64",
        binary_contains_symbols = ["_doUpperStuff"],
        binary_not_contains_symbols = ["_frameworkDependent", "_doStuff"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_tvos_transitive_avoid_frameworks_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:upper_multiplatform_xcframework_with_avoid_frameworks",
        contains = [
            "$BUNDLE_ROOT/tvos-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/mapping_model.cdm",
            "$BUNDLE_ROOT/tvos-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/sample.png",
            "$BUNDLE_ROOT/tvos-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/versioned_datamodel.momd/VersionInfo.plist",
            "$BUNDLE_ROOT/tvos-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/unversioned_datamodel.mom",
            "$BUNDLE_ROOT/tvos-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/nonlocalized.plist",
            "$BUNDLE_ROOT/tvos-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/Info.plist",
            "$BUNDLE_ROOT/tvos-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/upper_multiplatform_xcframework_with_avoid_frameworks",
            "$BUNDLE_ROOT/tvos-arm64_x86_64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/mapping_model.cdm",
            "$BUNDLE_ROOT/tvos-arm64_x86_64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/sample.png",
            "$BUNDLE_ROOT/tvos-arm64_x86_64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/versioned_datamodel.momd/VersionInfo.plist",
            "$BUNDLE_ROOT/tvos-arm64_x86_64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/unversioned_datamodel.mom",
            "$BUNDLE_ROOT/tvos-arm64_x86_64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/nonlocalized.plist",
            "$BUNDLE_ROOT/tvos-arm64_x86_64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/Info.plist",
            "$BUNDLE_ROOT/tvos-arm64_x86_64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/upper_multiplatform_xcframework_with_avoid_frameworks",
            "$BUNDLE_ROOT/Info.plist",
        ],
        not_contains = [
            "$BUNDLE_ROOT/tvos-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/Another.plist",
            "$BUNDLE_ROOT/tvos-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/resource_bundle.bundle/Info.plist",
            "$BUNDLE_ROOT/tvos-arm64_x86_64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/Another.plist",
            "$BUNDLE_ROOT/tvos-arm64_x86_64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/resource_bundle.bundle/Info.plist",
        ],
        binary_test_file = "$BUNDLE_ROOT/tvos-arm64_x86_64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/upper_multiplatform_xcframework_with_avoid_frameworks",
        binary_test_architecture = "arm64",
        binary_contains_symbols = ["_doUpperStuff"],
        binary_not_contains_symbols = ["_frameworkDependent", "_doStuff"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_visionos_transitive_avoid_frameworks_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:upper_multiplatform_xcframework_with_avoid_frameworks",
        contains = [
            "$BUNDLE_ROOT/xros-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/mapping_model.cdm",
            "$BUNDLE_ROOT/xros-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/sample.png",
            "$BUNDLE_ROOT/xros-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/versioned_datamodel.momd/VersionInfo.plist",
            "$BUNDLE_ROOT/xros-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/unversioned_datamodel.mom",
            "$BUNDLE_ROOT/xros-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/nonlocalized.plist",
            "$BUNDLE_ROOT/xros-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/Info.plist",
            "$BUNDLE_ROOT/xros-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/upper_multiplatform_xcframework_with_avoid_frameworks",
            "$BUNDLE_ROOT/xros-arm64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/mapping_model.cdm",
            "$BUNDLE_ROOT/xros-arm64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/sample.png",
            "$BUNDLE_ROOT/xros-arm64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/versioned_datamodel.momd/VersionInfo.plist",
            "$BUNDLE_ROOT/xros-arm64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/unversioned_datamodel.mom",
            "$BUNDLE_ROOT/xros-arm64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/nonlocalized.plist",
            "$BUNDLE_ROOT/xros-arm64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/Info.plist",
            "$BUNDLE_ROOT/xros-arm64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/upper_multiplatform_xcframework_with_avoid_frameworks",
            "$BUNDLE_ROOT/Info.plist",
        ],
        not_contains = [
            "$BUNDLE_ROOT/xros-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/Another.plist",
            "$BUNDLE_ROOT/xros-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/resource_bundle.bundle/Info.plist",
            "$BUNDLE_ROOT/xros-arm64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/Another.plist",
            "$BUNDLE_ROOT/xros-arm64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/resource_bundle.bundle/Info.plist",
        ],
        binary_test_file = "$BUNDLE_ROOT/xros-arm64-simulator/upper_multiplatform_xcframework_with_avoid_frameworks.framework/upper_multiplatform_xcframework_with_avoid_frameworks",
        binary_test_architecture = "arm64",
        binary_contains_symbols = ["_doUpperStuff"],
        binary_not_contains_symbols = ["_frameworkDependent", "_doStuff"],
        tags = [name],
    )

    # Test for missing architectures in "avoid"ed XCFrameworks.
    analysis_failure_message_test(
        name = "{}_has_an_avoided_framework_with_missing_architecture_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_xcframework_with_avoid_frameworks_referencing_insufficient_architectures",
        expected_error = """Trying to build a framework binary with architecture arm64, but the target it depends on at //test/starlark_tests/targets_under_test/apple:reduced_architecture_ios_xcframework_to_avoid only supports these architectures for the target environment "simulator" and OS "ios":

["x86_64"]

Check the rule definition for this dependency to ensure that it supports this given architecture for
the given target environment simulator and OS ios.""",
        tags = [name],
    )

    # Test for missing environments in "avoid"ed XCFrameworks.
    analysis_failure_message_test(
        name = "{}_has_an_avoided_framework_with_missing_environment_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_xcframework_with_avoid_frameworks_referencing_insufficient_environments",
        expected_error = """The referenced XCFrameworks to avoid at //test/starlark_tests/targets_under_test/apple:ios_xcframework_with_avoid_frameworks_referencing_insufficient_environments do not contain a framework for the current target environment "device" and OS "ios".

Check the rule definition for each of the dependencies to ensure that they have the same or a superset of matching target environments ("simulator" or "device") and OSes ("ios", "tvos", etc.).""",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_ios_transitive_avoid_frameworks_generated_modulemap_file_content_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:upper_multiplatform_xcframework_with_avoid_frameworks",
        text_test_file = "$BUNDLE_ROOT/ios-arm64/upper_multiplatform_xcframework_with_avoid_frameworks.framework/Modules/module.modulemap",
        text_test_values = [
            "framework module upper_multiplatform_xcframework_with_avoid_frameworks {",
            "export *",
            "use \"multiplatform_xcframework_to_avoid\"",
            "use \"multiplatform_xcframework_with_avoid_frameworks\"",
            "}",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_ios_transitive_avoid_frameworks_generated_swift_modulemap_file_content_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:upper_ios_swift_xcframework_with_avoid_frameworks",
        text_test_file = "$BUNDLE_ROOT/ios-arm64/SwiftFmwkWithObjcDepsAndGenHeader.framework/Modules/module.modulemap",
        text_test_values = [
            "framework module SwiftFmwkWithObjcDepsAndGenHeader {",
            "header \"SwiftFmwkWithObjcDepsAndGenHeader.h\"",
            "use \"multiplatform_xcframework_to_avoid\"",
            "use \"multiplatform_xcframework_with_avoid_frameworks\"",
            "requires objc",
            "}",
        ],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
