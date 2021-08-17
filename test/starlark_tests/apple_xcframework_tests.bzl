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
load(
    ":rules/infoplist_contents_test.bzl",
    "infoplist_contents_test",
)

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
        name = "{}_ios_arm64_archive_contents_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework",
        binary_test_file = "$BUNDLE_ROOT/ios_arm64_device/ios_dynamic_xcframework.framework/ios_dynamic_xcframework",
        macho_load_commands_contain = ["name @rpath/ios_dynamic_xcframework.framework/ios_dynamic_xcframework (offset 24)"],
        contains = [
            "$BUNDLE_ROOT/ios_arm64_device/ios_dynamic_xcframework.framework/Headers/shared.h",
            "$BUNDLE_ROOT/ios_arm64_device/ios_dynamic_xcframework.framework/ios_dynamic_xcframework",
            "$BUNDLE_ROOT/ios_arm64_device/ios_dynamic_xcframework.framework/Info.plist",
            "$BUNDLE_ROOT/Info.plist",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_ios_intel_sim_archive_contents_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework",
        binary_test_file = "$BUNDLE_ROOT/ios_x86_64_simulator/ios_dynamic_xcframework.framework/ios_dynamic_xcframework",
        macho_load_commands_contain = ["name @rpath/ios_dynamic_xcframework.framework/ios_dynamic_xcframework (offset 24)"],
        contains = [
            "$BUNDLE_ROOT/ios_x86_64_simulator/ios_dynamic_xcframework.framework/Headers/shared.h",
            "$BUNDLE_ROOT/ios_x86_64_simulator/ios_dynamic_xcframework.framework/ios_dynamic_xcframework",
            "$BUNDLE_ROOT/ios_x86_64_simulator/ios_dynamic_xcframework.framework/Info.plist",
            "$BUNDLE_ROOT/Info.plist",
        ],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
