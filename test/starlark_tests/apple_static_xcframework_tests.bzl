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
            # The array positioning of these plist values will change between runs of the
            # underlying xcodebuild -create-xcframework tool, requiring we do a fuzzy match for two
            # libraries rather than specify which architectures were identified.
            "AvailableLibraries:0:HeadersPath": "Headers",
            "AvailableLibraries:0:LibraryIdentifier": "ios-arm64*",
            "AvailableLibraries:0:LibraryPath": "ios_static_xcframework.apple_static_library_lipo.a",
            "AvailableLibraries:0:SupportedArchitectures": "*",
            "AvailableLibraries:0:SupportedPlatform": "ios",
            "AvailableLibraries:1:HeadersPath": "Headers",
            "AvailableLibraries:1:LibraryIdentifier": "ios-arm64*",
            "AvailableLibraries:1:LibraryPath": "ios_static_xcframework.apple_static_library_lipo.a",
            "AvailableLibraries:1:SupportedArchitectures": "*",
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
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcframework.apple_static_library_lipo.a",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/Headers/shared.h",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcframework.apple_static_library_lipo.a",
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
            "$BUNDLE_ROOT/ios-arm64/ios_static_xcfmwk_with_avoid_deps.apple_static_library_lipo.a",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_avoid_deps.apple_static_library_lipo.a",
            "$BUNDLE_ROOT/Info.plist",
        ],
        not_contains = [
            "$BUNDLE_ROOT/ios-arm64/Headers/DummyFmwk.h",
            "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/Headers/DummyFmwk.h",
        ],
        binary_test_file = "$BUNDLE_ROOT/ios-arm64_x86_64-simulator/ios_static_xcfmwk_with_avoid_deps.apple_static_library_lipo.a",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_doStuff"],
        binary_not_contains_symbols = ["_frameworkDependent"],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
