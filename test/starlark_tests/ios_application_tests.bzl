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
    ":rules/apple_verification_test.bzl",
    "apple_verification_test",
)
load(
    ":rules/analysis_target_outputs_test.bzl",
    "analysis_target_outputs_test",
)
load(
    ":rules/common_verification_tests.bzl",
    "archive_contents_test",
    "bitcode_symbol_map_test",
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
    ":rules/linkmap_test.bzl",
    "linkmap_test",
)

def ios_application_test_suite(name = "ios_application"):
    """Test suite for ios_application.

    Args:
        name: The name prefix for all the nested tests
    """

    analysis_target_outputs_test(
        name = "{}_ipa_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        expected_outputs = ["app.ipa"],
        tags = [name],
    )

    # Tests that an app with a mixed target framework compiles
    analysis_target_outputs_test(
        name = "{}_mixed_target_framework_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_fmwk_with_multiple_objc_library_and_swift_library_deps",
        expected_outputs = ["app_with_fmwk_with_multiple_objc_library_and_swift_library_deps.ipa"],
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
        tags = [
            name,
            "manual",  # disabled in oss
        ],
    )

    apple_verification_test(
        name = "{}_codesignopts_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_codesignopts",
        verifier_script = "verifier_scripts/codesignopts_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_fmwk",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_imported_fmwk_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_fmwk",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
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

    # Tests that Swift standard libraries bundled in SwiftSupport have the code
    # signature from Apple.
    archive_contents_test(
        name = "{}_swift_support_codesign_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_swift_dep",
        binary_test_file = "$ARCHIVE_ROOT/SwiftSupport/iphoneos/libswiftCore.dylib",
        codesign_info_contains = [
            "Identifier=com.apple.dt.runtime.swiftCore",
            "Authority=Software Signing",
            "Authority=Apple Code Signing Certification Authority",
            "Authority=Apple Root CA",
            "TeamIdentifier=59GAB85EFG",
        ],
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

    apple_verification_test(
        name = "{}_package_symbols_test".format(name),
        build_type = "simulator",
        env = {
            "BINARY_PATHS": [
                "Payload/app_with_imported_dynamic_fmwk_with_dsym.app/app_with_imported_dynamic_fmwk_with_dsym",
                "Payload/app_with_imported_dynamic_fmwk_with_dsym.app/Frameworks/iOSDynamicFramework.framework/iOSDynamicFramework",
                "Payload/app_with_imported_dynamic_fmwk_with_dsym.app/Frameworks/iOSDynamicFrameworkWithDebugInfo.framework/iOSDynamicFrameworkWithDebugInfo",
            ],
        },
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_dynamic_fmwk_with_dsym",
        verifier_script = "verifier_scripts/symbols_verifier.sh",
        tags = [
            name,
            "manual",  # can't use Starlark transition on --define now
        ],
    )

    archive_contents_test(
        name = "{}_custom_executable_name_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_custom_executable_name",
        contains = ["$BUNDLE_ROOT/app.exe"],
        not_contains = ["$BUNDLE_ROOT/app_with_custom_executable_name"],
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

    dsyms_test(
        name = "{}_dsyms_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        expected_dsyms = ["app.app"],
        tags = [name],
    )

    dsyms_test(
        name = "{}_custom_executable_name_dsyms_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_custom_executable_name",
        expected_dsyms = ["custom_bundle_name.app"],
        expected_binaries = [
            "custom_bundle_name.app.dSYM/Contents/Resources/DWARF/app.exe",
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
            "MinimumOSVersion": "8.0",
            "UIDeviceFamily:0": "1",
        },
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_custom_executable_name_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_custom_executable_name",
        expected_values = {
            "CFBundleExecutable": "app.exe",
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

    # Tests that the archive contains Bitcode symbol maps when Bitcode is
    # enabled.
    bitcode_symbol_map_test(
        name = "{}_archive_contains_bitcode_symbol_maps_test".format(name),
        binary_paths = ["Payload/app.app/app"],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        tags = [name],
    )

    # Tests that the linkmap outputs are produced when `--objc_generate_linkmap`
    # is present.
    linkmap_test(
        name = "{}_linkmap_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app",
        tags = [name],
    )

    # Test that Bitcode was removed from the imported framework when building
    # with Bitcode disabled.
    archive_contents_test(
        name = "{}_imported_dynamic_framework_bitcode_strip_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_imported_dynamic_fmwk_with_bitcode",
        binary_test_file = "$BUNDLE_ROOT/Frameworks/iOSDynamicFrameworkWithBitcode.framework/iOSDynamicFrameworkWithBitcode",
        macho_load_commands_not_contain = ["__LLVM"],
        tags = [name],
    )

    # Test that Bitcode was removed from the Swift standard libraries when building
    # with Bitcode disabled.
    archive_contents_test(
        name = "{}_swift_stdlibs_bitcode_strip_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_swift_dep",
        binary_test_file = "$BUNDLE_ROOT/Frameworks/libswiftCore.dylib",
        macho_load_commands_not_contain = ["__LLVM"],
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
        tags = [
            name,
            # OSS Blocked by b/73547309
            "manual",  # disabled in oss
        ],
    )

    archive_contents_test(
        name = "{}_contains_asan_dylib_device_test".format(name),
        build_type = "device",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.asan_ios_dynamic.dylib",
        ],
        sanitizer = "asan",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_minimal",
        tags = [
            name,
            # OSS Blocked by b/73547309
            "manual",  # disabled in oss
        ],
    )

    archive_contents_test(
        name = "{}_contains_tsan_dylib_device_test".format(name),
        build_type = "simulator",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.tsan_iossim_dynamic.dylib",
        ],
        sanitizer = "tsan",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_minimal",
        tags = [
            name,
            # OSS Blocked by b/73547309
            "manual",  # disabled in oss
        ],
    )

    archive_contents_test(
        name = "{}_contains_ubsan_dylib_simulator_test".format(name),
        build_type = "simulator",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.ubsan_iossim_dynamic.dylib",
        ],
        sanitizer = "ubsan",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_minimal",
        tags = [
            name,
            # OSS Blocked by b/73547309
            "manual",  # disabled in oss
        ],
    )

    archive_contents_test(
        name = "{}_contains_ubsan_dylib_device_test".format(name),
        build_type = "device",
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.ubsan_ios_dynamic.dylib",
        ],
        sanitizer = "ubsan",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_minimal",
        tags = [
            name,
            # OSS Blocked by b/73547309
            "manual",  # disabled in oss
        ],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
