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

"""apple_dynamic_xcframework_import Starlark tests."""

load(
    "//test/starlark_tests/rules:analysis_failure_message_test.bzl",
    "analysis_failure_message_test",
    "analysis_failure_message_with_tree_artifact_outputs_test",
)
load(
    "//test/starlark_tests/rules:analysis_target_actions_test.bzl",
    "analysis_contains_xcframework_processor_action_test",
)
load(
    "//test/starlark_tests/rules:apple_verification_test.bzl",
    "apple_verification_test",
)
load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "archive_contents_test",
    "binary_contents_test",
)

def apple_dynamic_xcframework_import_test_suite(name):
    """Test suite for apple_dynamic_xcframework_import.

    Args:
      name: the base name to be used in things created by this macro
    """

    # Verify ios_application bundles Framework files from imported XCFramework.
    archive_contents_test(
        name = "{}_contains_imported_xcframework_framework_files".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_xcframework",
        contains = [
            "$BUNDLE_ROOT/Frameworks/generated_dynamic_xcframework_with_headers.framework/Info.plist",
            "$BUNDLE_ROOT/Frameworks/generated_dynamic_xcframework_with_headers.framework/generated_dynamic_xcframework_with_headers",
        ],
        not_contains = [
            "$BUNDLE_ROOT/Frameworks/generated_dynamic_xcframework_with_headers.framework/Headers/",
            "$BUNDLE_ROOT/Frameworks/generated_dynamic_xcframework_with_headers.framework/Modules/",
        ],
        binary_test_file = "$BINARY",
        macho_load_commands_contain = [
            "name @rpath/generated_dynamic_xcframework_with_headers.framework/generated_dynamic_xcframework_with_headers (offset 24)",
        ],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_swift_contains_imported_xcframework_framework_files".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_app_with_imported_objc_xcframework",
        contains = [
            "$BUNDLE_ROOT/Frameworks/generated_dynamic_xcframework_with_headers.framework/Info.plist",
            "$BUNDLE_ROOT/Frameworks/generated_dynamic_xcframework_with_headers.framework/generated_dynamic_xcframework_with_headers",
            "$BUNDLE_ROOT/Frameworks/libswiftCore.dylib",
        ],
        not_contains = [
            "$BUNDLE_ROOT/Frameworks/generated_dynamic_xcframework_with_headers.framework/Headers/",
            "$BUNDLE_ROOT/Frameworks/generated_dynamic_xcframework_with_headers.framework/Modules/",
        ],
        binary_test_file = "$BINARY",
        macho_load_commands_contain = [
            "name @rpath/generated_dynamic_xcframework_with_headers.framework/generated_dynamic_xcframework_with_headers (offset 24)",
        ],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_contains_imported_swift_xcframework_framework_files".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_swift_xcframework",
        contains = [
            "$BUNDLE_ROOT/Frameworks/Swift3PFmwkWithGenHeader.framework/Info.plist",
            "$BUNDLE_ROOT/Frameworks/Swift3PFmwkWithGenHeader.framework/Swift3PFmwkWithGenHeader",
        ],
        not_contains = [
            "$BUNDLE_ROOT/Frameworks/Swift3PFmwkWithGenHeader.framework/Headers/",
            "$BUNDLE_ROOT/Frameworks/Swift3PFmwkWithGenHeader.framework/Modules/",
        ],
        binary_test_file = "$BINARY",
        macho_load_commands_contain = [
            "name @rpath/Swift3PFmwkWithGenHeader.framework/Swift3PFmwkWithGenHeader (offset 24)",
        ],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_swift_contains_imported_swift_xcframework_framework_files".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_app_with_imported_swift_xcframework",
        contains = [
            "$BUNDLE_ROOT/Frameworks/Swift3PFmwkWithGenHeader.framework/Info.plist",
            "$BUNDLE_ROOT/Frameworks/Swift3PFmwkWithGenHeader.framework/Swift3PFmwkWithGenHeader",
        ],
        not_contains = [
            "$BUNDLE_ROOT/Frameworks/Swift3PFmwkWithGenHeader.framework/Headers/",
            "$BUNDLE_ROOT/Frameworks/Swift3PFmwkWithGenHeader.framework/Modules/",
        ],
        binary_test_file = "$BINARY",
        macho_load_commands_contain = [
            "name @rpath/Swift3PFmwkWithGenHeader.framework/Swift3PFmwkWithGenHeader (offset 24)",
        ],
        tags = [name],
    )

    # Verify the correct XCFramework library was bundled and sliced for the required architecture.
    binary_contents_test(
        name = "{}_xcframework_binary_file_info_test_x86_64".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_xcframework",
        binary_test_file = "$BUNDLE_ROOT/Frameworks/generated_dynamic_xcframework_with_headers.framework/generated_dynamic_xcframework_with_headers",
        binary_contains_file_info = ["Mach-O 64-bit dynamically linked shared library x86_64"],
        tags = [name],
    )
    binary_contents_test(
        name = "{}_xcframework_binary_file_info_test_arm64".format(name),
        build_type = "simulator",
        cpus = {"ios_multi_cpus": ["sim_arm64"]},
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_xcframework",
        binary_test_file = "$BUNDLE_ROOT/Frameworks/generated_dynamic_xcframework_with_headers.framework/generated_dynamic_xcframework_with_headers",
        binary_contains_file_info = ["Mach-O 64-bit dynamically linked shared library arm64"],
        tags = [name],
    )
    binary_contents_test(
        name = "{}_xcframework_binary_file_info_test_arm64_device".format(name),
        build_type = "device",
        cpus = {"ios_multi_cpus": ["arm64"]},
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_xcframework",
        binary_test_file = "$BUNDLE_ROOT/Frameworks/generated_dynamic_xcframework_with_headers.framework/generated_dynamic_xcframework_with_headers",
        binary_contains_file_info = ["Mach-O 64-bit dynamically linked shared library arm64"],
        tags = [name],
    )
    binary_contents_test(
        name = "{}_xcframework_binary_file_info_test_fat".format(name),
        build_type = "simulator",
        cpus = {
            "ios_multi_cpus": [
                "sim_arm64",
                "x86_64",
            ],
        },
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_xcframework",
        binary_test_file = "$BUNDLE_ROOT/Frameworks/generated_dynamic_xcframework_with_headers.framework/generated_dynamic_xcframework_with_headers",
        binary_contains_file_info = [
            "Mach-O universal binary with 2 architectures:",
            "x86_64:Mach-O 64-bit dynamically linked shared library x86_64",
            "arm64:Mach-O 64-bit dynamically linked shared library arm64",
        ],
        tags = [name],
    )
    binary_contents_test(
        name = "{}_xcframework_swift_binary_file_info_test_fat".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_swift_xcframework",
        binary_test_file = "$BUNDLE_ROOT/Frameworks/Swift3PFmwkWithGenHeader.framework/Swift3PFmwkWithGenHeader",
        binary_contains_file_info = ["Mach-O 64-bit dynamically linked shared library x86_64"],
        tags = [name],
    )

    # Verify bundled frameworks from imported XCFrameworks are codesigned.
    apple_verification_test(
        name = "{}_imported_xcframework_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_xcframework",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )
    apple_verification_test(
        name = "{}_imported_swift_xcframework_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_xcframework",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    # Verify ios_application bundles Framework files when using xcframework_processor_tool.
    archive_contents_test(
        name = "{}_contains_imported_xcframework_framework_files_with_xcframework_import_tool".format(name),
        build_type = "simulator",
        build_settings = {
            "//apple/build_settings:parse_xcframework_info_plist": "True",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_xcframework",
        contains = [
            "$BUNDLE_ROOT/Frameworks/generated_dynamic_xcframework_with_headers.framework/Info.plist",
            "$BUNDLE_ROOT/Frameworks/generated_dynamic_xcframework_with_headers.framework/generated_dynamic_xcframework_with_headers",
        ],
        not_contains = [
            "$BUNDLE_ROOT/Frameworks/generated_dynamic_xcframework_with_headers.framework/Headers/",
            "$BUNDLE_ROOT/Frameworks/generated_dynamic_xcframework_with_headers.framework/Modules/",
        ],
        binary_test_file = "$BINARY",
        macho_load_commands_contain = [
            "name @rpath/generated_dynamic_xcframework_with_headers.framework/generated_dynamic_xcframework_with_headers (offset 24)",
        ],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_swift_contains_imported_swift_xcframework_framework_files_with_xcframework_import_tool".format(name),
        build_type = "simulator",
        build_settings = {
            "//apple/build_settings:parse_xcframework_info_plist": "True",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_app_with_imported_swift_xcframework",
        contains = [
            "$BUNDLE_ROOT/Frameworks/Swift3PFmwkWithGenHeader.framework/Info.plist",
            "$BUNDLE_ROOT/Frameworks/Swift3PFmwkWithGenHeader.framework/Swift3PFmwkWithGenHeader",
        ],
        not_contains = [
            "$BUNDLE_ROOT/Frameworks/Swift3PFmwkWithGenHeader.framework/Headers/",
            "$BUNDLE_ROOT/Frameworks/Swift3PFmwkWithGenHeader.framework/Modules/",
        ],
        binary_test_file = "$BINARY",
        macho_load_commands_contain = [
            "name @rpath/Swift3PFmwkWithGenHeader.framework/Swift3PFmwkWithGenHeader (offset 24)",
        ],
        tags = [name],
    )

    # Verify XCFramework processor tool action is registered via build setting.
    analysis_contains_xcframework_processor_action_test(
        name = "{}_imported_xcframework_framework_files_registers_action_with_xcframework_import_tool".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:ios_imported_dynamic_xcframework",
        target_mnemonic = "ProcessXCFrameworkFiles",
        tags = [name],
    )

    # Verify ios_application links correct XCFramework library for arm64* architectures.
    archive_contents_test(
        name = "{}_links_ios_arm64_macho_load_cmd_for_simulator_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_xcframework",
        binary_test_file = "$BUNDLE_ROOT/Frameworks/generated_dynamic_xcframework_with_headers.framework/generated_dynamic_xcframework_with_headers",
        binary_test_architecture = "arm64",
        cpus = {"ios_multi_cpus": ["sim_arm64"]},
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform IOSSIMULATOR"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_links_ios_arm64_macho_load_cmd_for_device_test".format(name),
        build_type = "device",
        cpus = {"ios_multi_cpus": ["arm64"]},
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_xcframework",
        binary_test_file = "$BUNDLE_ROOT/Frameworks/generated_dynamic_xcframework_with_headers.framework/generated_dynamic_xcframework_with_headers",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform IOS"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_links_ios_arm64e_macho_load_cmd_for_device_test".format(name),
        build_type = "device",
        cpus = {"ios_multi_cpus": ["arm64e"]},
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_xcframework",
        binary_test_file = "$BUNDLE_ROOT/Frameworks/generated_dynamic_xcframework_with_headers.framework/generated_dynamic_xcframework_with_headers",
        binary_test_architecture = "arm64e",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform IOS"],
        tags = [name],
    )

    # Verify watchos_application links correct XCFramework library for arm64* architectures.
    archive_contents_test(
        name = "{}_links_watchos_arm64_macho_load_cmd_for_simulator_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_with_imported_xcframework",
        binary_test_file = "$BUNDLE_ROOT/Frameworks/generated_dynamic_watchos_xcframework.framework/generated_dynamic_watchos_xcframework",
        binary_test_architecture = "arm64",
        cpus = {"watchos_cpus": ["arm64"]},
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform WATCHOSSIMULATOR"],
    )
    archive_contents_test(
        name = "{}_links_watchos_arm64_32_macho_load_cmd_for_device_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_with_imported_xcframework",
        binary_test_file = "$BUNDLE_ROOT/Frameworks/generated_dynamic_watchos_xcframework.framework/generated_dynamic_watchos_xcframework",
        binary_test_architecture = "arm64_32",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform WATCHOS"],
    )

    # Verify tvos_application bundles XCFramework library for device and simulator architectures.
    archive_contents_test(
        name = "{}_bundles_imported_tvos_xcframework_to_application_device_build".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/tvos:app_with_imported_dynamic_xcframework",
        contains = [
            "$BUNDLE_ROOT/Frameworks/generated_dynamic_tvos_xcframework.framework/Info.plist",
            "$BUNDLE_ROOT/Frameworks/generated_dynamic_tvos_xcframework.framework/generated_dynamic_tvos_xcframework",
        ],
        binary_test_file = "$BUNDLE_ROOT/Frameworks/generated_dynamic_tvos_xcframework.framework/generated_dynamic_tvos_xcframework",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform TVOS"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_bundles_imported_tvos_xcframework_to_application_simulator_arm64_build".format(name),
        build_type = "simulator",
        cpus = {"tvos_cpus": ["sim_arm64"]},
        target_under_test = "//test/starlark_tests/targets_under_test/tvos:app_with_imported_dynamic_xcframework",
        contains = [
            "$BUNDLE_ROOT/Frameworks/generated_dynamic_tvos_xcframework.framework/Info.plist",
            "$BUNDLE_ROOT/Frameworks/generated_dynamic_tvos_xcframework.framework/generated_dynamic_tvos_xcframework",
        ],
        binary_test_file = "$BUNDLE_ROOT/Frameworks/generated_dynamic_tvos_xcframework.framework/generated_dynamic_tvos_xcframework",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform TVOSSIMULATOR"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_bundles_imported_tvos_xcframework_to_application_simulator_x86_64_build".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/tvos:app_with_imported_dynamic_xcframework",
        contains = [
            "$BUNDLE_ROOT/Frameworks/generated_dynamic_tvos_xcframework.framework/Info.plist",
            "$BUNDLE_ROOT/Frameworks/generated_dynamic_tvos_xcframework.framework/generated_dynamic_tvos_xcframework",
        ],
        binary_test_file = "$BUNDLE_ROOT/Frameworks/generated_dynamic_tvos_xcframework.framework/generated_dynamic_tvos_xcframework",
        binary_test_architecture = "x86_64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform TVOSSIMULATOR"],
        tags = [name],
    )

    # Verify macos_application links XCFramework library for device and simulator architectures.
    archive_contents_test(
        name = "{}_bundles_imported_macos_xcframework_to_application_x86_64_build".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_dynamic_versioned_xcframework",
        binary_test_file = "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/generated_dynamic_macos_versioned_xcframework",
        binary_test_architecture = "x86_64",
        contains = [
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Resources/Info.plist",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/generated_dynamic_macos_versioned_xcframework",
        ],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform MACOS"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_bundles_imported_macos_xcframework_to_application_arm64_build".format(name),
        build_type = "device",
        cpus = {"macos_cpus": ["arm64"]},
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_dynamic_versioned_xcframework",
        binary_test_file = "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/generated_dynamic_macos_versioned_xcframework",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform MACOS"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_bundles_imported_macos_xcframework_to_application_arm64e_build".format(name),
        build_type = "simulator",
        cpus = {"macos_cpus": ["arm64e"]},
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_dynamic_versioned_xcframework",
        binary_test_file = "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/generated_dynamic_macos_versioned_xcframework",
        binary_test_architecture = "arm64e",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform MACOS"],
        tags = [name],
    )

    # Verify importing XCFramework with dynamic libraries (i.e. not Apple frameworks) fails.
    analysis_failure_message_test(
        name = "{}_fails_importing_xcframework_with_libraries_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_imported_xcframework_with_libraries",
        expected_error = "Importing XCFrameworks with dynamic libraries is not supported.",
        tags = [name],
    )

    # Verify macos_application links XCFramework versioned framework for device and simulator
    # architectures.
    archive_contents_test(
        name = "{}_bundles_imported_macos_versioned_xcframework_to_application_x86_64_build".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_dynamic_versioned_xcframework",
        binary_test_file = "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/generated_dynamic_macos_versioned_xcframework",
        binary_test_architecture = "x86_64",
        contains = [
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Resources/Info.plist",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/generated_dynamic_macos_versioned_xcframework",
        ],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform MACOS"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_bundles_imported_macos_versioned_xcframework_to_application_arm64_build".format(name),
        build_type = "device",
        cpus = {"macos_cpus": ["arm64"]},
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_dynamic_versioned_xcframework",
        binary_test_file = "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/generated_dynamic_macos_versioned_xcframework",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform MACOS"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_bundles_imported_macos_versioned_xcframework_to_application_arm64e_build".format(name),
        build_type = "simulator",
        cpus = {"macos_cpus": ["arm64e"]},
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_dynamic_versioned_xcframework",
        binary_test_file = "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/generated_dynamic_macos_versioned_xcframework",
        binary_test_architecture = "arm64e",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform MACOS"],
        tags = [name],
    )

    # Verify importing XCFramework with versioned frameworks and tree artifacts fails.
    analysis_failure_message_with_tree_artifact_outputs_test(
        name = "{}_fails_with_versioned_frameworks_and_tree_artifact_outputs_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_dynamic_versioned_xcframework",
        expected_error = (
            "The apple_dynamic_xcframework_import rule does not yet support versioned " +
            "frameworks with the experimental tree artifact feature/build setting."
        ),
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
