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

"""macos_application Starlark tests."""

load(
    ":rules/apple_verification_test.bzl",
    "apple_verification_test",
)
load(
    ":rules/common_verification_tests.bzl",
    "apple_symbols_file_test",
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
load(
    ":rules/analysis_xcasset_argv_test.bzl",
    "analysis_xcasset_argv_test",
)

def macos_application_test_suite(name):
    """Test suite for macos_application.

    Args:
      name: the base name to be used in things created by this macro
    """
    apple_verification_test(
        name = "{}_codesign_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_imported_fmwk_codesign_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_fmwk",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_entitlements_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        verifier_script = "verifier_scripts/entitlements_verifier.sh",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_swift_dylibs_no_static_linkage_test".format(name),
        build_type = "device",
        contains = [
            "$CONTENT_ROOT/Frameworks/libswiftCore.dylib",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_basic_swift",
        binary_test_file = "$CONTENT_ROOT/MacOS/app_basic_swift",
        binary_test_architecture = "x86_64",
        binary_not_contains_symbols = ["_swift_slowAlloc"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_additional_contents_test".format(name),
        build_type = "device",
        contains = [
            "$CONTENT_ROOT/Additional/additional.txt",
            "$CONTENT_ROOT/Nested/non_nested.txt",
            "$CONTENT_ROOT/Nested/nested/nested.txt",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_correct_rpath_header_value_test".format(name),
        build_type = "device",
        binary_test_file = "$CONTENT_ROOT/MacOS/app",
        macho_load_commands_contain = ["path @executable_path/../Frameworks (offset 12)"],
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_resources_test".format(name),
        build_type = "device",
        contains = [
            "$CONTENT_ROOT/Resources/resource_bundle.bundle/Info.plist",
            "$CONTENT_ROOT/Resources/Another.plist",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_strings_device_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        contains = [
            "$RESOURCE_ROOT/localization.bundle/en.lproj/files.stringsdict",
            "$RESOURCE_ROOT/localization.bundle/en.lproj/greetings.strings",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_custom_linkopts_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_special_linkopts",
        binary_test_file = "$CONTENT_ROOT/MacOS/app_special_linkopts",
        compilation_mode = "opt",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_linkopts_test_main"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_bundle_name_with_space_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_space",
        compilation_mode = "opt",
        contains = [
            "$ARCHIVE_ROOT/app with space.app",
        ],
        not_contains = [
            "$ARCHIVE_ROOT/app.app",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_bundle_name_with_different_extension_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_different_extension",
        compilation_mode = "opt",
        contains = [
            "$ARCHIVE_ROOT/app_with_different_extension.xpc",
        ],
        not_contains = [
            "$ARCHIVE_ROOT/app_with_different_extension.app",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_prebuilt_dynamic_framework_dependency_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_fmwk",
        contains = [
            "$CONTENT_ROOT/Frameworks/generated_macos_dynamic_fmwk.framework/generated_macos_dynamic_fmwk",
            "$CONTENT_ROOT/Frameworks/generated_macos_dynamic_fmwk.framework/Info.plist",
        ],
        not_contains = [
            "$CONTENT_ROOT/Frameworks/generated_macos_dynamic_fmwk.framework/Headers/SharedClass.h",
            "$CONTENT_ROOT/Frameworks/generated_macos_dynamic_fmwk.framework/Modules/module.modulemap",
        ],
        tags = [name],
    )

    dsyms_test(
        name = "{}_dsyms_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        expected_dsyms = ["app.app"],
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        expected_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "app",
            "CFBundleIdentifier": "com.google.example",
            "CFBundleName": "app",
            "CFBundlePackageType": "APPL",
            "CFBundleSupportedPlatforms:0": "MacOSX",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "macosx",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "macosx*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "LSMinimumSystemVersion": "10.10",
        },
        tags = [name],
    )

    # Tests xcasset tool is passed the correct arguments.
    analysis_xcasset_argv_test(
        name = "{}_xcasset_actool_argv".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_multiple_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_multiple_infoplists",
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
            "app_with_ext_and_symbols_in_bundle.app/Contents/MacOS/app_with_ext_and_symbols_in_bundle",
            "app_with_ext_and_symbols_in_bundle.app/Contents/PlugIns/ext.appex/Contents/MacOS/ext",
        ],
        build_type = "device",
        tags = [name],
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_ext_and_symbols_in_bundle",
    )

    infoplist_contents_test(
        name = "{}_minimum_os_deployment_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_minimum_deployment_os_version",
        expected_values = {
            "LSMinimumSystemVersion": "11.0",
        },
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
