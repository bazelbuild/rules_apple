# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""ios_unit_test Starlark tests."""

load(
    ":rules/apple_verification_test.bzl",
    "apple_verification_test",
)
load(
    ":rules/common_verification_tests.bzl",
    "archive_contents_test",
)
load(
    ":rules/dsyms_test.bzl",
    "dsyms_test",
)
load(
    ":rules/infoplist_contents_test.bzl",
    "infoplist_contents_test",
)

def ios_unit_test_test_suite(name):
    """Test suite for ios_unit_test.

    Args:
      name: the base name to be used in things created by this macro
    """
    apple_verification_test(
        name = "{}_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:unit_test",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_resources_test".format(name),
        build_type = "simulator",
        contains = [
            "$BUNDLE_ROOT/resource_bundle.bundle/Info.plist",
            "$BUNDLE_ROOT/Another.plist",
        ],
        plist_test_file = "$BUNDLE_ROOT/Info.plist",
        plist_test_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "unit_test",
            "CFBundleIdentifier": "com.google.exampleTests",
            "CFBundleName": "unit_test",
            "CFBundlePackageType": "BNDL",
            "CFBundleSupportedPlatforms:0": "iPhone*",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "iphone*",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "iphone*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "MinimumOSVersion": "8.0",
            "UIDeviceFamily:0": "1",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/ios:unit_test",
        tags = [name],
    )

    dsyms_test(
        name = "{}_dsyms_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:unit_test",
        expected_dsyms = ["unit_test.xctest"],
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_multiple_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:unit_test_multiple_infoplists",
        expected_values = {
            "AnotherKey": "AnotherValue",
            "CFBundleExecutable": "unit_test_multiple_infoplists",
        },
        tags = [name],
    )

    archive_contents_test(
        name = "{}_test_target_bundles_framework".format(name),
        build_type = "simulator",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk.framework/fmwk",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:unit_test_with_fmwk",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_test_target_bundles_imported_framework".format(name),
        build_type = "simulator",
        contains = [
            "$BUNDLE_ROOT/Frameworks/iOSDynamicFramework.framework/iOSDynamicFramework",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:unit_test_with_imported_fmwk",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_test_target_does_not_bundle_framework_if_host_does".format(name),
        build_type = "simulator",
        not_contains = [
            "$BUNDLE_ROOT/Frameworks/iOSDynamicFramework.framework/iOSDynamicFramework",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:unit_test_with_host_importing_same_fmwk",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_test_target_does_not_bundle_resources_from_host_or_shared_framework".format(name),
        build_type = "simulator",
        contains = [
            "$BUNDLE_ROOT/nonlocalized.strings",
        ],
        not_contains = [
            "$BUNDLE_ROOT/basic.bundle/basic_bundle.txt",
            "$BUNDLE_ROOT/basic.bundle/nested/should_be_nested.strings",
            "$BUNDLE_ROOT/basic.bundle/should_be_binary.plist",
            "$BUNDLE_ROOT/basic.bundle/should_be_binary.strings",
            "$BUNDLE_ROOT/empty.strings",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:dedupe_test_test",
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
