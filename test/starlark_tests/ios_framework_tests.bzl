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
    "//apple/build_settings:build_settings.bzl",
    "build_settings_labels",
)
load(
    "//test/starlark_tests/rules:analysis_failure_message_test.bzl",
    "analysis_failure_message_test",
)
load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "archive_contents_test",
)
load(
    "//test/starlark_tests/rules:infoplist_contents_test.bzl",
    "infoplist_contents_test",
)
load(
    "//test/starlark_tests/rules:validation_action_artifact_test.bzl",
    "validation_output_contents_test",
)
load(
    ":common.bzl",
    "common",
)

visibility("private")

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
            "MinimumOSVersion": common.min_os_ios.min_deployment_target,
            "UIDeviceFamily:0": "1",
            "UIDeviceFamily:1": "2",
        },
        tags = [name],
    )

    archive_contents_test(
        name = "{}_archive_contents_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:fmwk",
        binary_test_file = "$BUNDLE_ROOT/fmwk",
        macho_load_commands_contain = [
            "name @rpath/fmwk.framework/fmwk (offset 24)",
            "path @executable_path/Frameworks (offset 12)",
            "path @loader_path/Frameworks (offset 12)",
        ],
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
            "$BUNDLE_ROOT/Frameworks/fmwk_min_os_baseline_with_bundle.framework/basic.bundle/basic_bundle.txt",
            "$BUNDLE_ROOT/Frameworks/fmwk_min_os_baseline_with_bundle.framework/basic.bundle/nested/should_be_nested.strings",
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
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_nplus1_min_os_and_baseline_fmwk",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk_min_os_baseline_with_bundle.framework/basic.bundle/basic_bundle.txt",
            "$BUNDLE_ROOT/Frameworks/fmwk_min_os_baseline_with_bundle.framework/basic.bundle/nested/should_be_nested.strings",
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
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk_with_imported_static_fmwk.framework/SharedStaticFrameworkResources.bundle/sample.plist",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_prebuild_static_framework_not_included_in_app".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_inner_and_outer_static_fmwk",
        binary_test_file = "$BUNDLE_ROOT/app_with_inner_and_outer_static_fmwk",
        binary_test_architecture = "x86_64",
        binary_not_contains_symbols = ["-[ObjectiveCSharedClass doSomethingShared]"],
        not_contains = [
            "$BUNDLE_ROOT/SharedStaticFrameworkResources.bundle",
        ],
        tags = [name],
    )

    # Verifies that, when an extension depends on a framework with different
    # minimum_os, symbol subtraction still occurs.
    archive_contents_test(
        name = "{}_symbols_present_in_framework".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_min_os_baseline",
        binary_test_file = "$BUNDLE_ROOT/Frameworks/fmwk_min_os_baseline.framework/fmwk_min_os_baseline",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_anotherFunctionShared"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_symbols_not_in_extension".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_min_os_baseline",
        binary_test_file = "$BUNDLE_ROOT/PlugIns/ext_min_os_nplus1.appex/ext_min_os_nplus1",
        binary_test_architecture = "x86_64",
        binary_not_contains_symbols = ["_anotherFunctionShared"],
        tags = [name],
    )

    # Verifies an ios_framework listed both as a load time dependency, and dependency of another
    # ios_framework target listed as a runtime dependency:
    #
    # - Framework is bundled at the top-level application.
    # - Framework is linked to the application binary.
    # - Framework does not cause duplicate files error due being listed at two different targets:
    #     1. As a load time dependency at the ios_application target using `frameworks`.
    #     2. As a load time dependency to a runtime ios_framework target using `frameworks`.
    #
    # - Runtime framework is bundled at the top-level application.
    # - Runtime framework is not linked to the application binary.
    archive_contents_test(
        name = "{}_bundles_both_load_and_runtime_framework_dep_without_duplicate_files_errors".format(name),
        build_type = "device",
        binary_test_file = "$BUNDLE_ROOT/app_with_fmwk_and_ext_with_objc_lib_with_nested_ios_framework",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk.framework/fmwk",
            "$BUNDLE_ROOT/Frameworks/fmwk_with_fmwk.framework/fmwk_with_fmwk",
        ],
        macho_load_commands_contain = [
            "name @rpath/fmwk.framework/fmwk (offset 24)",
        ],
        macho_load_commands_not_contain = [
            "name @rpath/fmwk_with_fmwk.framework/fmwk_with_fmwk (offset 24)",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_fmwk_and_ext_with_objc_lib_with_nested_ios_framework",
        tags = [name],
    )
    archive_contents_test(
        name = "{}_bundles_both_load_and_runtime_framework_dep_without_duplicate_files_errors_with_tree_artifacts".format(name),
        build_type = "device",
        binary_test_file = "$BUNDLE_ROOT/app_with_fmwk_and_ext_with_objc_lib_with_nested_ios_framework",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk.framework/fmwk",
            "$BUNDLE_ROOT/Frameworks/fmwk_with_fmwk.framework/fmwk_with_fmwk",
        ],
        macho_load_commands_contain = [
            "name @rpath/fmwk.framework/fmwk (offset 24)",
        ],
        macho_load_commands_not_contain = [
            "name @rpath/fmwk_with_fmwk.framework/fmwk_with_fmwk (offset 24)",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_fmwk_and_ext_with_objc_lib_with_nested_ios_framework",
        build_settings = {
            build_settings_labels.use_tree_artifacts_outputs: "True",
        },
        tags = [name],
    )

    # Tests that if frameworks and applications have different minimum versions that a user
    # actionable error is raised.
    analysis_failure_message_test(
        name = "{}_app_with_baseline_min_os_and_nplus1_fmwk_produces_error".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_baseline_min_os_and_nplus1_fmwk",
        expected_error = """
ERROR: minimum_os_version {framework_version} on the framework //test/starlark_tests/targets_under_test/ios:fmwk_min_os_nplus1 is too high compared to //test/starlark_tests/targets_under_test/ios:app_with_baseline_min_os_and_nplus1_fmwk's minimum_os_version of {app_version}

Please address the minimum_os_version on framework //test/starlark_tests/targets_under_test/ios:fmwk_min_os_nplus1 to match //test/starlark_tests/targets_under_test/ios:app_with_baseline_min_os_and_nplus1_fmwk's minimum_os_version.
""".format(app_version = common.min_os_ios.min_deployment_target, framework_version = common.min_os_ios.nplus1),
        tags = [name],
    )

    # Tests that if data-loaded frameworks and applications have different minimum versions that a
    # user actionable error is raised.
    analysis_failure_message_test(
        name = "{}_app_with_baseline_min_os_and_nplus1_transitive_data_fmwk_produces_error".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_nplus1_framework_objc_lib_using_data",
        expected_error = """
ERROR: minimum_os_version {framework_version} on the framework //test/starlark_tests/targets_under_test/ios:fmwk_min_os_nplus1 is too high compared to //test/starlark_tests/targets_under_test/ios:app_with_nplus1_framework_objc_lib_using_data's minimum_os_version of {app_version}

Please address the minimum_os_version on framework //test/starlark_tests/targets_under_test/ios:fmwk_min_os_nplus1 to match //test/starlark_tests/targets_under_test/ios:app_with_nplus1_framework_objc_lib_using_data's minimum_os_version.
""".format(app_version = common.min_os_ios.min_deployment_target, framework_version = common.min_os_ios.nplus1),
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_base_bundle_id_derived_bundle_id_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:fmwk_with_base_bundle_id_derived_bundle_id",
        expected_values = {
            "CFBundleIdentifier": "com.bazel.app.example.fmwk-with-base-bundle-id-derived-bundle-id",
        },
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_ambiguous_base_bundle_id_derived_bundle_id_fail_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:fmwk_with_ambiguous_base_bundle_id_derived_bundle_id",
        expected_error = """
Error: Found a `bundle_id` provided with `base_bundle_id`. This is ambiguous.

Please remove one of the two from your rule definition.
""",
        tags = [name],
    )

    # Test framework with App Intents generates and bundles Metadata.appintents bundle.
    archive_contents_test(
        name = "{}_with_app_intents_contains_app_intents_metadata_bundle_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:framework_with_app_intents",
        contains = [
            "$BUNDLE_ROOT/Metadata.appintents/extract.actionsdata",
            "$BUNDLE_ROOT/Metadata.appintents/version.json",
        ],
        tags = [name],
    )

    validation_output_contents_test(
        name = "{}_app_intents_conformances_validation_execution_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:framework_with_app_intents",
        validation_file_name = "framework_with_app_intents_app_intents_conformances_validation.txt",
        allow_empty = True,
        tags = [name],
    )
    validation_output_contents_test(
        name = "{}_framework_defined_app_intent_aspect_validation_execution_contents_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:framework_with_app_intents",
        validation_file_name = "framework_defined_app_intent_app_intents_validation.txt",
        expected_contents = [
            "FrameworkDefinedHelloWorldIntents",
        ],
        tags = [name],
    )

    # Test framework with multi-module App Intents generates and bundles Metadata.appintents bundle.
    archive_contents_test(
        name = "{}_with_multi_module_app_intents_contains_app_intents_metadata_bundle_test".format(name),
        build_settings = {
            build_settings_labels.enable_wip_features: "True",
        },
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:framework_with_multi_module_app_intents",
        contains = [
            "$BUNDLE_ROOT/Metadata.appintents/extract.actionsdata",
            "$BUNDLE_ROOT/Metadata.appintents/version.json",
        ],
        tags = [name],
    )

    validation_output_contents_test(
        name = "{}_with_multi_module_app_intents_conformances_validation_execution_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:framework_with_multi_module_app_intents",
        validation_file_name = "framework_with_multi_module_app_intents_app_intents_conformances_validation.txt",
        allow_empty = True,
        tags = [name],
    )
    validation_output_contents_test(
        name = "{}_with_multi_module_app_intents_framework_defined_app_intent_with_dependency_aspect_validation_execution_contents_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:framework_with_multi_module_app_intents",
        validation_file_name = "framework_defined_app_intent_with_dependency_app_intents_validation.txt",
        expected_contents = [
            "FrameworkDefinedHelloWorldIntents",
        ],
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_app_intents_within_load_deferred_framework_fail_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_load_deferred_framework_app_intents",
        expected_error = "An App Intents metadata bundle was found in the following framework that is not directly loaded by an app/extension:",
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
