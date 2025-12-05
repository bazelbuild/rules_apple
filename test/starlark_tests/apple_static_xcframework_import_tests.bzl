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

"""apple_static_xcframework_import Starlark tests."""

load(
    "//test/starlark_tests/rules:analysis_failure_message_test.bzl",
    "analysis_failure_message_test",
    "analysis_failure_message_with_tree_artifact_outputs_test",
)
load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "archive_contents_test",
)
load(
    ":common.bzl",
    "common",
)

visibility("private")

def apple_static_xcframework_import_test_suite(name):
    """Test suite for apple_static_xcframework_import.

    Args:
      name: the base name to be used in things created by this macro
    """

    # Verify importing XCFramework with static frameworks (i.e. not libraries) fails.
    analysis_failure_message_test(
        name = "{}_fails_importing_xcframework_with_static_framework_without_infoplist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_xcframework_with_static_frameworks_no_root_infoplists",
        expected_error = """
Error: Unexpectedly found no root Info.plist from the non-binary files found in the XCFramework:

third_party/bazel_rules/rules_apple/test/starlark_tests/targets_under_test/apple/generated_static_framework_xcframework_without_root_infoplist.xcframework/ios-arm64_x86_64-simulator/generated_static_framework_xcframework_without_root_infoplist.framework/Resources/generated_static_framework_xcframework_without_root_infoplist.bundle/Info.plist

There must be one root Info.plist in the framework bundle at \
"generated_static_framework_xcframework_without_root_infoplist.framework/Info.plist".
""",
        tags = [name],
    )

    # Verify ios_application with XCFramework with static library dependency contains symbols and
    # does not bundle anything under Frameworks/
    archive_contents_test(
        name = "{}_ios_application_with_imported_static_xcframework_includes_symbols".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_xcframework_with_static_library",
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = [
            "-[SharedClass doSomethingShared]",
            "_OBJC_CLASS_$_SharedClass",
        ],
        not_contains = ["$BUNDLE_ROOT/Frameworks/"],
        tags = [name],
    )

    # Verify that if codesigned_xcframework_files is set and the input is an unsigned XCFramework,
    # the signatures plist is written out with appropriate values.
    archive_contents_test(
        name = "{}_with_unsigned_xcframework_bundles_signatures_xml_plist".format(name),
        build_type = "device",
        cpus = {"ios_multi_cpus": ["arm64", "arm64e"]},
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_xcframework_with_static_library",
        contains = [
            "$ARCHIVE_ROOT/Signatures/generated_static_xcframework_with_headers.xcframework-ios.signature",
        ],
        plist_test_file = "$ARCHIVE_ROOT/Signatures/generated_static_xcframework_with_headers.xcframework-ios.signature",
        plist_test_values = {
            "isSecureTimestamp": "false",
            "metadata:library": "generated_static_xcframework_with_headers.a",
            "metadata:platform": "ios",
            "signed": "false",
        },
        tags = [name],
    )

    # Verify ios_application with XCFramework with Swift static library dependency contains
    # Objective-C symbols, doesn't bundle XCFramework, and does not bundle Swift standard libraries.
    archive_contents_test(
        name = "{}_swift_ios_application_with_imported_static_xcframework_includes_symbols".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_app_with_imported_xcframework_with_static_library",
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = [
            "-[SharedClass doSomethingShared]",
            "_OBJC_CLASS_$_SharedClass",
        ],
        not_contains = [
            "$BUNDLE_ROOT/Frameworks/generated_static_xcframework_with_headers",
            "$BUNDLE_ROOT/Frameworks/libswiftCore.dylib",  # Only required for iOS before 15.0.
        ],
        tags = [name],
    )

    # Verify ios_application with an imported XCFramework that has a Swift static library
    # contains symbols visible to Objective-C, and does not bundle Swift standard libraries.
    archive_contents_test(
        name = "{}_swift_with_imported_static_fmwk_contains_symbols_and_does_not_bundle_swift_std_libraries".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_swift_xcframework_with_static_library",
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = [
            "_OBJC_CLASS_$__TtC34generated_swift_static_xcframework11SharedClass",
        ],
        not_contains = ["$BUNDLE_ROOT/Frameworks/libswiftCore.dylib"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_swift_with_imported_swift_static_fmwk_contains_symbols_and_does_not_bundle_swift_std_libraries".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_app_with_imported_swift_xcframework_with_static_library",
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = [
            "_OBJC_CLASS_$__TtC34generated_swift_static_xcframework11SharedClass",
        ],
        not_contains = ["$BUNDLE_ROOT/Frameworks/libswiftCore.dylib"],
        tags = [name],
    )

    # Verify Swift standard libraries are not bundled for an imported XCFramework that has a Swift
    # static library containing no module interface files (.swiftmodule directory) and where the
    # import rule sets `has_swift` = True.
    archive_contents_test(
        name = "{}_swift_with_no_module_interface_files_and_has_swift_attr_enabled_does_not_bundle_swift_std_libraries".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_swift_xcframework_with_static_library_without_swiftmodule",
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = [
            "_OBJC_CLASS_$__TtC34generated_swift_static_xcframework11SharedClass",
        ],
        not_contains = ["$BUNDLE_ROOT/Frameworks/libswiftCore.dylib"],
        tags = [name],
    )

    # Verify ios_application links correct XCFramework library between simulator and device builds.
    archive_contents_test(
        name = "{}_links_ios_arm64_macho_load_cmd_for_simulator_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_xcframework_with_static_library",
        binary_test_file = "$BINARY",
        binary_test_architecture = "arm64",
        cpus = {"ios_multi_cpus": ["sim_arm64"]},
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform IOSSIMULATOR"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_links_ios_arm64_macho_load_cmd_for_device_test".format(name),
        build_type = "device",
        cpus = {"ios_multi_cpus": ["arm64"]},
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_xcframework_with_static_library",
        binary_test_architecture = "arm64",
        binary_test_file = "$BINARY",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform IOS"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_links_ios_arm64e_macho_load_cmd_for_device_test".format(name),
        build_type = "device",
        cpus = {"ios_multi_cpus": ["arm64e"]},
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_xcframework_with_static_library",
        binary_test_architecture = "arm64e",
        binary_test_file = "$BINARY",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform IOS"],
        tags = [name],
    )

    # Verify watchos_application links correct XCFramework library for arm64* architectures.
    archive_contents_test(
        name = "{}_links_watchos_arm64_macho_load_cmd_for_simulator_test".format(name),
        build_type = "simulator",
        cpus = {"watchos_cpus": ["arm64"]},
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_with_imported_static_xcframework",
        not_contains = ["$BUNDLE_ROOT/Frameworks"],
        binary_test_file = "$BUNDLE_ROOT/app_with_imported_static_xcframework",
        binary_test_architecture = "arm64",
        binary_contains_symbols = [
            "-[SharedClass doSomethingShared]",
            "_OBJC_CLASS_$_SharedClass",
        ],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform WATCHOSSIMULATOR"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_links_watchos_arm64_32_macho_load_cmd_for_device_test".format(name),
        build_type = "device",
        cpus = {"watchos_cpus": ["arm64_32"]},
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_with_imported_static_xcframework",
        not_contains = ["$BUNDLE_ROOT/Frameworks"],
        binary_test_file = "$BUNDLE_ROOT/app_with_imported_static_xcframework",
        binary_test_architecture = "arm64_32",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform WATCHOS"],
        binary_contains_symbols = [
            "-[SharedClass doSomethingShared]",
            "_OBJC_CLASS_$_SharedClass",
        ],
        tags = [name],
    )

    # Verify tvos_application links XCFramework library for device and simulator architectures.
    archive_contents_test(
        name = "{}_links_imported_tvos_xcframework_to_application_device_build".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/tvos:app_with_imported_static_xcframework",
        binary_test_file = "$BINARY",
        binary_test_architecture = "arm64",
        binary_contains_symbols = [
            "-[SharedClass doSomethingShared]",
            "_OBJC_CLASS_$_SharedClass",
        ],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform TVOS"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_links_imported_tvos_xcframework_to_application_simulator_arm64_build".format(name),
        build_type = "simulator",
        cpus = {"tvos_cpus": ["sim_arm64"]},
        target_under_test = "//test/starlark_tests/targets_under_test/tvos:app_with_imported_static_xcframework",
        binary_test_file = "$BINARY",
        binary_test_architecture = "arm64",
        binary_contains_symbols = [
            "-[SharedClass doSomethingShared]",
            "_OBJC_CLASS_$_SharedClass",
        ],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform TVOSSIMULATOR"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_links_imported_tvos_xcframework_to_application_simulator_x86_64_build".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/tvos:app_with_imported_static_xcframework",
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = [
            "-[SharedClass doSomethingShared]",
            "_OBJC_CLASS_$_SharedClass",
        ],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform TVOSSIMULATOR"],
        tags = [name],
    )

    # Verify that the empty dylib for a Static Framework XCFramework is not linked by the app binary.
    archive_contents_test(
        name = "{}_framework_dependent_app_does_not_link_ios_x86_64_macho_load_cmd_for_simulator_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_static_framework_xcframework",
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        cpus = {"ios_multi_cpus": ["x86_64"]},
        macho_load_commands_not_contain = [
            "name @rpath/ios_static_framework_xcframework_with_data_resource_bundle.framework/ios_static_framework_xcframework_with_data_resource_bundle",
        ],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_framework_dependent_app_does_not_link_ios_arm64_macho_load_cmd_for_simulator_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_static_framework_xcframework",
        binary_test_file = "$BINARY",
        binary_test_architecture = "arm64",
        cpus = {"ios_multi_cpus": ["arm64"]},
        macho_load_commands_not_contain = [
            "name @rpath/ios_static_framework_xcframework_with_data_resource_bundle.framework/ios_static_framework_xcframework_with_data_resource_bundle",
        ],
        tags = [name],
    )

    # Verify that the Static Framework XCFramework's resources are bundled correctly, and the empty
    # dylib is built for the correct platform and minimum OS version.
    archive_contents_test(
        name = "{}_framework_links_ios_x86_64_macho_load_cmd_for_simulator_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_static_framework_xcframework",
        binary_test_file = "$BUNDLE_ROOT/Frameworks/ios_static_framework_xcframework_with_data_resource_bundle.framework/ios_static_framework_xcframework_with_data_resource_bundle",
        binary_test_architecture = "x86_64",
        cpus = {"ios_multi_cpus": ["x86_64"]},
        contains = [
            "$BUNDLE_ROOT/Frameworks/ios_static_framework_xcframework_with_data_resource_bundle.framework/Info.plist",
            "$BUNDLE_ROOT/Frameworks/ios_static_framework_xcframework_with_data_resource_bundle.framework/ios_static_framework_xcframework_with_data_resource_bundle",
            "$BUNDLE_ROOT/Frameworks/ios_static_framework_xcframework_with_data_resource_bundle.framework/resource_bundle.bundle/custom_apple_resource_info.out",
            "$BUNDLE_ROOT/Frameworks/ios_static_framework_xcframework_with_data_resource_bundle.framework/resource_bundle.bundle/Info.plist",
        ],
        not_contains = [
            "$BUNDLE_ROOT/Frameworks/ios_static_framework_xcframework_with_data_resource_bundle.framework/Headers/",
            "$BUNDLE_ROOT/Frameworks/ios_static_framework_xcframework_with_data_resource_bundle.framework/Modules/",
        ],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_ios.baseline, "platform IOSSIMULATOR"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_framework_links_ios_arm64_macho_load_cmd_for_device_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_static_framework_xcframework",
        binary_test_file = "$BUNDLE_ROOT/Frameworks/ios_static_framework_xcframework_with_data_resource_bundle.framework/ios_static_framework_xcframework_with_data_resource_bundle",
        binary_test_architecture = "arm64",
        cpus = {"ios_multi_cpus": ["arm64"]},
        contains = [
            "$BUNDLE_ROOT/Frameworks/ios_static_framework_xcframework_with_data_resource_bundle.framework/Info.plist",
            "$BUNDLE_ROOT/Frameworks/ios_static_framework_xcframework_with_data_resource_bundle.framework/ios_static_framework_xcframework_with_data_resource_bundle",
            "$BUNDLE_ROOT/Frameworks/ios_static_framework_xcframework_with_data_resource_bundle.framework/resource_bundle.bundle/custom_apple_resource_info.out",
            "$BUNDLE_ROOT/Frameworks/ios_static_framework_xcframework_with_data_resource_bundle.framework/resource_bundle.bundle/Info.plist",
        ],
        not_contains = [
            "$BUNDLE_ROOT/Frameworks/ios_static_framework_xcframework_with_data_resource_bundle.framework/Headers/",
            "$BUNDLE_ROOT/Frameworks/ios_static_framework_xcframework_with_data_resource_bundle.framework/Modules/",
        ],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_ios.baseline, "platform IOS"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_framework_ios_device_empty_dylib_matches_original_info_plist_minos_test".format(name),
        build_type = "device",
        cpus = {"ios_multi_cpus": ["arm64"]},
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_nplus1_minos_and_baseline_minos_imported_static_framework_xcframework",
        plist_test_file = "$BUNDLE_ROOT/Frameworks/ios_static_framework_xcframework_with_data_resource_bundle.framework/Info.plist",
        plist_test_values = {
            "MinimumOSVersion": common.min_os_ios.baseline,
        },
        tags = [name],
    )

    # Verify macos_application links the XCFramework unversioned static framework for device and
    # simulator architectures.
    archive_contents_test(
        name = "{}_bundles_imported_macos_unversioned_framework_xcframework_to_application_x86_64_build".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_static_unversioned_xcframework",
        binary_test_file = "$CONTENT_ROOT/Frameworks/generated_static_macos_unversioned_xcframework.framework/generated_static_macos_unversioned_xcframework",
        binary_test_architecture = "x86_64",
        contains = [
            "$CONTENT_ROOT/Frameworks/generated_static_macos_unversioned_xcframework.framework/Resources/Info.plist",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_unversioned_xcframework.framework/generated_static_macos_unversioned_xcframework",
        ],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_macos.arm64_support_plus1, "platform MACOS"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_bundles_imported_macos_unversioned_framework_xcframework_to_application_arm64_build".format(name),
        build_type = "device",
        cpus = {"macos_cpus": ["arm64"]},
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_static_unversioned_xcframework",
        binary_test_file = "$CONTENT_ROOT/Frameworks/generated_static_macos_unversioned_xcframework.framework/generated_static_macos_unversioned_xcframework",
        binary_test_architecture = "arm64",
        contains = [
            "$CONTENT_ROOT/Frameworks/generated_static_macos_unversioned_xcframework.framework/Resources/Info.plist",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_unversioned_xcframework.framework/generated_static_macos_unversioned_xcframework",
        ],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_macos.arm64_support_plus1, "platform MACOS"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_bundles_imported_macos_unversioned_framework_xcframework_to_application_arm64e_build".format(name),
        build_type = "device",
        cpus = {"macos_cpus": ["arm64e"]},
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_static_unversioned_xcframework",
        binary_test_file = "$CONTENT_ROOT/Frameworks/generated_static_macos_unversioned_xcframework.framework/generated_static_macos_unversioned_xcframework",
        binary_test_architecture = "arm64e",
        contains = [
            "$CONTENT_ROOT/Frameworks/generated_static_macos_unversioned_xcframework.framework/Resources/Info.plist",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_unversioned_xcframework.framework/generated_static_macos_unversioned_xcframework",
        ],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_macos.arm64_support_plus1, "platform MACOS"],
        tags = [name],
    )

    # Verify macos_application links the XCFramework versioned static framework for device and
    # simulator architectures.
    archive_contents_test(
        name = "{}_bundles_imported_macos_versioned_framework_xcframework_to_application_x86_64_build".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_static_versioned_xcframework",
        binary_test_file = "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/generated_static_macos_versioned_xcframework",
        binary_test_architecture = "x86_64",
        contains = [
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Resources/Info.plist",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/generated_static_macos_versioned_xcframework",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Versions/A/Resources/Info.plist",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Versions/A/generated_static_macos_versioned_xcframework",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Versions/Current/Resources/Info.plist",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Versions/Current/generated_static_macos_versioned_xcframework",
        ],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_macos.arm64_support_plus1, "platform MACOS"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_bundles_imported_macos_versioned_framework_xcframework_to_application_arm64_build".format(name),
        build_type = "device",
        cpus = {"macos_cpus": ["arm64"]},
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_static_versioned_xcframework",
        binary_test_file = "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/generated_static_macos_versioned_xcframework",
        binary_test_architecture = "arm64",
        contains = [
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Resources/Info.plist",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/generated_static_macos_versioned_xcframework",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Versions/A/Resources/Info.plist",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Versions/A/generated_static_macos_versioned_xcframework",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Versions/Current/Resources/Info.plist",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Versions/Current/generated_static_macos_versioned_xcframework",
        ],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_macos.arm64_support_plus1, "platform MACOS"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_bundles_imported_macos_versioned_framework_xcframework_to_application_arm64e_build".format(name),
        build_type = "device",
        cpus = {"macos_cpus": ["arm64e"]},
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_static_versioned_xcframework",
        binary_test_file = "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/generated_static_macos_versioned_xcframework",
        binary_test_architecture = "arm64e",
        contains = [
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Resources/Info.plist",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/generated_static_macos_versioned_xcframework",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Versions/A/Resources/Info.plist",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Versions/A/generated_static_macos_versioned_xcframework",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Versions/Current/Resources/Info.plist",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Versions/Current/generated_static_macos_versioned_xcframework",
        ],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_macos.arm64_support_plus1, "platform MACOS"],
        tags = [name],
    )

    # Verify importing Static Framework XCFrameworks with versioned frameworks and tree artifacts
    # fails.
    analysis_failure_message_with_tree_artifact_outputs_test(
        name = "{}_fails_with_versioned_frameworks_and_tree_artifact_outputs_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_static_versioned_xcframework",
        expected_error = "Error: \"imported_static_versioned_xcframework\" does not currently support versioned frameworks with the tree artifact feature/build setting. Please ensure that the `apple.experimental.tree_artifact_outputs` variable is not set to 1 on the command line or in your active build configuration.",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_secure_features_app_fails_importing_xcframework_with_no_expected_secure_features_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:secure_features_app_with_imported_static_xcframework_and_no_expected_secure_features",
        expected_error = """The precompiled artifact at `//test/starlark_tests/targets_under_test/ios:ios_imported_static_xcframework_with_missing_pointer_authentication_secure_features` was expected to be compatible with the following secure features requested from the build, but they were not indicated as supported by the target's `expected_secure_features` attribute:
- apple.xcode_26_minimum_opt_in

Please contact the owner of this target to supply a precompiled artifact (likely a framework or XCFramework) that is built with the required Enhanced Security features enabled, and update the "expected_secure_features" attribute to match.""",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_secure_features_app_fails_importing_xcframework_with_mismatched_secure_features_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:secure_features_app_with_imported_static_xcframework_and_mismatched_secure_features",
        expected_error = """The precompiled artifact at `//test/starlark_tests/targets_under_test/ios:ios_imported_static_xcframework` was expected to be compatible with the following secure features requested from the build, but they were not indicated as supported by the target's `expected_secure_features` attribute:
- trivial_auto_var_init

Please contact the owner of this target to supply a precompiled artifact (likely a framework or XCFramework) that is built with the required Enhanced Security features enabled, and update the "expected_secure_features" attribute to match.
""",
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
