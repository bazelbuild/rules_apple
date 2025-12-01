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

"""ios_application Starlark tests."""

load(
    "//apple/build_settings:build_settings.bzl",
    "build_settings_labels",
)
load(
    "//test/starlark_tests/rules:analysis_failure_message_test.bzl",
    "analysis_failure_message_test",
    "analysis_failure_message_with_wip_features_test",
    "make_analysis_failure_message_test",
)
load(
    "//test/starlark_tests/rules:analysis_output_group_info_files_test.bzl",
    "analysis_output_group_info_dsymutil_bundle_files_test",
    "analysis_output_group_info_files_test",
)
load(
    "//test/starlark_tests/rules:analysis_target_actions_test.bzl",
    "analysis_target_actions_tree_artifacts_outputs_test",
)
load(
    "//test/starlark_tests/rules:analysis_target_outputs_test.bzl",
    "analysis_target_outputs_test",
    "analysis_target_tree_artifacts_outputs_test",
)
load(
    "//test/starlark_tests/rules:apple_codesigning_dossier_info_provider_test.bzl",
    "apple_codesigning_dossier_info_provider_test",
)
load(
    "//test/starlark_tests/rules:apple_dsym_bundle_info_test.bzl",
    "apple_dsym_bundle_info_dsymutil_bundle_test",
    "apple_dsym_bundle_info_test",
)
load(
    "//test/starlark_tests/rules:apple_verification_test.bzl",
    "apple_verification_test",
)
load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "apple_symbols_file_test",
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
    "//test/starlark_tests/rules:output_group_zip_contents_test.bzl",
    "output_group_zip_contents_test",
)
load(
    ":common.bzl",
    "common",
)

visibility("private")

analysis_failure_message_with_mismatched_universal_architechtures_test = make_analysis_failure_message_test(
    config_settings = {"//command_line_option:ios_multi_cpus": "arm64,x86_64"},
)

