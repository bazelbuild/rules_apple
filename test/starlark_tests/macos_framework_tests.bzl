# Copyright 2026 The Bazel Authors. All rights reserved.
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

"""macos_framework Starlark tests."""

load(
    "//apple/build_settings:build_settings.bzl",
    "build_settings_labels",
)
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
    "//test/starlark_tests/rules:infoplist_contents_test.bzl",
    "infoplist_contents_test",
)
load(
    ":common.bzl",
    "common",
)

visibility("private")

def macos_framework_test_suite(name):
    """Test suite for macos_framework.

    Args:
      name: the base name to be used in things created by this macro
    """
    infoplist_contents_test(
        name = "{}_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:fmwk",
        expected_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "fmwk",
            "CFBundleIdentifier": "com.google.example.framework",
            "CFBundleName": "fmwk",
            "CFBundlePackageType": "FMWK",
            "CFBundleSupportedPlatforms:0": "MacOSX",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "macosx",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "macosx*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "LSMinimumSystemVersion": common.min_os_macos.min_deployment_target,
        },
        tags = [name],
    )

    archive_contents_test(
        name = "{}_archive_contents_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:fmwk",
        binary_test_file = "$BUNDLE_ROOT/Versions/A/fmwk",
        macho_load_commands_contain = [
            "name @rpath/fmwk.framework/Versions/A/fmwk (offset 24)",
            "path @executable_path/../Frameworks (offset 12)",
            "path @loader_path/Frameworks (offset 12)",
        ],
        contains = [
            "$BUNDLE_ROOT/Versions/A/fmwk",
            "$BUNDLE_ROOT/Versions/A/Resources/Info.plist",
            "$BUNDLE_ROOT/Versions/Current",
            "$BUNDLE_ROOT/fmwk",
            "$BUNDLE_ROOT/Resources",
        ],
        tags = [name],
    )

    analysis_failure_message_with_tree_artifact_outputs_test(
        name = "{}_failing_with_tree_artifacts_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:fmwk",
        expected_error = "does not support versioned frameworks with the bundle outputs feature/build setting without disabling legacy signing",
        tags = [name],
    )

    # Tests that a macos_framework builds fine without any version info
    # since it isn't required.
    infoplist_contents_test(
        name = "{}_no_version_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:fmwk_no_version",
        not_expected_keys = ["CFBundleShortVersionString", "CFBundleVersion"],
        tags = [name],
    )

    # Verify that dynamic frameworks are embedded in the application package, but not
    # duplicated in any embedded extension packages.
    archive_contents_test(
        name = "{}_extensions_do_not_duplicate_frameworks_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_ext_and_fmwk",
        contains = [
            "$BUNDLE_ROOT/Contents/Frameworks/fmwk.framework/Versions/A/fmwk",
            "$BUNDLE_ROOT/Contents/Frameworks/fmwk.framework/Versions/A/Resources/Info.plist",
            "$BUNDLE_ROOT/Contents/PlugIns/ext_with_fmwk.appex",
        ],
        not_contains = ["$BUNDLE_ROOT/Contents/PlugIns/ext_with_fmwk.appex/Contents/Frameworks"],
        tags = [name],
    )

    # Verify that dynamic frameworks depended on by an extension are still packaged in the parent
    # application bundle's Frameworks directory, not the extension bundle's PlugIns directory.
    archive_contents_test(
        name = "{}_extensions_framework_propagates_to_app_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_ext_with_fmwk",
        contains = [
            "$BUNDLE_ROOT/Contents/Frameworks/fmwk.framework/Versions/A/fmwk",
            "$BUNDLE_ROOT/Contents/Frameworks/fmwk.framework/Versions/A/Resources/Info.plist",
            "$BUNDLE_ROOT/Contents/PlugIns/ext_with_fmwk.appex",
        ],
        not_contains = ["$BUNDLE_ROOT/Contents/PlugIns/ext_with_fmwk.appex/Contents/Frameworks"],
        tags = [name],
    )

    # Verify that resources with the same name from the framework and application do not get
    # deduplicated.
    archive_contents_test(
        name = "{}_same_resource_names_not_deduped".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_same_resource_names_as_framework",
        contains = [
            "$BUNDLE_ROOT/Contents/Frameworks/fmwk_with_duplicate_resource_names.framework/Versions/A/Resources/Another.plist",
            "$BUNDLE_ROOT/Contents/Resources/Another.plist",
        ],
        tags = [name],
    )

    # Verify that resource bundles from transitive dependencies of the framework remain packaged
    # inside the framework's bundle rather than being promoted to the parent application's bundle.
    archive_contents_test(
        name = "{}_resource_bundle_in_framework_stays_in_framework".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_fmwk_with_bundle_resources",
        contains = [
            "$BUNDLE_ROOT/Contents/Frameworks/fmwk_min_os_baseline_with_bundle.framework/Versions/A/Resources/basic.bundle/basic_bundle.txt",
            "$BUNDLE_ROOT/Contents/Frameworks/fmwk_min_os_baseline_with_bundle.framework/Versions/A/Resources/basic.bundle/nested/should_be_nested.strings",
        ],
        not_contains = [
            "$BUNDLE_ROOT/Contents/Resources/basic.bundle/basic_bundle.txt",
            "$BUNDLE_ROOT/Contents/Resources/basic.bundle/nested/should_be_nested.strings",
        ],
        tags = [name],
    )

    # Verify that resources with explicit owners on both the framework and the application are NOT
    # deduplicated and exist in both targets.
    archive_contents_test(
        name = "{}_shared_resources_with_explicit_owners_in_framework_and_app".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_framework_and_shared_resources",
        contains = [
            "$BUNDLE_ROOT/Contents/Frameworks/fmwk_with_resources.framework/Versions/A/Resources/Another.plist",
            "$BUNDLE_ROOT/Contents/Resources/Another.plist",
        ],
        tags = [name],
    )

    # Verify that symbols from a library depended on by the framework are present in the framework's
    # binary, but NOT in the application's binary.
    archive_contents_test(
        name = "{}_symbols_from_shared_library_in_framework".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_framework_and_resources",
        cpus = {"macos_cpus": ["arm64"]},
        binary_test_architecture = "arm64",
        binary_test_file = "$BUNDLE_ROOT/Contents/Frameworks/fmwk_with_resources.framework/Versions/A/fmwk_with_resources",
        binary_contains_symbols = ["_dontCallMeShared"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_symbols_from_shared_library_not_in_application".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_framework_and_resources",
        cpus = {"macos_cpus": ["arm64"]},
        binary_test_file = "$BUNDLE_ROOT/Contents/MacOS/app_with_framework_and_resources",
        binary_test_architecture = "arm64",
        binary_not_contains_symbols = ["_dontCallMeShared"],
        tags = [name],
    )

    # Verify that dynamic frameworks transitively depended on by another dynamic framework are
    # packaged in the parent application bundle's Frameworks directory.
    archive_contents_test(
        name = "{}_app_includes_transitive_framework_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_fmwk_with_fmwk",
        cpus = {"macos_cpus": ["arm64"]},
        binary_test_file = "$BUNDLE_ROOT/Contents/Frameworks/fmwk.framework/Versions/A/fmwk",
        binary_test_architecture = "arm64",
        contains = [
            "$BUNDLE_ROOT/Contents/Frameworks/fmwk_with_fmwk.framework/Versions/A/fmwk_with_fmwk",
            "$BUNDLE_ROOT/Contents/Frameworks/fmwk_with_fmwk.framework/Versions/A/Resources/Info.plist",
            "$BUNDLE_ROOT/Contents/Frameworks/fmwk.framework/Versions/A/Resources/nonlocalized.plist",
            "$BUNDLE_ROOT/Contents/Frameworks/fmwk.framework/Versions/A/fmwk",
            "$BUNDLE_ROOT/Contents/Frameworks/fmwk.framework/Versions/A/Resources/Info.plist",
        ],
        not_contains = [
            "$BUNDLE_ROOT/Contents/Frameworks/fmwk_with_fmwk.framework/Versions/A/Frameworks/",
            "$BUNDLE_ROOT/Contents/Frameworks/fmwk_with_fmwk.framework/Versions/A/Resources/nonlocalized.plist",
        ],
        binary_contains_symbols = ["_anotherFunctionShared"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_app_includes_transitive_framework_symbols_not_in_app".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_fmwk_with_fmwk",
        cpus = {"macos_cpus": ["arm64"]},
        binary_test_file = "$BUNDLE_ROOT/Contents/MacOS/app_with_fmwk_with_fmwk",
        binary_test_architecture = "arm64",
        binary_not_contains_symbols = ["_anotherFunctionShared"],
        tags = [name],
    )

    # Tests that multiple infoplists can be merged into the framework's plist.
    infoplist_contents_test(
        name = "{}_multiple_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:fmwk_multiple_infoplists",
        expected_values = {
            "AnotherKey": "AnotherValue",
            "CFBundleExecutable": "fmwk_multiple_infoplists",
        },
        tags = [name],
    )

    # Tests that the exported_symbols_lists attribute is respected and dead-code stripping occurs,
    # retaining only the exported symbols in an opt build.
    archive_contents_test(
        name = "{}_exported_symbols_list_stripped_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:fmwk_stripped",
        cpus = {"macos_cpus": ["arm64"]},
        binary_test_file = "$BUNDLE_ROOT/Versions/A/fmwk_stripped",
        compilation_mode = "opt",
        binary_test_architecture = "arm64",
        binary_contains_symbols = ["_anotherFunctionShared"],
        binary_not_contains_symbols = ["_dontCallMeShared", "_anticipatedDeadCode"],
        tags = [name],
    )

    # Tests that the exported_symbols_lists attribute is respected and dead-code stripping occurs
    # when using -dead_strip in linkopts, retaining only the exported symbols in an opt build.
    archive_contents_test(
        name = "{}_exported_symbols_list_dead_stripped_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:fmwk_dead_stripped",
        cpus = {"macos_cpus": ["arm64"]},
        binary_test_file = "$BUNDLE_ROOT/Versions/A/fmwk_dead_stripped",
        compilation_mode = "opt",
        binary_test_architecture = "arm64",
        binary_contains_symbols = ["_anotherFunctionShared"],
        binary_not_contains_symbols = ["_dontCallMeShared", "_anticipatedDeadCode"],
        tags = [name],
    )

    # Verify that prebuilt dynamic frameworks depended on by a dynamic framework propagate to the
    # parent application.
    archive_contents_test(
        name = "{}_prebuild_framework_propagated_to_application".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_inner_and_outer_fmwk",
        contains = [
            "$BUNDLE_ROOT/Contents/Frameworks/fmwk_with_imported_fmwk.framework/Versions/A/fmwk_with_imported_fmwk",
            "$BUNDLE_ROOT/Contents/Frameworks/generated_macos_dynamic_versioned_fmwk.framework/Versions/A/generated_macos_dynamic_versioned_fmwk",
        ],
        not_contains = [
            "$BUNDLE_ROOT/Contents/Frameworks/fmwk_with_imported_fmwk.framework/Versions/A/Frameworks",
        ],
        tags = [name],
    )

    # Tests that if frameworks and applications have different minimum versions that a user
    # actionable error is raised.
    analysis_failure_message_test(
        name = "{}_app_with_baseline_min_os_and_nplus1_fmwk_produces_error".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_baseline_min_os_and_nplus1_fmwk",
        expected_error = """
ERROR: minimum_os_version {framework_version} on the framework //test/starlark_tests/targets_under_test/macos:fmwk_min_os_nplus1 is too high compared to //test/starlark_tests/targets_under_test/macos:app_with_baseline_min_os_and_nplus1_fmwk's minimum_os_version of {app_version}

Please address the minimum_os_version on framework //test/starlark_tests/targets_under_test/macos:fmwk_min_os_nplus1 to match //test/starlark_tests/targets_under_test/macos:app_with_baseline_min_os_and_nplus1_fmwk's minimum_os_version.
""".format(app_version = common.min_os_macos.min_deployment_target, framework_version = common.min_os_macos.nplus1),
        tags = [name],
    )

    # Test framework with App Intents generates and bundles Metadata.appintents bundle.
    archive_contents_test(
        name = "{}_with_app_intents_contains_app_intents_metadata_bundle_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:framework_with_app_intents",
        contains = [
            "$BUNDLE_ROOT/Versions/A/Resources/Metadata.appintents/extract.actionsdata",
            "$BUNDLE_ROOT/Versions/A/Resources/Metadata.appintents/version.json",
        ],
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
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_multi_module_framework_app_intents",
        contains = [
            "$BUNDLE_ROOT/Contents/Resources/Metadata.appintents/extract.actionsdata",
            "$BUNDLE_ROOT/Contents/Resources/Metadata.appintents/version.json",
        ],
        tags = [name],
    )

    # Test that an app intents within load deferred framework produces an actionable error.
    analysis_failure_message_test(
        name = "{}_app_intents_within_load_deferred_framework_fail_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_load_deferred_framework_app_intents",
        expected_error = "An App Intents metadata bundle was found in the following framework that is not directly loaded by an app/extension:",
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
