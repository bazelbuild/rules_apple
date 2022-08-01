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

load(":rules/analysis_failure_message_test.bzl", "analysis_failure_message_test")
load(":rules/apple_verification_test.bzl", "apple_verification_test")
load(":rules/common_verification_tests.bzl", "archive_contents_test", "binary_contents_test")

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
            "$BUNDLE_ROOT/Frameworks/SwiftFmwkWithGenHeader.framework/Info.plist",
            "$BUNDLE_ROOT/Frameworks/SwiftFmwkWithGenHeader.framework/SwiftFmwkWithGenHeader",
        ],
        not_contains = [
            "$BUNDLE_ROOT/Frameworks/SwiftFmwkWithGenHeader.framework/Headers/",
            "$BUNDLE_ROOT/Frameworks/SwiftFmwkWithGenHeader.framework/Modules/",
        ],
        binary_test_file = "$BINARY",
        macho_load_commands_contain = [
            "name @rpath/SwiftFmwkWithGenHeader.framework/SwiftFmwkWithGenHeader (offset 24)",
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
        binary_test_file = "$BUNDLE_ROOT/Frameworks/SwiftFmwkWithGenHeader.framework/SwiftFmwkWithGenHeader",
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
        target_features = ["apple.parse_xcframework_info_plist"],
        tags = [name],
    )

    # Verify importing XCFramework with dynamic libraries (i.e. not Apple frameworks) fails.
    analysis_failure_message_test(
        name = "{}_fails_importing_xcframework_with_libraries_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_imported_xcframework_with_libraries",
        expected_error = "Importing XCFrameworks with dynamic libraries is not supported.",
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
