# Copyright 2022 The Bazel Authors. All rights reserved.
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

"""xcarchive Starlark tests."""

load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "archive_contents_test",
)

def xcarchive_test_suite(name):
    """Test suite for xcarchive rule.

    Args:
      name: the base name to be used in things created by this macro
    """

    # Verify xcarchive bundles required files and app for simulator and device.
    archive_contents_test(
        name = "{}_contains_xcarchive_files_simulator".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_minimal.xcarchive",
        contains = [
            "$BUNDLE_ROOT/Info.plist",
            "$BUNDLE_ROOT/Products/Applications/app_minimal.app",
        ],
        plist_test_file = "$BUNDLE_ROOT/Info.plist",
        plist_test_values = {
            "ApplicationProperties:ApplicationPath": "Products/Applications/app_minimal.app",
            "ApplicationProperties:ArchiveVersion": "2",
            "ApplicationProperties:CFBundleIdentifier": "com.google.example",
            "ApplicationProperties:CFBundleShortVersionString": "1.0",
            "ApplicationProperties:CFBundleVersion": "1.0",
            "Name": "app_minimal",
            "SchemeName": "app_minimal",
        },
        tags = [name],
    )
    archive_contents_test(
        name = "{}_contains_xcarchive_files_device".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_minimal.xcarchive",
        contains = [
            "$BUNDLE_ROOT/Info.plist",
            "$BUNDLE_ROOT/Products/Applications/app_minimal.app",
        ],
        plist_test_file = "$BUNDLE_ROOT/Info.plist",
        plist_test_values = {
            "ApplicationProperties:ApplicationPath": "Products/Applications/app_minimal.app",
            "ApplicationProperties:ArchiveVersion": "2",
            "ApplicationProperties:CFBundleIdentifier": "com.google.example",
            "ApplicationProperties:CFBundleShortVersionString": "1.0",
            "ApplicationProperties:CFBundleVersion": "1.0",
            "Name": "app_minimal",
            "SchemeName": "app_minimal",
        },
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
