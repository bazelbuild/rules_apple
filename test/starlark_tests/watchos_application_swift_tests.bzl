# Copyright 2020 The Bazel Authors. All rights reserved.
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

"""Swift-specific `watchos_application` bundling tests."""

load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "archive_contents_test",
)
load(
    "//test/starlark_tests/rules:output_group_zip_contents_test.bzl",
    "output_group_zip_contents_test",
)

visibility("private")

def watchos_application_swift_test_suite(name):
    """Test suite for watchos_application_swift.

    Args:
      name: the base name to be used in things created by this macro
    """

    # Post-ABI stability, Swift should not be bundled at all.
    archive_contents_test(
        name = "{}_device_build_ios_swift_watchos_swift_stable_abi_test".format(name),
        build_type = "device",
        not_contains = [
            "$ARCHIVE_ROOT/SwiftSupport/iphoneos/libswiftCore.dylib",
            "$ARCHIVE_ROOT/SwiftSupport/watchos/libswiftCore.dylib",
            "$BUNDLE_ROOT/Frameworks/libswiftCore.dylib",
            "$BUNDLE_ROOT/Watch/app.app/Frameworks/libswiftCore.dylib",
            "$BUNDLE_ROOT/Watch/app.app/PlugIns/ext.appex/Frameworks/libswiftCore.dylib",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ios_with_swift_watchos_with_swift_stable_abi",
        tags = [name],
    )

    # Check that the combined zip contains the expected essential Payload files and watchOS + Swift
    # support files.
    output_group_zip_contents_test(
        name = "{}_has_combined_zip_output_group".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ios_with_swift_watchos_with_swift",
        output_group_name = "combined_dossier_zip",
        output_group_file_shortpath = "third_party/bazel_rules/rules_apple/test/starlark_tests/targets_under_test/watchos/ios_with_swift_watchos_with_swift_dossier_with_bundle.zip",
        contains = [
            "bundle/Payload/companion.app/Info.plist",
            "bundle/Payload/companion.app/companion",
            "bundle/Payload/companion.app/Watch/app.app/Info.plist",
            "bundle/Payload/companion.app/Watch/app.app/app",
            "bundle/Payload/companion.app/Watch/app.app/PlugIns/ext.appex/Info.plist",
            "bundle/Payload/companion.app/Watch/app.app/PlugIns/ext.appex/ext",
            "bundle/WatchKitSupport2/WK",
            "dossier/manifest.json",
        ],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
