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

# buildifier: disable=unnamed-macro
def apple_xcframework_test_suite():
    """Test suite for apple_xcframework."""
    name = "apple_xcframework"

    infoplist_contents_test(
        name = "{}_ios_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework",
        expected_values = {
            "AvailableLibraries": "*",
            "CFBundlePackageType": "XFWK",
            "XCFrameworkFormatVersion": "1.0",
        },
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

    native.test_suite(
        name = name,
        tags = [name],
    )
