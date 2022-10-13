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
    ":common.bzl",
    "common",
)
load(
    ":rules/analysis_failure_message_test.bzl",
    "analysis_failure_message_test",
)
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
            "MinimumOSVersion": common.min_os_ios.baseline,
            "UIDeviceFamily:0": "1",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/ios:unit_test",
        tags = [name],
    )

    dsyms_test(
        name = "{}_dsyms_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:unit_test",
        expected_direct_dsyms = ["unit_test.xctest"],
        expected_transitive_dsyms = ["unit_test.xctest", "app.app"],
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_test_bundle_id_override".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:unit_test_custom_bundle_id",
        expected_values = {
            "CFBundleIdentifier": "my.test.bundle.id",
        },
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_test_bundle_id_same_as_test_host_error".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:unit_test_invalid_bundle_id",
        expected_error = "The test bundle's identifier of 'com.google.example' can't be the same as the test host's bundle identifier. Please change one of them.",
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
        name = "{}_test_target_bundles_framework_from_objc_library_runtime_deps".format(name),
        build_type = "simulator",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk_min_os_baseline.framework/fmwk_min_os_baseline",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:unit_test_with_fmwk_from_objc_library_runtime_deps",
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

    archive_contents_test(
        name = "{}_builds_without_test_host".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:unit_test_no_host",
        cpus = {
            "ios_multi_cpus": ["x86_64"],
        },
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos 14.0", "platform IOSSIMULATOR"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_builds_with_swift_dep".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:unit_test_with_swift_deps",
        cpus = {
            "ios_multi_cpus": ["x86_64"],
        },
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos 14.0", "platform IOSSIMULATOR"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_bundle_loader_reference_main".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:unit_test_with_bundle_loader",
        binary_test_file = "$BUNDLE_ROOT/unit_test_with_bundle_loader",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_OBJC_CLASS_$_CommonTests"],
        cpus = {
            "ios_multi_cpus": ["x86_64"],
        },
        binary_not_contains_symbols = ["_OBJC_CLASS_$_ObjectiveCCommonClass"],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
