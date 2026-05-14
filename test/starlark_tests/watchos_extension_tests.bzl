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

"""watchos_extension Starlark tests."""

load(
    "//apple/internal:apple_product_type.bzl",  # buildifier: disable=bzl-visibility
    "apple_product_type",
)  # buildifier: disable=bzl-visibility
load(
    "//test/starlark_tests/rules:analysis_output_group_info_files_test.bzl",
    "analysis_output_group_info_files_test",
)
load(
    "//test/starlark_tests/rules:apple_dsym_bundle_info_test.bzl",
    "apple_dsym_bundle_info_test",
)
load(
    "//test/starlark_tests/rules:apple_verification_test.bzl",
    "apple_verification_test",
)
load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "archive_contents_test",
    "entry_point_test",
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
    "//test/starlark_tests/rules:plisttool_error_test.bzl",
    "plisttool_error_test",
)
load(
    "//test/starlark_tests/rules:product_type_test.bzl",
    "product_type_test",
)
load(
    "//test/starlark_tests/rules:provisioning_profile_tool_error_test.bzl",
    "provisioning_profile_tool_error_test",
)
load(
    ":common.bzl",
    "common",
)

_EXTENSION_PLIST_SUBSTITUTIONS = {
    "BUNDLE_NAME": "ext.appex",
    "DEVELOPMENT_LANGUAGE": "en",
    "EXECUTABLE_NAME": "ext",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.google.example.ext",
    "PRODUCT_BUNDLE_PACKAGE_TYPE": "XPC!",
    "PRODUCT_NAME": "ext",
    "TARGET_NAME": "ext",
}

