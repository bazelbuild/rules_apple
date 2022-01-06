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

def ios_framework_test_suite(name):
    """Test suite for ios_framework.

    Args:
      name: the base name to be used in things created by this macro
    """
    infoplist_contents_test(
        name = "{}_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:fmwk",
        expected_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "fmwk",
            "CFBundleIdentifier": "com.google.example.framework",
            "CFBundleName": "fmwk",
            "CFBundlePackageType": "FMWK",
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
        macho_load_commands_contain = ["name @rpath/fmwk.framework/fmwk (offset 24)"],
        contains = [
            "$BUNDLE_ROOT/fmwk",
            "$BUNDLE_ROOT/Headers/common.h",
            "$BUNDLE_ROOT/Info.plist",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_app_load_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_bundle_only_fmwks",
        binary_test_file = "$BUNDLE_ROOT/app_with_bundle_only_fmwks",
        macho_load_commands_not_contain = [
            "name @rpath/bundle_only_fmwk.framework/bundle_only_fmwk (offset 24)",
            "name @rpath/generated_ios_dynamic_fmwk.framework/generated_ios_dynamic_fmwk (offset 24)",
        ],
        contains = [
            "$BUNDLE_ROOT/Frameworks/bundle_only_fmwk.framework/bundle_only_fmwk",
            "$BUNDLE_ROOT/Frameworks/bundle_only_fmwk.framework/nonlocalized.plist",
            "$BUNDLE_ROOT/Frameworks/generated_ios_dynamic_fmwk.framework/generated_ios_dynamic_fmwk",
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

    # Tests that different root-level resources with the same name are not
    # deduped between framework and app.
    archive_contents_test(
        name = "{}_same_resource_names_not_deduped".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_same_resource_names_as_framework",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk_with_duplicate_resource_names.framework/Another.plist",
            "$BUNDLE_ROOT/Another.plist",
        ],
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

    # Tests that if frameworks have resource bundles they are only in the
    # framework.
    archive_contents_test(
        name = "{}_resource_bundle_in_framework_stays_in_framework".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_fmwk_with_bundle_resources",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk_min_os_9_0.framework/basic.bundle/basic_bundle.txt",
            "$BUNDLE_ROOT/Frameworks/fmwk_min_os_9_0.framework/basic.bundle/nested/should_be_nested.strings",
        ],
        not_contains = [
            "$BUNDLE_ROOT/basic.bundle/basic_bundle.txt",
            "$BUNDLE_ROOT/basic.bundle/nested/should_be_nested.strings",
        ],
        tags = [name],
    )

    # Tests that if frameworks and applications have different minimum versions
    # the assets are still only in the framework.
    archive_contents_test(
        name = "{}_resources_in_framework_stays_in_framework_with_app_with_lower_min_os_version".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_8_0_minimum_and_9_0_fmwk",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk_min_os_9_0.framework/basic.bundle/basic_bundle.txt",
            "$BUNDLE_ROOT/Frameworks/fmwk_min_os_9_0.framework/basic.bundle/nested/should_be_nested.strings",
        ],
        not_contains = [
            "$BUNDLE_ROOT/basic.bundle/basic_bundle.txt",
            "$BUNDLE_ROOT/basic.bundle/nested/should_be_nested.strings",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_resources_in_framework_stays_in_framework_with_app_with_higher_min_os_version".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_9_0_minimum_and_8_0_fmwk",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk_min_os_8_0.framework/basic.bundle/basic_bundle.txt",
            "$BUNDLE_ROOT/Frameworks/fmwk_min_os_8_0.framework/basic.bundle/nested/should_be_nested.strings",
        ],
        not_contains = [
            "$BUNDLE_ROOT/basic.bundle/basic_bundle.txt",
            "$BUNDLE_ROOT/basic.bundle/nested/should_be_nested.strings",
        ],
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
        binary_test_file = "$BUNDLE_ROOT/Frameworks/fmwk.framework/fmwk",
        binary_test_architecture = "x86_64",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk_with_fmwk.framework/fmwk_with_fmwk",
            "$BUNDLE_ROOT/Frameworks/fmwk_with_fmwk.framework/Info.plist",
            "$BUNDLE_ROOT/Frameworks/fmwk.framework/nonlocalized.plist",
            "$BUNDLE_ROOT/Frameworks/fmwk.framework/fmwk",
            "$BUNDLE_ROOT/Frameworks/fmwk.framework/Info.plist",
        ],
        not_contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk_with_fmwk.framework/Frameworks/",
            "$BUNDLE_ROOT/Frameworks/fmwk_with_fmwk.framework/nonlocalized.plist",
            "$BUNDLE_ROOT/framework_resources/nonlocalized.plist",
        ],
        binary_contains_symbols = ["_anotherFunctionShared"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_app_includes_transitive_framework_symbols_not_in_app".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_fmwk_with_fmwk",
        binary_test_file = "$BUNDLE_ROOT/app_with_fmwk_with_fmwk",
        binary_test_architecture = "x86_64",
        binary_not_contains_symbols = ["_anotherFunctionShared"],
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

    # Verifies that, when an extension depends on a framework with different
    # minimum_os, symbol subtraction still occurs.
    archive_contents_test(
        name = "{}_symbols_present_in_framework".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_8_0_min_version",
        binary_test_file = "$BUNDLE_ROOT/Frameworks/fmwk_8_0_minimum.framework/fmwk_8_0_minimum",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_anotherFunctionShared"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_symbols_not_in_extension".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_8_0_min_version",
        binary_test_file = "$BUNDLE_ROOT/PlugIns/ext_with_9_0_min_version.appex/ext_with_9_0_min_version",
        binary_test_architecture = "x86_64",
        binary_not_contains_symbols = ["_anotherFunctionShared"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_static_framework_contains_swiftinterface".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_static_framework",
        contains = [
            "$BUNDLE_ROOT/Headers/swift_framework_lib.h",
            "$BUNDLE_ROOT/Modules/swift_framework_lib.swiftmodule/x86_64.swiftdoc",
            "$BUNDLE_ROOT/Modules/swift_framework_lib.swiftmodule/x86_64.swiftinterface",
        ],
        not_contains = [
            "$BUNDLE_ROOT/Modules/swift_framework_lib.swiftmodule/x86_64.swiftmodule",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_angle_bracketed_import_in_umbrella_header".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:objc_static_framework",
        text_test_file = "$BUNDLE_ROOT/Headers/objc_static_framework.h",
        text_test_values = [
            "#import <objc_static_framework/common.h>",
        ],
        tags = [name],
    )

    # Verify ios_framework listed as a runtime_dep of an objc_library gets
    # propagated to ios_application bundle.
    archive_contents_test(
        name = "{}_includes_objc_library_ios_framework_runtime_dep".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_objc_library_dep_with_ios_framework_runtime_dep",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk_8_0_minimum.framework/fmwk_8_0_minimum",
        ],
        tags = [name],
    )

    # Verify nested frameworks from objc_library targets get propagated to
    # ios_application bundle.
    archive_contents_test(
        name = "{}_includes_multiple_objc_library_ios_framework_deps".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_objc_lib_dep_with_inner_lib_with_runtime_dep_fmwk",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk.framework/fmwk",
            "$BUNDLE_ROOT/Frameworks/fmwk_8_0_minimum.framework/fmwk_8_0_minimum",
            "$BUNDLE_ROOT/Frameworks/fmwk_with_fmwk.framework/fmwk_with_fmwk",
        ],
        tags = [name],
    )

    # Verify ios_framework listed as a runtime_dep of an objc_library does not
    # get linked to top-level application (Mach-O LC_LOAD_DYLIB commands).
    archive_contents_test(
        name = "{}_does_not_load_bundled_ios_framework_runtime_dep".format(name),
        build_type = "device",
        binary_test_file = "$BUNDLE_ROOT/app_with_objc_lib_dep_with_inner_lib_with_runtime_dep_fmwk",
        macho_load_commands_not_contain = [
            "name @rpath/fmwk.framework/fmwk (offset 24)",
            "name @rpath/fmwk_8_0_minimum.framework/fmwk_8_0_minimum (offset 24)",
            "name @rpath/fmwk_with_fmwk.framework/fmwk_with_fmwk (offset 24)",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_objc_lib_dep_with_inner_lib_with_runtime_dep_fmwk",
        tags = [name],
    )

    # Verify that both ios_framework listed as a load time and runtime_dep
    # get bundled to top-level application, and runtime does not get linked.
    archive_contents_test(
        name = "{}_bundles_both_load_and_runtime_framework_dep".format(name),
        build_type = "device",
        binary_test_file = "$BUNDLE_ROOT/app_with_load_and_runtime_framework_dep",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk.framework/fmwk",
            "$BUNDLE_ROOT/Frameworks/fmwk_8_0_minimum.framework/fmwk_8_0_minimum",
        ],
        macho_load_commands_contain = [
            "name @rpath/fmwk.framework/fmwk (offset 24)",
        ],
        macho_load_commands_not_contain = [
            "name @rpath/fmwk_8_0_minimum.framework/fmwk_8_0_minimum (offset 24)",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_load_and_runtime_framework_dep",
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
