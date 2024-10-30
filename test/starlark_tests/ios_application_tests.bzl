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
)
load(
    "//test/starlark_tests/rules:analysis_output_group_info_files_test.bzl",
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
    "//test/starlark_tests/rules:apple_bundle_archive_support_info_device_test.bzl",
    "apple_bundle_archive_support_info_device_test",
)
load(
    "//test/starlark_tests/rules:apple_codesigning_dossier_info_provider_test.bzl",
    "apple_codesigning_dossier_info_provider_test",
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
    "apple_symbols_file_test",
    "archive_contents_test",
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

def ios_application_test_suite(name):
    """Test suite for ios_application.

    Args:
      name: the base name to be used in things created by this macro
    """
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

    # Verify that Swift dylibs are packaged with the application, when the application uses Swift.
    archive_contents_test(
        name = "{}_device_swift_dylibs_present".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_app_requiring_support_libs",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libswiftCore.dylib",
            "$ARCHIVE_ROOT/SwiftSupport/iphoneos/libswiftCore.dylib",
        ],
        tags = [name],
    )
    apple_bundle_archive_support_info_device_test(
        name = "{}_bundle_archive_support_contains_stub_executable_device_test".format(name),
        expected_archive_bundle_files = ["SwiftSupport/iphoneos/swiftlibs"],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_app_requiring_support_libs",
        tags = [name],
    )
    archive_contents_test(
        name = "{}_simulator_swift_dylibs_present".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_app_requiring_support_libs",
        contains = ["$BUNDLE_ROOT/Frameworks/libswiftCore.dylib"],
        tags = [name],
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
            "$BUNDLE_ROOT/Frameworks/libswiftCore.dylib",
            "$BUNDLE_ROOT/Frameworks/iOSDynamicFramework.framework/Info.plist",
            "$BUNDLE_ROOT/Frameworks/iOSDynamicFramework.framework/iOSDynamicFramework",
        ],
        not_contains = [
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
        contains = ["$BUNDLE_ROOT/Frameworks/libswiftCore.dylib"],
        not_contains = ["$BUNDLE_ROOT/Frameworks/iOSSwiftStaticFramework.framework"],
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
        contains = ["$BUNDLE_ROOT/Frameworks/libswiftCore.dylib"],
        not_contains = ["$BUNDLE_ROOT/Frameworks/iOSStaticFramework.framework"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_swift_with_imported_swift_static_fmwk_contains_symbols_and_not_bundles_files".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_app_with_imported_swift_static_fmwk",
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_OBJC_CLASS_$__TtC23iOSSwiftStaticFramework11SharedClass"],
        contains = ["$BUNDLE_ROOT/Frameworks/libswiftCore.dylib"],
        not_contains = ["$BUNDLE_ROOT/Frameworks/iOSSwiftStaticFramework.framework"],
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
    apple_dsym_bundle_info_test(
        name = "{}_transitive_dsyms_test".format(name),
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
        name = "{}_contains_app_intents_metadata_bundle_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_app_intents",
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
- //test/starlark_tests/resources:app_intent
- //test/starlark_tests/resources:hinted_app_intent
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

    # Test app with App Intents generates and bundles Metadata.appintents bundle for fat binaries.
    archive_contents_test(
        name = "{}_fat_build_contains_app_intents_metadata_bundle_test".format(name),
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

    native.test_suite(
        name = name,
        tags = [name],
    )