def ios_application_test_suite(name):
    """Test suite for ios_application.

    Args:
      name: the base name to be used in things created by this macro
    """

    analysis_failure_message_with_mismatched_universal_architechtures_test(
        name = "{}_fails_when_building_device_and_sim_architectures_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_minimal",
        expected_error = """
ERROR: Attempted to build a universal binary with the following platforms, but their environments \
(device or simulator) are not consistent:

ios_arm64, ios_x86_64

First mismatched environment was simulator from ios_x86_64.

Expected all environments to be device.

All requested architectures must be either device or simulator architectures.""",
        tags = [name],
    )

    analysis_target_outputs_test(
        name = "{}_ipa_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        expected_outputs = ["app.ipa"],
        tags = [name],
    )
    analysis_target_tree_artifacts_outputs_test(
        name = "{}_tree_artifact_outputs_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_minimal",
        expected_outputs = ["app_minimal.app"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_tree_artifact_contents_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_minimal",
        build_settings = {
            build_settings_labels.use_tree_artifacts_outputs: "True",
        },
        contains = [
            "$BUNDLE_ROOT/Info.plist",
            "$BUNDLE_ROOT/PkgInfo",
            "$BUNDLE_ROOT/app_minimal",
        ],
        tags = [name],
    )

    analysis_target_actions_tree_artifacts_outputs_test(
        name = "{}_registers_action_for_tree_artifact_bundling_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_minimal",
        target_mnemonic = "BundleTreeApp",
        not_expected_mnemonic = ["BundleApp"],
        tags = [name],
    )

    apple_verification_test(
        name = "{}_ext_and_fmwk_provisioned_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_ext_and_fmwk_provisioned",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_ext_and_fmwk_provisioned_codesign_asan_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_ext_and_fmwk_provisioned",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        sanitizer = "asan",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_fmwk",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    # Verify that Swift dylibs are no longer packaged with the application for iOS 15+, when the
    # application uses Swift.
    archive_contents_test(
        name = "{}_device_swift_dylibs_not_present".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_app_requiring_support_libs",
        not_contains = [
            "$BUNDLE_ROOT/Frameworks/libswiftCore.dylib",
            "$ARCHIVE_ROOT/SwiftSupport/iphoneos/libswiftCore.dylib",
        ],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_simulator_swift_dylibs_not_present".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_app_requiring_support_libs",
        not_contains = ["$BUNDLE_ROOT/Frameworks/libswiftCore.dylib"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_device_swift_span_compatibility_dylib_present_on_older_os".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_app_using_span_pre_26",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libswiftCompatibilitySpan.dylib",
            "$ARCHIVE_ROOT/SwiftSupport/iphoneos/libswiftCompatibilitySpan.dylib",
        ],
        tags = [
            name,
        ],
    )
    archive_contents_test(
        name = "{}_simulator_swift_span_compatibility_dylib_present_on_older_os".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_app_using_span_pre_26",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libswiftCompatibilitySpan.dylib",
        ],
        tags = [
            name,
        ],
    )

    archive_contents_test(
        name = "{}_device_swift_span_compatibility_dylib_not_present_on_newer_os".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_app_using_span_post_26",
        not_contains = [
            "$BUNDLE_ROOT/Frameworks/libswiftCompatibilitySpan.dylib",
            "$ARCHIVE_ROOT/SwiftSupport/iphoneos/libswiftCompatibilitySpan.dylib",
        ],
        tags = [
            name,
        ],
    )
    archive_contents_test(
        name = "{}_simulator_swift_span_compatibility_dylib_not_present_on_newer_os".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_app_using_span_post_26",
        not_contains = [
            "$BUNDLE_ROOT/Frameworks/libswiftCompatibilitySpan.dylib",
        ],
        tags = [
            name,
        ],
    )

    apple_verification_test(
        name = "{}_imported_fmwk_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_fmwk",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    # Verify ios_application with imported dynamic framework bundles files for Objective-C/Swift
    archive_contents_test(
        name = "{}_with_imported_dynamic_fmwk_bundles_files".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_fmwk",
        contains = [
            "$BUNDLE_ROOT/Frameworks/iOSDynamicFramework.framework/Info.plist",
            "$BUNDLE_ROOT/Frameworks/iOSDynamicFramework.framework/iOSDynamicFramework",
            "$BUNDLE_ROOT/Frameworks/iOSDynamicFramework.framework/Resources/iOSDynamicFramework.bundle/Info.plist",
        ],
        not_contains = [
            "$BUNDLE_ROOT/Frameworks/iOSDynamicFramework.framework/Headers/SharedClass.h",
            "$BUNDLE_ROOT/Frameworks/iOSDynamicFramework.framework/Headers/iOSDynamicFramework.h",
            "$BUNDLE_ROOT/Frameworks/iOSDynamicFramework.framework/Modules/module.modulemap",
        ],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_swift_with_imported_dynamic_fmwk_bundles_files".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_app_with_imported_dynamic_fmwk",
        contains = [
            "$BUNDLE_ROOT/Frameworks/iOSDynamicFramework.framework/Info.plist",
            "$BUNDLE_ROOT/Frameworks/iOSDynamicFramework.framework/iOSDynamicFramework",
        ],
        not_contains = [
            "$BUNDLE_ROOT/Frameworks/libswiftCore.dylib",
            "$BUNDLE_ROOT/Frameworks/iOSDynamicFramework.framework/Headers/SharedClass.h",
            "$BUNDLE_ROOT/Frameworks/iOSDynamicFramework.framework/Headers/iOSDynamicFramework.h",
            "$BUNDLE_ROOT/Frameworks/iOSDynamicFramework.framework/Modules/module.modulemap",
        ],
        tags = [name],
    )

    # Verify ios_application with imported static framework contains symbols for Objective-C/Swift,
    # and resource bundles; but does not bundle the static library.
    archive_contents_test(
        name = "{}_with_imported_static_fmwk_contains_symbols_and_bundles_resources".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_static_fmwk",
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = [
            "-[SharedClass doSomethingShared]",
            "_OBJC_CLASS_$_SharedClass",
        ],
        is_not_binary_plist = ["$BUNDLE_ROOT/iOSStaticFramework.bundle/Info.plist"],
        contains = ["$BUNDLE_ROOT/iOSStaticFramework.bundle/Info.plist"],
        not_contains = ["$BUNDLE_ROOT/Frameworks/iOSStaticFramework.framework"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_with_imported_swift_static_fmwk_contains_symbols_and_not_bundles_files".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_swift_static_fmwk",
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = [
            "_OBJC_CLASS_$__TtC23iOSSwiftStaticFramework11SharedClass",
        ],
        not_contains = ["$BUNDLE_ROOT/Frameworks/iOSSwiftStaticFramework.framework"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_with_imported_swift_static_fmwk_and_no_swift_module_interface_file_contains_symbols_and_not_bundles_files".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_swift_static_fmwk_without_module_interface_files",
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = [
            "_OBJC_CLASS_$__TtC23iOSSwiftStaticFramework11SharedClass",
        ],
        not_contains = [
            "$BUNDLE_ROOT/Frameworks/libswiftCore.dylib",
            "$BUNDLE_ROOT/Frameworks/iOSSwiftStaticFramework.framework",
        ],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_swift_with_imported_static_fmwk_contains_symbols_and_not_bundles_files".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_app_with_imported_static_fmwk",
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = [
            "-[SharedClass doSomethingShared]",
            "_OBJC_CLASS_$_SharedClass",
        ],
        not_contains = [
            "$BUNDLE_ROOT/Frameworks/libswiftCore.dylib",
            "$BUNDLE_ROOT/Frameworks/iOSStaticFramework.framework",
        ],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_swift_with_imported_swift_static_fmwk_contains_symbols_and_not_bundles_files".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_app_with_imported_swift_static_fmwk",
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_OBJC_CLASS_$__TtC23iOSSwiftStaticFramework11SharedClass"],
        not_contains = [
            "$BUNDLE_ROOT/Frameworks/libswiftCore.dylib",
            "$BUNDLE_ROOT/Frameworks/iOSSwiftStaticFramework.framework",
        ],
        tags = [name],
    )

    apple_verification_test(
        name = "{}_fmwk_with_imported_fmwk_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_fmwk_importing_fmwk",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_fmwk_in_fmwk_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_fmwk_with_fmwk",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_fmwk_in_fmwk_provisioned_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_fmwk_with_fmwk_provisioned",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_two_fmwk_provisioned_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_two_fmwk_provisioned",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_entitlements_simulator_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        verifier_script = "verifier_scripts/entitlements_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_entitlements_device_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        verifier_script = "verifier_scripts/entitlements_verifier.sh",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_dbg_resources_simulator_test".format(name),
        build_type = "simulator",
        compilation_mode = "dbg",
        is_binary_plist = ["$BUNDLE_ROOT/resource_bundle.bundle/Info.plist"],
        is_not_binary_plist = ["$BUNDLE_ROOT/Another.plist"],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_opt_resources_simulator_test".format(name),
        build_type = "simulator",
        compilation_mode = "opt",
        is_binary_plist = [
            "$BUNDLE_ROOT/resource_bundle.bundle/Info.plist",
            "$BUNDLE_ROOT/Another.plist",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_dbg_resources_device_test".format(name),
        build_type = "device",
        compilation_mode = "dbg",
        is_binary_plist = ["$BUNDLE_ROOT/resource_bundle.bundle/Info.plist"],
        is_not_binary_plist = ["$BUNDLE_ROOT/Another.plist"],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_opt_resources_device_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        is_binary_plist = [
            "$BUNDLE_ROOT/resource_bundle.bundle/Info.plist",
            "$BUNDLE_ROOT/Another.plist",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_opt_strings_simulator_test".format(name),
        build_type = "simulator",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        contains = [
            "$RESOURCE_ROOT/localization.bundle/en.lproj/files.stringsdict",
            "$RESOURCE_ROOT/localization.bundle/en.lproj/greetings.strings",
        ],
        tags = [name],
    )

    analysis_output_group_info_files_test(
        name = "{}_dsyms_output_group_files_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        output_group_name = "dsyms",
        expected_outputs = [
            "app.app.dSYM/Contents/Info.plist",
            "app.app.dSYM/Contents/Resources/DWARF/app_x86_64",
            "app.app.dSYM/Contents/Resources/DWARF/app_arm64",
        ],
        tags = [name],
    )

    analysis_output_group_info_dsymutil_bundle_files_test(
        name = "{}_dsyms_output_group_dsymutil_bundle_files_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        output_group_name = "dsyms",
        expected_outputs = [
            "app.app.dSYM",
        ],
        tags = [name],
    )

    apple_dsym_bundle_info_test(
        name = "{}_dsym_bundle_info_files_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        expected_direct_dsyms = [
            "dSYMs/app.app.dSYM",
        ],
        expected_transitive_dsyms = [
            "dSYMs/app.app.dSYM",
        ],
        tags = [name],
    )

    apple_dsym_bundle_info_dsymutil_bundle_test(
        name = "{}_dsym_bundle_info_dsymutil_bundle_files_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        expected_direct_dsyms = [
            "app.app.dSYM",
        ],
        expected_transitive_dsyms = [
            "app.app.dSYM",
        ],
        tags = [name],
    )

    analysis_output_group_info_files_test(
        name = "{}_dsyms_output_group_transitive_files_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_ext_and_fmwk_provisioned",
        output_group_name = "dsyms",
        expected_outputs = [
            "app_with_ext_and_fmwk_provisioned.app.dSYM/Contents/Info.plist",
            "app_with_ext_and_fmwk_provisioned.app.dSYM/Contents/Resources/DWARF/app_with_ext_and_fmwk_provisioned_arm64",
            "app_with_ext_and_fmwk_provisioned.app.dSYM/Contents/Resources/DWARF/app_with_ext_and_fmwk_provisioned_x86_64",
            "ext_with_fmwk_provisioned.appex.dSYM/Contents/Info.plist",
            "ext_with_fmwk_provisioned.appex.dSYM/Contents/Resources/DWARF/ext_with_fmwk_provisioned_arm64",
            "ext_with_fmwk_provisioned.appex.dSYM/Contents/Resources/DWARF/ext_with_fmwk_provisioned_x86_64",
            "fmwk_with_provisioning.framework.dSYM/Contents/Info.plist",
            "fmwk_with_provisioning.framework.dSYM/Contents/Resources/DWARF/fmwk_with_provisioning_arm64",
            "fmwk_with_provisioning.framework.dSYM/Contents/Resources/DWARF/fmwk_with_provisioning_x86_64",
        ],
        tags = [name],
    )

    analysis_output_group_info_dsymutil_bundle_files_test(
        name = "{}_dsyms_output_group_dsymutil_bundle_transitive_files_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_ext_and_fmwk_provisioned",
        output_group_name = "dsyms",
        expected_outputs = [
            "app_with_ext_and_fmwk_provisioned.app.dSYM",
            "ext_with_fmwk_provisioned.appex.dSYM",
            "fmwk_with_provisioning.framework.dSYM",
        ],
        tags = [name],
    )

    apple_dsym_bundle_info_test(
        name = "{}_dsymutil_bundle_transitive_dsyms_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_ext_and_fmwk_provisioned",
        expected_direct_dsyms = [
            "dSYMs/app_with_ext_and_fmwk_provisioned.app.dSYM",
        ],
        expected_transitive_dsyms = [
            "dSYMs/fmwk_with_provisioning.framework.dSYM",
            "dSYMs/ext_with_fmwk_provisioned.appex.dSYM",
            "dSYMs/app_with_ext_and_fmwk_provisioned.app.dSYM",
        ],
        tags = [name],
    )

    apple_dsym_bundle_info_dsymutil_bundle_test(
        name = "{}_transitive_dsyms_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_ext_and_fmwk_provisioned",
        expected_direct_dsyms = [
            "app_with_ext_and_fmwk_provisioned.app.dSYM",
        ],
        expected_transitive_dsyms = [
            "fmwk_with_provisioning.framework.dSYM",
            "ext_with_fmwk_provisioned.appex.dSYM",
            "app_with_ext_and_fmwk_provisioned.app.dSYM",
        ],
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        expected_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "app",
            "CFBundleIdentifier": "com.google.example",
            "CFBundleName": "app",
            "CFBundlePackageType": "APPL",
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
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_multiple_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_multiple_infoplists",
        expected_values = {
            "AnotherKey": "AnotherValue",
            "CFBundleExecutable": "app_multiple_infoplists",
        },
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_apple_resource_locales_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:ios_locale_it",
        build_type = "device",
        expected_values = {
            "CFBundleLocalizations": """\"Array {
    it
}\"""",
        },
        tags = [name],
    )

    # Tests that the archive contains .symbols package files when `include_symbols_in_bundle`
    # is enabled.
    apple_symbols_file_test(
        name = "{}_archive_contains_apple_symbols_files_test".format(name),
        binary_paths = [
            "Payload/app_with_ext_and_fmwk_and_symbols_in_bundle.app/app_with_ext_and_fmwk_and_symbols_in_bundle",
            "Payload/app_with_ext_and_fmwk_and_symbols_in_bundle.app/PlugIns/ext_with_fmwk_provisioned.appex/ext_with_fmwk_provisioned",
            "Payload/app_with_ext_and_fmwk_and_symbols_in_bundle.app/Frameworks/fmwk_with_provisioning.framework/fmwk_with_provisioning",
        ],
        build_type = "simulator",
        tags = [name],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_ext_and_fmwk_and_symbols_in_bundle",
    )

    # Tests that the linkmap outputs are produced when `--objc_generate_linkmap`
    # is present.
    linkmap_test(
        name = "{}_linkmap_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        tags = [name],
    )
    analysis_output_group_info_files_test(
        name = "{}_linkmaps_output_group_info_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        output_group_name = "linkmaps",
        expected_outputs = [
            "app_x86_64.linkmap",
            "app_arm64.linkmap",
        ],
        tags = [name],
    )

    # Tests that the provisioning profile is present when built for device.
    archive_contents_test(
        name = "{}_contains_provisioning_profile_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        contains = [
            "$BUNDLE_ROOT/embedded.mobileprovision",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_contains_asan_dylib_simulator_test".format(name),
        build_type = "simulator",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.asan_iossim_dynamic.dylib",
        ],
        sanitizer = "asan",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_minimal",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_contains_asan_dylib_device_test".format(name),
        build_type = "device",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.asan_ios_dynamic.dylib",
        ],
        sanitizer = "asan",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_minimal",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_contains_tsan_dylib_simulator_test".format(name),
        build_type = "simulator",  # There is no thread sanitizer for the device, so only test sim.
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.tsan_iossim_dynamic.dylib",
        ],
        sanitizer = "tsan",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_minimal",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_contains_ubsan_dylib_simulator_test".format(name),
        build_type = "simulator",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.ubsan_iossim_dynamic.dylib",
        ],
        sanitizer = "ubsan",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_minimal",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_contains_ubsan_dylib_device_test".format(name),
        build_type = "device",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.ubsan_ios_dynamic.dylib",
        ],
        sanitizer = "ubsan",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_minimal",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_swift_contains_asan_dylib_simulator_test".format(name),
        build_type = "simulator",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.asan_iossim_dynamic.dylib",
        ],
        sanitizer = "asan",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_app_minimal",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_swift_contains_asan_dylib_device_test".format(name),
        build_type = "device",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.asan_ios_dynamic.dylib",
        ],
        sanitizer = "asan",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_app_minimal",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_swift_contains_tsan_dylib_simulator_test".format(name),
        build_type = "simulator",  # There is no thread sanitizer for the device, so only test sim.
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.tsan_iossim_dynamic.dylib",
        ],
        sanitizer = "tsan",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_app_minimal",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_swift_contains_ubsan_dylib_simulator_test".format(name),
        build_type = "simulator",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.ubsan_iossim_dynamic.dylib",
        ],
        sanitizer = "ubsan",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_app_minimal",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_swift_contains_ubsan_dylib_device_test".format(name),
        build_type = "device",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.ubsan_ios_dynamic.dylib",
        ],
        sanitizer = "ubsan",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_app_minimal",
        tags = [name],
    )

    # Tests analysis phase failure when an extension depends on a framework which
    # is not marked extension_safe.
    analysis_failure_message_test(
        name = "{}_fails_with_extension_depending_on_not_extension_safe_framework".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_ext_with_fmwk_not_extension_safe",
        expected_error = (
            "The target {package}:ext_with_fmwk_not_extension_safe is for an extension but its " +
            "framework dependency {package}:fmwk_not_extension_safe is not marked extension-safe." +
            " Specify 'extension_safe = 1' on the framework target."
        ).format(
            package = "//test/starlark_tests/targets_under_test/ios",
        ),
        tags = [name],
    )

    directory_test(
        name = "{}_dsym_directory_test".format(name),
        apple_generate_dsym = True,
        build_type = "device",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        expected_directories = {
            "app.app.dSYM": [
                "Contents/Resources/DWARF/app_bin",
                "Contents/Info.plist",
            ],
        },
        tags = [name],
    )

    output_group_zip_contents_test(
        name = "{}_has_combined_zip_output_group".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        output_group_name = "combined_dossier_zip",
        output_group_file_shortpath = "third_party/bazel_rules/rules_apple/test/starlark_tests/targets_under_test/ios/app_dossier_with_bundle.zip",
        contains = [
            "bundle/Payload/app.app/Info.plist",
            "bundle/Payload/app.app/app",
            "dossier/manifest.json",
        ],
        tags = [name],
    )

    # Test app with App Intents generates and bundles Metadata.appintents bundle.
    archive_contents_test(
        name = "{}_with_app_intents_contains_app_intents_metadata_bundle_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_app_intents",
        contains = [
            "$BUNDLE_ROOT/Metadata.appintents/extract.actionsdata",
            "$BUNDLE_ROOT/Metadata.appintents/version.json",
        ],
        tags = [name],
    )

    # Test app with repeated references to the same App Intent generates and bundles a single
    # Metadata.appintents bundle.
    archive_contents_test(
        name = "{}_with_repeated_references_to_the_same_app_intent_contains_app_intents_metadata_bundle_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_repeated_references_to_the_same_app_intent",
        contains = [
            "$BUNDLE_ROOT/Metadata.appintents/extract.actionsdata",
            "$BUNDLE_ROOT/Metadata.appintents/version.json",
        ],
        tags = [name],
    )

    # Test app with transitive App Intents generates and bundles Metadata.appintents bundle.
    archive_contents_test(
        name = "{}_with_transitive_app_intents_contains_app_intents_metadata_bundle_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_transitive_app_intents",
        contains = [
            "$BUNDLE_ROOT/Metadata.appintents/extract.actionsdata",
            "$BUNDLE_ROOT/Metadata.appintents/version.json",
        ],
        tags = [name],
    )

    # Test that an app with transitive and direct App Intents fails to build (at present time).
    analysis_failure_message_test(
        name = "{}_too_many_app_intents_failure_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_transitive_and_direct_app_intents",
        expected_error = """
Error: Expected only one swift_library defining App Intents exclusive to the given top level Apple target at //test/starlark_tests/targets_under_test/ios:app_with_transitive_and_direct_app_intents, but found 2 targets defining App Intents instead.

App Intents bundles were defined by the following targets:
- //test/starlark_tests/resources:hinted_app_intent
- //test/starlark_tests/resources:widget_configuration_intent
""",
        tags = [name],
    )

    # Test that an app with multi-module app intents sharing modules with a framework generates a
    # Metadata.appintents bundle.
    archive_contents_test(
        name = "{}_with_multi_module_framework_app_intents_contains_app_intents_metadata_bundle_test".format(name),
        build_settings = {
            build_settings_labels.enable_wip_features: "True",
        },
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_multi_module_framework_app_intents",
        contains = [
            "$BUNDLE_ROOT/Metadata.appintents/extract.actionsdata",
            "$BUNDLE_ROOT/Metadata.appintents/version.json",
        ],
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_no_exclusive_app_intents_failure_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_no_exclusive_framework_app_intents",
        expected_error = """
Error: Expected one swift_library defining App Intents exclusive to the given top level Apple target at //test/starlark_tests/targets_under_test/ios:app_with_no_exclusive_framework_app_intents, but only found 1 targets defining App Intents owned by frameworks.

App Intents bundles were defined by the following framework-referenced targets:
- //test/starlark_tests/resources:framework_defined_app_intent
""",
        tags = [name],
    )

    # Test app with a Widget Configuration Intent with a computed property generates and bundles Metadata.appintents bundle.
    archive_contents_test(
        name = "{}_with_widget_configuration_intent_contains_app_intents_metadata_bundle_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_widget_configuration_intent",
        contains = [
            "$BUNDLE_ROOT/Metadata.appintents/extract.actionsdata",
            "$BUNDLE_ROOT/Metadata.appintents/version.json",
        ],
        tags = [name],
    )

    # Test app with App Intents generates and bundles Metadata.appintents bundle for universal binaries.
    archive_contents_test(
        name = "{}_universal_build_contains_app_intents_metadata_bundle_test".format(name),
        build_type = "simulator",
        cpus = {
            "ios_multi_cpus": ["x86_64", "sim_arm64"],
        },
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_app_intents",
        contains = [
            "$BUNDLE_ROOT/Metadata.appintents/extract.actionsdata",
            "$BUNDLE_ROOT/Metadata.appintents/version.json",
        ],
        tags = [name],
    )

    # Test Metadata.appintents bundle contents for simulator and device.
    archive_contents_test(
        name = "{}_metadata_appintents_bundle_contents_for_simulator_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_app_intents",
        text_test_file = "$BUNDLE_ROOT/Metadata.appintents/extract.actionsdata",
        text_test_values = [
            ".*HelloWorldIntent.*",
            ".*IntelIntent.*",
            ".*iOSIntent.*",
        ],
        text_file_not_contains = [
            ".*ArmIntent.*",
            ".*macOSIntent.*",
            ".*tvOSIntent.*",
            ".*watchOSIntent.*",
        ],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_metadata_appintents_bundle_contents_for_device_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_app_intents",
        text_test_file = "$BUNDLE_ROOT/Metadata.appintents/extract.actionsdata",
        text_test_values = [
            ".*HelloWorldIntent.*",
            ".*ArmIntent.*",
            ".*iOSIntent.*",
        ],
        text_file_not_contains = [
            ".*IntelIntent.*",
            ".*macOSIntent.*",
            ".*tvOSIntent.*",
            ".*watchOSIntent.*",
        ],
        tags = [name],
    )

    # Test dSYM binaries and linkmaps from framework embedded via 'data' are propagated correctly
    # at the top-level ios_application rule, and present through the 'dsysms' and 'linkmaps' output
    # groups.
    analysis_output_group_info_files_test(
        name = "{}_with_runtime_framework_transitive_dsyms_output_group_info_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_fmwks_from_frameworks_and_objc_swift_libraries_using_data",
        output_group_name = "dsyms",
        expected_outputs = [
            "app_with_fmwks_from_frameworks_and_objc_swift_libraries_using_data.app.dSYM/Contents/Info.plist",
            "app_with_fmwks_from_frameworks_and_objc_swift_libraries_using_data.app.dSYM/Contents/Resources/DWARF/app_with_fmwks_from_frameworks_and_objc_swift_libraries_using_data_arm64",
            "app_with_fmwks_from_frameworks_and_objc_swift_libraries_using_data.app.dSYM/Contents/Resources/DWARF/app_with_fmwks_from_frameworks_and_objc_swift_libraries_using_data_x86_64",
            # Frameworks
            "fmwk.framework.dSYM/Contents/Info.plist",
            "fmwk.framework.dSYM/Contents/Resources/DWARF/fmwk_arm64",
            "fmwk.framework.dSYM/Contents/Resources/DWARF/fmwk_x86_64",
            "fmwk_min_os_baseline_with_bundle.framework.dSYM/Contents/Info.plist",
            "fmwk_min_os_baseline_with_bundle.framework.dSYM/Contents/Resources/DWARF/fmwk_min_os_baseline_with_bundle_arm64",
            "fmwk_min_os_baseline_with_bundle.framework.dSYM/Contents/Resources/DWARF/fmwk_min_os_baseline_with_bundle_x86_64",
            "fmwk_no_version.framework.dSYM/Contents/Info.plist",
            "fmwk_no_version.framework.dSYM/Contents/Resources/DWARF/fmwk_no_version_arm64",
            "fmwk_no_version.framework.dSYM/Contents/Resources/DWARF/fmwk_no_version_x86_64",
            "fmwk_with_resources.framework.dSYM/Contents/Info.plist",
            "fmwk_with_resources.framework.dSYM/Contents/Resources/DWARF/fmwk_with_resources_arm64",
            "fmwk_with_resources.framework.dSYM/Contents/Resources/DWARF/fmwk_with_resources_x86_64",
        ],
        tags = [name],
    )

    analysis_output_group_info_dsymutil_bundle_files_test(
        name = "{}_with_runtime_framework_transitive_dsyms_output_group_info_dsymutil_bundle_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_fmwks_from_frameworks_and_objc_swift_libraries_using_data",
        output_group_name = "dsyms",
        expected_outputs = [
            "app_with_fmwks_from_frameworks_and_objc_swift_libraries_using_data.app.dSYM",
            # Frameworks
            "fmwk.framework.dSYM",
            "fmwk_min_os_baseline_with_bundle.framework.dSYM",
            "fmwk_no_version.framework.dSYM",
            "fmwk_with_resources.framework.dSYM",
        ],
        tags = [name],
    )

    analysis_output_group_info_files_test(
        name = "{}_with_runtime_framework_transitive_linkmaps_output_group_info_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_fmwks_from_frameworks_and_objc_swift_libraries_using_data",
        output_group_name = "linkmaps",
        expected_outputs = [
            "app_with_fmwks_from_frameworks_and_objc_swift_libraries_using_data_arm64.linkmap",
            "app_with_fmwks_from_frameworks_and_objc_swift_libraries_using_data_x86_64.linkmap",
            "fmwk_arm64.linkmap",
            "fmwk_x86_64.linkmap",
            "fmwk_min_os_baseline_with_bundle_arm64.linkmap",
            "fmwk_min_os_baseline_with_bundle_x86_64.linkmap",
            "fmwk_no_version_arm64.linkmap",
            "fmwk_no_version_x86_64.linkmap",
            "fmwk_with_resources_arm64.linkmap",
            "fmwk_with_resources_x86_64.linkmap",
        ],
        tags = [name],
    )

    # Test transitive frameworks dSYM bundles are propagated by the AppleDsymBundleInfo provider.
    apple_dsym_bundle_info_test(
        name = "{}_with_runtime_framework_dsym_bundle_info_files_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_fmwks_from_frameworks_and_objc_swift_libraries_using_data",
        expected_direct_dsyms = [
            "dSYMs/app_with_fmwks_from_frameworks_and_objc_swift_libraries_using_data.app.dSYM",
        ],
        expected_transitive_dsyms = [
            "dSYMs/app_with_fmwks_from_frameworks_and_objc_swift_libraries_using_data.app.dSYM",
            "dSYMs/fmwk.framework.dSYM",
            "dSYMs/fmwk_min_os_baseline_with_bundle.framework.dSYM",
            "dSYMs/fmwk_no_version.framework.dSYM",
            "dSYMs/fmwk_with_resources.framework.dSYM",
        ],
        tags = [name],
    )

    apple_dsym_bundle_info_dsymutil_bundle_test(
        name = "{}_with_runtime_framework_dsym_bundle_info_files_dsymutil_bundle_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_fmwks_from_frameworks_and_objc_swift_libraries_using_data",
        expected_direct_dsyms = [
            "app_with_fmwks_from_frameworks_and_objc_swift_libraries_using_data.app.dSYM",
        ],
        expected_transitive_dsyms = [
            "app_with_fmwks_from_frameworks_and_objc_swift_libraries_using_data.app.dSYM",
            "fmwk.framework.dSYM",
            "fmwk_min_os_baseline_with_bundle.framework.dSYM",
            "fmwk_no_version.framework.dSYM",
            "fmwk_with_resources.framework.dSYM",
        ],
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_no_bundle_id_fail_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_no_bundle_id",
        expected_error = """
Error: There are no attributes set on this target that can be used to determine a bundle ID.

Need a `bundle_id` or a reference to an `apple_base_bundle_id` target coming from the rule or (when
applicable) exactly one of the `apple_capability_set` targets found within `shared_capabilities`.
""",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_empty_bundle_id_fail_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_empty_bundle_id",
        expected_error = """
Error: There are no attributes set on this target that can be used to determine a bundle ID.

Need a `bundle_id` or a reference to an `apple_base_bundle_id` target coming from the rule or (when
applicable) exactly one of the `apple_capability_set` targets found within `shared_capabilities`.
""",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_just_dot_bundle_id_fail_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_just_dot_bundle_id",
        expected_error = "Empty segment in bundle_id: \".\"",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_leading_dot_bundle_id_fail_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_leading_dot_bundle_id",
        expected_error = "Empty segment in bundle_id: \".my.bundle.id\"",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_trailing_dot_bundle_id_fail_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_trailing_dot_bundle_id",
        expected_error = "Empty segment in bundle_id: \"my.bundle.id.\"",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_double_dot_bundle_id_fail_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_double_dot_bundle_id",
        expected_error = "Empty segment in bundle_id: \"my..bundle.id\"",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_invalid_character_bundle_id_fail_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_invalid_character_bundle_id",
        expected_error = "Invalid character(s) in bundle_id: \"my#bundle\"",
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_capability_set_derived_bundle_id_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_capability_set_derived_bundle_id",
        expected_values = {
            "CFBundleIdentifier": "com.bazel.app.example",
        },
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_custom_bundle_id_derived_bundle_id_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_custom_bundle_id_suffix_derived_bundle_id",
        expected_values = {
            "CFBundleIdentifier": "com.bazel.app.example.bundle-id-suffix",
        },
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_ambiguous_shared_capabilities_bundle_id_fail_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_ambiguous_shared_capabilities_bundle_id",
        expected_error = """
Error: Found a `bundle_id` on the rule along with `shared_capabilities` defining a `base_bundle_id`.

This is ambiguous. Please remove the `bundle_id` from your rule definition, or reference
`shared_capabilities` without a `base_bundle_id`.
""",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_absent_shared_capabilities_bundle_id_fail_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_absent_shared_capabilities_bundle_id",
        expected_error = """
Error: Expected to find a base_bundle_id from exactly one of the assigned shared_capabilities.
Found none.
""",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_conflicting_shared_capabilities_bundle_id_fail_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_conflicting_shared_capabilities_bundle_id",
        expected_error = """
Error: Received conflicting base bundle IDs from more than one assigned Apple shared capability.

Found "com.bazel.app.example" which does not match previously defined "com.altbazel.app.example".
""",
        tags = [name],
    )

    apple_codesigning_dossier_info_provider_test(
        name = "{}_codesigning_dossier_info_provider_test".format(name),
        expected_dossier = "app_dossier.zip",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        tags = [name],
    )

    # Test that an app with a framework-defined App Intents bundle is properly referenced by the app
    # bundle's Metadata.appintents bundle.
    archive_contents_test(
        name = "{}_metadata_app_intents_packagedata_bundle_contents_has_framework_defined_intents_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_framework_app_intents",
        text_test_file = "$BUNDLE_ROOT/Metadata.appintents/extract.packagedata",
        text_test_values = [
            ".*FrameworkDefinedHelloWorldIntents.*",
        ],
        tags = [
            name,
        ],
    )

    # Test that an app with a framework-defined App Intents bundle is properly referenced by the app
    # bundle's Metadata.appintents bundle even when there is an extension that also references the
    # same framework-defined App Intents bundle.
    archive_contents_test(
        name = "{}_metadata_app_intents_packagedata_bundle_contents_has_extension_and_framework_defined_intents_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_ext_and_framework_app_intents",
        text_test_file = "$BUNDLE_ROOT/Metadata.appintents/extract.packagedata",
        text_test_values = [
            ".*FrameworkDefinedHelloWorldIntents.*",
        ],
        tags = [
            name,
        ],
    )

    archive_contents_test(
        name = "{}_with_spaces_contents_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app minimal has several spaces",
        contains = [
            "$BUNDLE_ROOT/Info.plist",
            "$BUNDLE_ROOT/PkgInfo",
            "$BUNDLE_ROOT/app minimal has several spaces",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_tree_artifact_with_spaces_contents_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app minimal has several spaces",
        build_settings = {
            build_settings_labels.use_tree_artifacts_outputs: "True",
        },
        contains = [
            "$BUNDLE_ROOT/Info.plist",
            "$BUNDLE_ROOT/PkgInfo",
            "$BUNDLE_ROOT/app minimal has several spaces",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_bundle_name_with_spaces_contents_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_minimal_bundle_name_with_spaces",
        contains = [
            "$BUNDLE_ROOT/Info.plist",
            "$BUNDLE_ROOT/PkgInfo",
            "$BUNDLE_ROOT/app minimal bundle name has several spaces",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_tree_artifact_bundle_name_with_spaces_contents_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_minimal_bundle_name_with_spaces",
        build_settings = {
            build_settings_labels.use_tree_artifacts_outputs: "True",
        },
        contains = [
            "$BUNDLE_ROOT/Info.plist",
            "$BUNDLE_ROOT/PkgInfo",
            "$BUNDLE_ROOT/app minimal bundle name has several spaces",
        ],
        tags = [name],
    )

    # Tests that the required Xcode 26 entitlements are added when enhanced security features are
    # assigned to a target.
    apple_verification_test(
        name = "{}_enhanced_security_features_entitlements_device_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_enhanced_security_app",
        verifier_script = "verifier_scripts/entitlements_key_verifier.sh",
        env = {
            "ENTITLEMENTS_KEY": ["com.apple.security.hardened-process"],
        },
        tags = [
            name,
            # TODO: b/449684779 - Remove this tag once Xcode 26+ is the default Xcode.
        ],
    )
    apple_verification_test(
        name = "{}_enhanced_security_features_xcode_26_entitlements_device_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_enhanced_security_app",
        verifier_script = "verifier_scripts/entitlements_key_verifier.sh",
        env = {
            "ENTITLEMENTS_KEY": ["com.apple.security.hardened-process.enhanced-security-version"],
        },
        tags = [
            name,
            # TODO: b/449684779 - Remove this tag once Xcode 26+ is the default Xcode.
        ],
    )

    archive_contents_test(
        name = "{}_pointer_authentication_arm64e_device_archs_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_with_fmwk_and_standard_extension",
        cpus = {
            "ios_multi_cpus": ["arm64", "arm64e"],
            "watchos_cpus": [],
        },
        binary_test_file = "$BINARY",
        binary_test_architecture = "arm64e",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform IOS"],
        tags = [name],
    )
    apple_verification_test(
        name = "{}_pointer_authentication_entitlements_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_with_fmwk_and_standard_extension",
        verifier_script = "verifier_scripts/entitlements_key_verifier.sh",
        env = {
            "ENTITLEMENTS_KEY": ["com.apple.security.pointer-authentication"],
        },
        tags = [
            name,
            # TODO: b/449684779 - Remove this tag once Xcode 26+ is the default Xcode.
        ],
    )
    apple_verification_test(
        name = "{}_pointer_authentication_xcode_26_entitlements_device_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_with_fmwk_and_standard_extension",
        verifier_script = "verifier_scripts/entitlements_key_verifier.sh",
        env = {
            "ENTITLEMENTS_KEY": ["com.apple.security.hardened-process.enhanced-security-version"],
        },
        tags = [
            name,
            # TODO: b/449684779 - Remove this tag once Xcode 26+ is the default Xcode.
        ],
    )

    archive_contents_test(
        name = "{}_pointer_authentication_arm64_device_archs_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_with_fmwk_and_standard_extension",
        cpus = {
            "ios_multi_cpus": ["arm64", "arm64e"],
            "watchos_cpus": [],
        },
        binary_test_file = "$BINARY",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform IOS"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_no_pointer_authentication_arm64_device_archs_extension_with_pointer_authentication_arm64e_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_with_fmwk_and_standard_extension",
        cpus = {
            "ios_multi_cpus": ["arm64", "arm64e"],
            "watchos_cpus": [],
        },
        binary_test_file = "$BUNDLE_ROOT/PlugIns/ext.appex/ext",
        binary_test_architecture = "arm64",
        binary_not_contains_architectures = ["arm64e"],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform IOS"],
        tags = [name],
    )
    apple_verification_test(
        name = "{}_no_pointer_authentication_entitlements_extension_with_pointer_authentication_arm64e_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_with_fmwk_and_standard_extension",
        verifier_script = "verifier_scripts/entitlements_key_verifier.sh",
        env = {
            "BUNDLE_TEST_ROOT": ["$BUNDLE_ROOT/PlugIns/ext.appex/"],
            "CHECK_FOR_ABSENT_ENTITLEMENTS": ["True"],
            "ENTITLEMENTS_KEY": ["com.apple.security.pointer-authentication"],
        },
        tags = [
            name,
            # TODO: b/449684779 - Remove this tag once Xcode 26+ is the default Xcode.
        ],
    )
    apple_verification_test(
        name = "{}_no_xcode_26_entitlements_extension_with_pointer_authentication_arm64e_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_with_fmwk_and_standard_extension",
        verifier_script = "verifier_scripts/entitlements_key_verifier.sh",
        env = {
            "BUNDLE_TEST_ROOT": ["$BUNDLE_ROOT/PlugIns/ext.appex/"],
            "CHECK_FOR_ABSENT_ENTITLEMENTS": ["True"],
            "ENTITLEMENTS_KEY": ["com.apple.security.hardened-process.enhanced-security-version"],
        },
        tags = [
            name,
            # TODO: b/449684779 - Remove this tag once Xcode 26+ is the default Xcode.
        ],
    )

    archive_contents_test(
        name = "{}_pointer_authentication_arm64e_device_archs_extension_with_pointer_authentication_arm64e_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_and_extension_with_fmwk",
        cpus = {
            "ios_multi_cpus": ["arm64", "arm64e"],
            "watchos_cpus": [],
        },
        binary_test_file = "$BUNDLE_ROOT/PlugIns/simple_pointer_authentication_extension.appex/simple_pointer_authentication_extension",
        binary_test_architecture = "arm64e",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform IOS"],
        tags = [name],
    )
    apple_verification_test(
        name = "{}_pointer_authentication_entitlements_extension_with_pointer_authentication_arm64e_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_and_extension_with_fmwk",
        verifier_script = "verifier_scripts/entitlements_key_verifier.sh",
        env = {
            "BUNDLE_TEST_ROOT": ["$BUNDLE_ROOT/PlugIns/simple_pointer_authentication_extension.appex/"],
            "ENTITLEMENTS_KEY": ["com.apple.security.pointer-authentication"],
        },
        tags = [
            name,
            # TODO: b/449684779 - Remove this tag once Xcode 26+ is the default Xcode.
        ],
    )
    apple_verification_test(
        name = "{}_xcode_26_entitlements_extension_with_pointer_authentication_arm64e_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_and_extension_with_fmwk",
        verifier_script = "verifier_scripts/entitlements_key_verifier.sh",
        env = {
            "BUNDLE_TEST_ROOT": ["$BUNDLE_ROOT/PlugIns/simple_pointer_authentication_extension.appex/"],
            "ENTITLEMENTS_KEY": ["com.apple.security.hardened-process.enhanced-security-version"],
        },
        tags = [
            name,
            # TODO: b/449684779 - Remove this tag once Xcode 26+ is the default Xcode.
        ],
    )

    archive_contents_test(
        name = "{}_pointer_authentication_arm64_device_archs_extension_with_pointer_authentication_arm64e_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_and_extension_with_fmwk",
        cpus = {
            "ios_multi_cpus": ["arm64", "arm64e"],
            "watchos_cpus": [],
        },
        binary_test_file = "$BUNDLE_ROOT/PlugIns/simple_pointer_authentication_extension.appex/simple_pointer_authentication_extension",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform IOS"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_pointer_authentication_arm64e_framework_in_app_and_extension_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_with_fmwk_and_standard_extension",
        cpus = {
            "ios_multi_cpus": ["arm64", "arm64e"],
            "watchos_cpus": [],
        },
        binary_test_file = "$BUNDLE_ROOT/Frameworks/fmwk_min_os_baseline.framework/fmwk_min_os_baseline",
        binary_test_architecture = "arm64e",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform IOS"],
        tags = [name],
    )
    apple_verification_test(
        name = "{}_pointer_authentication_entitlements_framework_with_pointer_authentication_arm64e_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_with_fmwk_and_standard_extension",
        verifier_script = "verifier_scripts/entitlements_key_verifier.sh",
        env = {
            "BUNDLE_TEST_ROOT": ["$BUNDLE_ROOT/Frameworks/fmwk_min_os_baseline.framework/"],
            "ENTITLEMENTS_KEY": ["com.apple.security.pointer-authentication"],
        },
        tags = [
            name,
            # TODO: b/449684779 - Remove this tag once Xcode 26+ is the default Xcode.
        ],
    )
    apple_verification_test(
        name = "{}_xcode_26_entitlements_framework_with_pointer_authentication_arm64e_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_with_fmwk_and_standard_extension",
        verifier_script = "verifier_scripts/entitlements_key_verifier.sh",
        env = {
            "BUNDLE_TEST_ROOT": ["$BUNDLE_ROOT/Frameworks/fmwk_min_os_baseline.framework/"],
            "ENTITLEMENTS_KEY": ["com.apple.security.hardened-process.enhanced-security-version"],
        },
        tags = [
            name,
            # TODO: b/449684779 - Remove this tag once Xcode 26+ is the default Xcode.
        ],
    )

    archive_contents_test(
        name = "{}_pointer_authentication_arm64_framework_in_app_and_extension_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_with_fmwk_and_standard_extension",
        cpus = {
            "ios_multi_cpus": ["arm64", "arm64e"],
            "watchos_cpus": [],
        },
        binary_test_file = "$BUNDLE_ROOT/Frameworks/fmwk_min_os_baseline.framework/fmwk_min_os_baseline",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform IOS"],
        tags = [name],
    )

    analysis_failure_message_with_wip_features_test(
        name = "{}_secure_features_disabled_at_rule_level_should_fail_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_enhanced_security_app_with_rule_level_disabled_features",
        expected_error = "Attempted to enable the secure feature `trivial_auto_var_init` for the target at `//test/starlark_tests/targets_under_test/ios:simple_enhanced_security_app_with_rule_level_disabled_features`",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_no_pointer_authentication_arm64_device_archs_app_clip_with_pointer_authentication_arm64e_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_with_app_clip",
        cpus = {
            "ios_multi_cpus": ["arm64", "arm64e"],
            "watchos_cpus": [],
        },
        binary_test_file = "$BUNDLE_ROOT/AppClips/app_clip.app/app_clip",
        binary_test_architecture = "arm64",
        binary_not_contains_architectures = ["arm64e"],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform IOS"],
        tags = [name],
    )
    apple_verification_test(
        name = "{}_no_pointer_authentication_entitlements_app_clip_with_pointer_authentication_arm64e_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_with_app_clip",
        verifier_script = "verifier_scripts/entitlements_key_verifier.sh",
        env = {
            "BUNDLE_TEST_ROOT": ["$BUNDLE_ROOT/AppClips/app_clip.app/"],
            "CHECK_FOR_ABSENT_ENTITLEMENTS": ["True"],
            "ENTITLEMENTS_KEY": ["com.apple.security.pointer-authentication"],
        },
        tags = [
            name,
            # TODO: b/449684779 - Remove this tag once Xcode 26+ is the default Xcode.
        ],
    )
    apple_verification_test(
        name = "{}_no_xcode_26_entitlements_app_clip_with_pointer_authentication_arm64e_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_with_app_clip",
        verifier_script = "verifier_scripts/entitlements_key_verifier.sh",
        env = {
            "BUNDLE_TEST_ROOT": ["$BUNDLE_ROOT/AppClips/app_clip.app/"],
            "CHECK_FOR_ABSENT_ENTITLEMENTS": ["True"],
            "ENTITLEMENTS_KEY": ["com.apple.security.hardened-process.enhanced-security-version"],
        },
        tags = [
            name,
            # TODO: b/449684779 - Remove this tag once Xcode 26+ is the default Xcode.
        ],
    )

    archive_contents_test(
        name = "{}_pointer_authentication_arm64e_device_archs_app_clip_with_pointer_authentication_arm64e_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_with_app_clip_with_pointer_authentication",
        cpus = {
            "ios_multi_cpus": ["arm64", "arm64e"],
            "watchos_cpus": [],
        },
        binary_test_file = "$BUNDLE_ROOT/AppClips/app_clip_with_pointer_authentication.app/app_clip_with_pointer_authentication",
        binary_test_architecture = "arm64e",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform IOS"],
        tags = [name],
    )
    apple_verification_test(
        name = "{}_pointer_authentication_entitlements_app_clip_with_pointer_authentication_arm64e_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_with_app_clip_with_pointer_authentication",
        verifier_script = "verifier_scripts/entitlements_key_verifier.sh",
        env = {
            "BUNDLE_TEST_ROOT": ["$BUNDLE_ROOT/AppClips/app_clip_with_pointer_authentication.app/"],
            "ENTITLEMENTS_KEY": ["com.apple.security.pointer-authentication"],
        },
        tags = [
            name,
            # TODO: b/449684779 - Remove this tag once Xcode 26+ is the default Xcode.
        ],
    )
    apple_verification_test(
        name = "{}_xcode_26_entitlements_app_clip_with_pointer_authentication_arm64e_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_with_app_clip_with_pointer_authentication",
        verifier_script = "verifier_scripts/entitlements_key_verifier.sh",
        env = {
            "BUNDLE_TEST_ROOT": ["$BUNDLE_ROOT/AppClips/app_clip_with_pointer_authentication.app/"],
            "ENTITLEMENTS_KEY": ["com.apple.security.hardened-process.enhanced-security-version"],
        },
        tags = [
            name,
            # TODO: b/449684779 - Remove this tag once Xcode 26+ is the default Xcode.
        ],
    )

    archive_contents_test(
        name = "{}_no_pointer_authentication_arm64_device_archs_watch_app_with_pointer_authentication_arm64e_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_with_watchos_app",
        cpus = {
            "ios_multi_cpus": ["arm64", "arm64e"],
            "watchos_cpus": ["device_arm64", "device_arm64e"],
        },
        binary_test_file = "$BUNDLE_ROOT/Watch/single_target_app_with_generic_ext.app/single_target_app_with_generic_ext",
        binary_test_architecture = "arm64",
        binary_not_contains_architectures = ["arm64e"],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform WATCHOS"],
        tags = [name],
    )
    apple_verification_test(
        name = "{}_no_pointer_authentication_entitlements_watch_app_with_pointer_authentication_arm64e_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_with_watchos_app",
        verifier_script = "verifier_scripts/entitlements_key_verifier.sh",
        env = {
            "BUNDLE_TEST_ROOT": ["$BUNDLE_ROOT/Watch/single_target_app_with_generic_ext.app/"],
            "CHECK_FOR_ABSENT_ENTITLEMENTS": ["True"],
            "ENTITLEMENTS_KEY": ["com.apple.security.pointer-authentication"],
        },
        tags = [
            name,
            # TODO: b/449684779 - Remove this tag once Xcode 26+ is the default Xcode.
        ],
    )
    apple_verification_test(
        name = "{}_no_xcode_26_entitlements_watch_app_with_pointer_authentication_arm64e_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_with_watchos_app",
        verifier_script = "verifier_scripts/entitlements_key_verifier.sh",
        env = {
            "BUNDLE_TEST_ROOT": ["$BUNDLE_ROOT/Watch/single_target_app_with_generic_ext.app/"],
            "CHECK_FOR_ABSENT_ENTITLEMENTS": ["True"],
            "ENTITLEMENTS_KEY": ["com.apple.security.hardened-process.enhanced-security-version"],
        },
        tags = [
            name,
            # TODO: b/449684779 - Remove this tag once Xcode 26+ is the default Xcode.
        ],
    )

    archive_contents_test(
        name = "{}_pointer_authentication_arm64e_device_archs_watch_app_with_pointer_authentication_arm64e_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_with_pointer_authentication_watchos_app",
        cpus = {
            "ios_multi_cpus": ["arm64", "arm64e"],
            "watchos_cpus": ["device_arm64", "device_arm64e"],
        },
        binary_test_file = "$BUNDLE_ROOT/Watch/simple_pointer_authentication_app.app/simple_pointer_authentication_app",
        binary_test_architecture = "arm64e",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform WATCHOS"],
        tags = [name],
    )
    apple_verification_test(
        name = "{}_pointer_authentication_entitlements_watch_app_with_pointer_authentication_arm64e_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_with_pointer_authentication_watchos_app",
        verifier_script = "verifier_scripts/entitlements_key_verifier.sh",
        env = {
            "BUNDLE_TEST_ROOT": ["$BUNDLE_ROOT/Watch/simple_pointer_authentication_app.app/"],
            "ENTITLEMENTS_KEY": ["com.apple.security.pointer-authentication"],
        },
        tags = [
            name,
            # TODO: b/449684779 - Remove this tag once Xcode 26+ is the default Xcode.
        ],
    )
    apple_verification_test(
        name = "{}_xcode_26_entitlements_watch_app_with_pointer_authentication_arm64e_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:simple_pointer_authentication_app_with_pointer_authentication_watchos_app",
        verifier_script = "verifier_scripts/entitlements_key_verifier.sh",
        env = {
            "BUNDLE_TEST_ROOT": ["$BUNDLE_ROOT/Watch/simple_pointer_authentication_app.app/"],
            "ENTITLEMENTS_KEY": ["com.apple.security.hardened-process.enhanced-security-version"],
        },
        tags = [
            name,
            # TODO: b/449684779 - Remove this tag once Xcode 26+ is the default Xcode.
        ],
    )

    # Test that an app with a compiled binary resource coming from a resource attribute will fail to
    # build and present a user-actionable error message.
    analysis_failure_message_test(
        name = "{}_with_binary_resources_in_transitive_deps_should_fail_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_binary_resources_in_transitive_deps",
        expected_error = (
            "Error: {parent_target} has a static or dynamic library coming from a target referenced from the resource-only attribute `data`:\n\n{bad_target}"
        ).format(
            parent_target = "//test/starlark_tests/targets_under_test/ios:objc_lib_with_binary_resources",
            bad_target = "//test/starlark_tests/resources:objc_common_lib",
        ),
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