def watchos_extension_test_suite(name):
    """Test suite for watchos_extension.

    Args:
      name: the base name to be used in things created by this macro
    """
    apple_verification_test(
        name = "{}_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_imported_fmwk_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext_with_imported_fmwk",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_entitlements_simulator_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext",
        verifier_script = "verifier_scripts/entitlements_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_entitlements_device_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext",
        verifier_script = "verifier_scripts/entitlements_verifier.sh",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_resources_simulator_test".format(name),
        build_type = "simulator",
        contains = [
            "$RESOURCE_ROOT/resource_bundle.bundle/Info.plist",
            "$RESOURCE_ROOT/Another.plist",
            "$RESOURCE_ROOT/Assets.car",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_strings_simulator_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext",
        contains = [
            "$RESOURCE_ROOT/localization.bundle/en.lproj/files.stringsdict",
            "$RESOURCE_ROOT/localization.bundle/en.lproj/greetings.strings",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_imported_fmwk_simulator_test".format(name),
        build_type = "simulator",
        contains = [
            "$RESOURCE_ROOT/Frameworks/generated_watchos_dynamic_fmwk.framework/generated_watchos_dynamic_fmwk",
            "$RESOURCE_ROOT/Frameworks/generated_watchos_dynamic_fmwk.framework/Info.plist",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext_with_imported_fmwk",
        tags = [name],
    )

    analysis_output_group_info_files_test(
        name = "{}_dsyms_output_group_files_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext",
        output_group_name = "dsyms",
        expected_outputs = [
            "ext.appex.dSYM/Contents/Info.plist",
            "ext.appex.dSYM/Contents/Resources/DWARF/ext",
        ],
        tags = [name],
    )
    apple_dsym_bundle_info_test(
        name = "{}_dsym_bundle_info_files_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext",
        expected_direct_dsyms = ["dSYMs/ext.appex.dSYM"],
        expected_transitive_dsyms = ["dSYMs/ext.appex.dSYM"],
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext",
        expected_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "ext",
            "CFBundleIdentifier": "com.google.example.ext",
            "CFBundleName": "ext",
            "CFBundlePackageType": "XPC!",
            "CFBundleSupportedPlatforms:0": "WatchSimulator*",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "watchsimulator*",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "watchsimulator*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "MinimumOSVersion": common.min_os_watchos.baseline,
            "NSExtension:NSExtensionAttributes:WKAppBundleIdentifier": "com.google.example",
            "NSExtension:NSExtensionPointIdentifier": "com.apple.watchkit",
            "UIDeviceFamily:0": "4",
        },
        tags = [name],
    )

    # Test missing the CFBundleVersion fails the build.
    plisttool_error_test(
        name = "{}_watch_ext_missing_version_fails_test".format(name),
        target_label = "//test/starlark_tests/targets_under_test/watchos:ext_missing_version",
        plists = ["//test/starlark_tests/resources:Info-extension-missing-version.plist"],
        plist_values = {
            "CFBundleIdentifier": "com.google.example.ext",
        },
        expected_error = (
            'Target "//test/starlark_tests/targets_under_test/watchos:ext_missing_version" ' +
            "is missing CFBundleVersion."
        ),
        variable_substitutions = _EXTENSION_PLIST_SUBSTITUTIONS,
        version_keys_required = True,
        tags = [name],
    )

    # Test missing the CFBundleShortVersionString fails the build.
    plisttool_error_test(
        name = "{}_watch_ext_missing_short_version_fails_test".format(name),
        target_label = "//test/starlark_tests/targets_under_test/watchos:ext_missing_short_version",
        plists = ["//test/starlark_tests/resources:Info-extension-missing-short-version.plist"],
        plist_values = {
            "CFBundleIdentifier": "com.google.example.ext",
        },
        expected_error = (
            'Target "//test/starlark_tests/targets_under_test/watchos:ext_missing_short_version" ' +
            "is missing CFBundleShortVersionString."
        ),
        variable_substitutions = _EXTENSION_PLIST_SUBSTITUTIONS,
        version_keys_required = True,
        tags = [name],
    )

    # Tests that failures to extract from a provisioning profile are properly
    # reported from the watchOS extension profile. The fact that multiple things
    # are tried is left as an implementation detail and only the final message
    # is looked for.
    provisioning_profile_tool_error_test(
        name = "{}_provisioning_profile_extraction_failure_test".format(name),
        target_label = "//test/starlark_tests/targets_under_test/watchos:ext_with_bogus_provisioning_profile",
        provisioning_profile = "//test/starlark_tests/resources:bogus.mobileprovision",
        expected_error = 'While processing target "//test/starlark_tests/targets_under_test/watchos:ext_with_bogus_provisioning_profile", failed to extract from the provisioning profile "test/starlark_tests/resources/bogus.mobileprovision".',
        tags = [name, "requires-darwin"],
    )

    infoplist_contents_test(
        name = "{}_multiple_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext_multiple_infoplists",
        expected_values = {
            "AnotherKey": "AnotherValue",
            "CFBundleExecutable": "ext_multiple_infoplists",
        },
        tags = [name],
    )

    # Tests that the linkmap outputs are produced when `--objc_generate_linkmap`
    # is present.
    linkmap_test(
        name = "{}_linkmap_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext",
        tags = [name],
    )
    analysis_output_group_info_files_test(
        name = "{}_linkmaps_output_group_info_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext",
        output_group_name = "linkmaps",
        expected_outputs = [
            "ext_x86_64.linkmap",
            "ext_arm64.linkmap",
        ],
        tags = [name],
    )

    # Tests that the provisioning profile is present when built for device.
    archive_contents_test(
        name = "{}_contains_provisioning_profile_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext",
        contains = [
            "$BUNDLE_ROOT/embedded.mobileprovision",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_correct_rpath_header_value_test".format(name),
        build_type = "device",
        binary_test_file = "$CONTENT_ROOT/ext",
        macho_load_commands_contain = [
            "path @executable_path/Frameworks (offset 12)",
            "path @executable_path/../../Frameworks (offset 12)",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext",
        tags = [name],
    )

    entry_point_test(
        name = "{}_entry_point_test".format(name),
        build_type = "simulator",
        entry_point = "_WKExtensionMain",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext",
        tags = [name],
    )

    entry_point_test(
        name = "{}_entry_point_app_extension_test".format(name),
        build_type = "simulator",
        entry_point = "_NSExtensionMain",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:watchos_app_extension",
        tags = [name],
    )

    product_type_test(
        name = "{}_product_type_watchkit_extension".format(name),
        expected_product_type = apple_product_type.watch2_extension,
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext",
        tags = [name],
    )

    product_type_test(
        name = "{}_product_type_app_extension".format(name),
        expected_product_type = apple_product_type.app_extension,
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:watchos_app_extension",
    )

    infoplist_contents_test(
        name = "{}_capability_set_derived_bundle_id_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext_with_capability_set_derived_bundle_id",
        expected_values = {
            "CFBundleIdentifier": "com.bazel.app.example.watchkitapp.watchkitextension",
        },
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
