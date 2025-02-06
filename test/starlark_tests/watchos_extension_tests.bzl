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
    "//test/starlark_tests/rules:analysis_failure_message_test.bzl",
    "analysis_failure_message_test",
)
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
    ":common.bzl",
    "common",
)

visibility("private")

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
            "$BUNDLE_ROOT/PlugIns/ext_with_imported_fmwk.appex/Frameworks/generated_watchos_dynamic_fmwk.framework/generated_watchos_dynamic_fmwk",
            "$BUNDLE_ROOT/PlugIns/ext_with_imported_fmwk.appex/Frameworks/generated_watchos_dynamic_fmwk.framework/Info.plist",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_with_ext_with_imported_fmwk",
        tags = [name],
    )

    analysis_output_group_info_files_test(
        name = "{}_dsyms_output_group_files_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext",
        output_group_name = "dsyms",
        expected_outputs = [
            "ext.appex.dSYM/Contents/Info.plist",
            "ext.appex.dSYM/Contents/Resources/DWARF/ext_x86_64",
            "ext.appex.dSYM/Contents/Resources/DWARF/ext_arm64",
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

    infoplist_contents_test(
        name = "{}_multiple_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext_multiple_infoplists",
        expected_values = {
            "AnotherKey": "AnotherValue",
            "CFBundleExecutable": "ext_multiple_infoplists",
        },
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_widgetkit_extension_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/custom_extensions:sample_widgetkit_extension",
        expected_values = {
            "NSExtension:NSExtensionPointIdentifier": "com.apple.widgetkit-extension",
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

    infoplist_contents_test(
        name = "{}_capability_set_derived_bundle_id_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext_with_capability_set_derived_bundle_id",
        expected_values = {
            "CFBundleIdentifier": "com.bazel.app.example.watchkitapp.watchkitextension",
        },
        tags = [name],
    )

    entry_point_test(
        name = "{}_entry_point_nsextensionmain_standalone_test".format(name),
        build_type = "simulator",
        entry_point = "_NSExtensionMain",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ext",
        tags = [name],
    )

    entry_point_test(
        name = "{}_entry_point_wkextensionmain_from_watchos2_app_test".format(name),
        binary_test_file = "$BUNDLE_ROOT/PlugIns/ext.appex/ext",
        build_type = "simulator",
        entry_point = "_WKExtensionMain",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app",
        tags = [name],
    )

    entry_point_test(
        name = "{}_entry_point_nsextensionmain_from_single_target_app_test".format(name),
        binary_test_file = "$BUNDLE_ROOT/PlugIns/generic_ext.appex/generic_ext",
        build_type = "simulator",
        entry_point = "_NSExtensionMain",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:single_target_app_with_generic_ext",
        tags = [name],
    )

    # Test that a WidgetKit extension maintains the correct entry point when referenced from a single
    # target watchOS app.
    entry_point_test(
        name = "{}_widgetkit_extension_entry_point_test".format(name),
        binary_test_file = "$BUNDLE_ROOT/PlugIns/sample_widgetkit_extension.appex/sample_widgetkit_extension",
        build_type = "simulator",
        entry_point = "_NSExtensionMain",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/custom_extensions:single_target_app_with_widgetkit_extension",
        tags = [name],
    )

    # Test that a generic extension is bundled in PlugIns and not Extensions.
    archive_contents_test(
        name = "{}_single_target_app_with_generic_extension_bundling_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:single_target_app_with_generic_ext",
        contains = ["$BUNDLE_ROOT/PlugIns/generic_ext.appex/generic_ext"],
        not_contains = ["$BUNDLE_ROOT/Extensions/generic_ext.appex/generic_ext"],
        tags = [name],
    )

    # Test that an ExtensionKit extension is bundled in Extensions and not PlugIns.
    archive_contents_test(
        name = "{}_single_target_app_with_extensionkit_bundling_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:single_target_app_with_extensionkit_ext",
        contains = ["$BUNDLE_ROOT/Extensions/extensionkit_ext.appex/extensionkit_ext"],
        not_contains = ["$BUNDLE_ROOT/PlugIns/extensionkit_ext.appex/extensionkit_ext"],
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_test_watchos2_app_has_generic_extensions_error".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_with_generic_ext",
        expected_error = "Error: Multiple extensions specified for a watchOS 2 extension-based application.",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_test_watchos2_app_extension_is_extensionkit_extension_error".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_with_watchos2_delegate_extensionkit_ext",
        expected_error = "Error: A watchOS 2 app delegate extension was declared as an ExtensionKit extension, which is not possible.",
        tags = [name],
    )

    # Test that an app with a framework-defined App Intents bundle is properly referenced by the
    # extension bundle's Metadata.appintents bundle.
    archive_contents_test(
        name = "{}_metadata_app_intents_packagedata_bundle_contents_has_framework_defined_intents_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:ext_with_framework_app_intents",
        text_test_file = "$BUNDLE_ROOT/Metadata.appintents/extract.packagedata",
        text_test_values = [
            ".*FrameworkDefinedHelloWorldIntents.*",
        ],
        tags = [
            name,
        ],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
