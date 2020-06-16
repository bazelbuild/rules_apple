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

"""ios_framework Starlark tests."""

load(
    ":rules/common_verification_tests.bzl",
    "archive_contents_test",
)
load(
    ":rules/infoplist_contents_test.bzl",
    "infoplist_contents_test",
)

def ios_framework_test_suite():
    """Test suite for ios_framework."""
    name = "ios_framework"

    infoplist_contents_test(
        name = "{}_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:fmwk",
        expected_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "fmwk",
            "CFBundleIdentifier": "com.google.example.framework",
            "CFBundleName": "fmwk",
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

    archive_contents_test(
        name = "{}_archive_contents_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:fmwk",
        binary_test_file = "$BUNDLE_ROOT/fmwk",
        binary_test_architecture = "x86_64",
        macho_load_commands_contain = ["name @rpath/fmwk.framework/fmwk (offset 24)"],
        contains = [
            "$BUNDLE_ROOT/fmwk",
            "$BUNDLE_ROOT/Headers/common.h",
            "$BUNDLE_ROOT/Info.plist",
        ],
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_no_version_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:fmwk_no_version",
        not_expected_keys = ["CFBundleShortVersionString", "CFBundleVersion"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_extensions_do_not_duplicate_frameworks_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_ext_and_fmwk_provisioned",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk_with_provisioning.framework/fmwk_with_provisioning",
            "$BUNDLE_ROOT/Frameworks/fmwk_with_provisioning.framework/Info.plist",
            "$BUNDLE_ROOT/PlugIns/ext_with_fmwk_provisioned.appex",
        ],
        not_contains = ["$BUNDLE_ROOT/PlugIns/ext_with_fmwk_provisioned.appex/Frameworks"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_extensions_framework_propagates_to_app_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_ext_with_fmwk_provisioned",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk_with_provisioning.framework/fmwk_with_provisioning",
            "$BUNDLE_ROOT/Frameworks/fmwk_with_provisioning.framework/Info.plist",
            "$BUNDLE_ROOT/PlugIns/ext_with_fmwk_provisioned.appex",
        ],
        not_contains = ["$BUNDLE_ROOT/PlugIns/ext_with_fmwk_provisioned.appex/Frameworks/fmwk_with_provisioning.framework/fmwk_with_provisioning"],
        tags = [name],
    )

    # Tests that resources that both apps and frameworks depend on are present
    # in the .framework directory and app directory if both have explicit owners
    # for the resources.
    archive_contents_test(
        name = "{}_shared_resources_with_explicit_owners_in_framework_and_app".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_framework_and_shared_resources",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk_with_resources.framework/Another.plist",
            "$BUNDLE_ROOT/Another.plist",
        ],
        tags = [name],
    )

    # Tests that resources that both apps and frameworks depend on are present
    # in the .framework directory only.
    archive_contents_test(
        name = "{}_resources_in_framework_stays_in_framework".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_framework_and_resources",
        contains = ["$BUNDLE_ROOT/Frameworks/fmwk_with_resources.framework/Another.plist"],
        not_contains = ["$BUNDLE_ROOT/another.plist"],
        tags = [name],
    )

    # Tests that libraries that both apps and frameworks depend only have symbols
    # present in the framework.
    archive_contents_test(
        name = "{}_symbols_from_shared_library_in_framework".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_framework_and_resources",
        binary_test_architecture = "x86_64",
        binary_test_file = "$BUNDLE_ROOT/Frameworks/fmwk_with_resources.framework/fmwk_with_resources",
        binary_contains_symbols = ["_dontCallMeShared"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_symbols_from_shared_library_not_in_application".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_framework_and_resources",
        binary_test_file = "$BUNDLE_ROOT/app_with_framework_and_resources",
        binary_test_architecture = "x86_64",
        binary_not_contains_symbols = ["_dontCallMeShared"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_app_includes_transitive_framework_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_fmwk_with_fmwk",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk_with_fmwk.framework/fmwk_with_fmwk",
            "$BUNDLE_ROOT/Frameworks/fmwk_with_fmwk.framework/Info.plist",
            "$BUNDLE_ROOT/Frameworks/fmwk.framework/fmwk",
            "$BUNDLE_ROOT/Frameworks/fmwk.framework/Info.plist",
        ],
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_multiple_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:fmwk_multiple_infoplists",
        expected_values = {
            "AnotherKey": "AnotherValue",
            "CFBundleExecutable": "fmwk_multiple_infoplists",
        },
        tags = [name],
    )

    archive_contents_test(
        name = "{}_exported_symbols_list_stripped_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:fmwk_stripped",
        binary_test_file = "$BUNDLE_ROOT/fmwk_stripped",
        compilation_mode = "opt",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_anotherFunctionShared"],
        binary_not_contains_symbols = ["_dontCallMeShared", "_anticipatedDeadCode"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_two_exported_symbols_lists_stripped_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:fmwk_stripped_two_exported_symbol_lists",
        binary_test_file = "$BUNDLE_ROOT/fmwk_stripped_two_exported_symbol_lists",
        compilation_mode = "opt",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_anotherFunctionShared", "_dontCallMeShared"],
        binary_not_contains_symbols = ["_anticipatedDeadCode"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_exported_symbols_list_dead_stripped_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:fmwk_dead_stripped",
        binary_test_file = "$BUNDLE_ROOT/fmwk_dead_stripped",
        compilation_mode = "opt",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_anotherFunctionShared"],
        binary_not_contains_symbols = ["_dontCallMeShared", "_anticipatedDeadCode"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_two_exported_symbols_lists_dead_stripped_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:fmwk_dead_stripped_two_exported_symbol_lists",
        binary_test_file = "$BUNDLE_ROOT/fmwk_dead_stripped_two_exported_symbol_lists",
        compilation_mode = "opt",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_anotherFunctionShared", "_dontCallMeShared"],
        binary_not_contains_symbols = ["_anticipatedDeadCode"],
        tags = [name],
    )

    # Test that if an ios_framework target depends on a prebuilt framework, that
    # the inner framework is propagated up to the application and not nested in
    # the outer framework.
    archive_contents_test(
        name = "{}_prebuild_framework_propagated_to_application".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_inner_and_outer_fmwk",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk_with_imported_fmwk.framework/fmwk_with_imported_fmwk",
            "$BUNDLE_ROOT/Frameworks/iOSDynamicFramework.framework/iOSDynamicFramework",
        ],
        not_contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk_with_imported_fmwk.framework/Frameworks",
        ],
        tags = [name],
    )

    # Test that if an ios_framework target depends on a prebuilt static framework,
    # the inner framework is propagated up to the application and not nested in
    # the outer framework.
    archive_contents_test(
        name = "{}_prebuild_static_framework_included_in_outer_framework".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_inner_and_outer_static_fmwk",
        binary_test_file = "$BUNDLE_ROOT/Frameworks/fmwk_with_imported_static_fmwk.framework/fmwk_with_imported_static_fmwk",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["-[ObjectiveCSharedClass doSomethingShared]"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_prebuild_static_framework_not_included_in_app".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_inner_and_outer_static_fmwk",
        binary_test_file = "$BUNDLE_ROOT/app_with_inner_and_outer_static_fmwk",
        binary_test_architecture = "x86_64",
        binary_not_contains_symbols = ["-[ObjectiveCSharedClass doSomethingShared]"],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
