# Copyright 2025 The Bazel Authors. All rights reserved.
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

"""watchos_framework Starlark tests."""

load(
    "//test/starlark_tests:common.bzl",
    "common",
)
load(
    "//test/starlark_tests/rules:analysis_failure_message_test.bzl",
    "analysis_failure_message_test",
)
load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "archive_contents_test",
    "binary_contents_test",
)
load(
    "//test/starlark_tests/rules:infoplist_contents_test.bzl",
    "infoplist_contents_test",
)

visibility("private")

def watchos_framework_test_suite(name):
    """Test suite for watchos_framework.

    Args:
      name: the base name to be used in things created by this macro
    """

    infoplist_contents_test(
        name = "{}_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:fmwk",
        expected_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "fmwk",
            "CFBundleIdentifier": "com.google.example.framework",
            "CFBundleName": "fmwk",
            "CFBundlePackageType": "FMWK",
            "CFBundleSupportedPlatforms:0": "WatchSimulator*",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "watchsimulator*",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "watchsimulator*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "MinimumOSVersion": common.min_os_watchos.requires_single_target_app,
            "UIDeviceFamily:0": "4",
        },
        tags = [name],
    )

    # Tests that the bundled .framework contains the expected files.
    archive_contents_test(
        name = "{}_contains_expected_files".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:fmwk",
        contains = [
            "$BUNDLE_ROOT/fmwk",
            "$BUNDLE_ROOT/Info.plist",
        ],
        tags = [name],
    )

    # Tests that the correct rpath was added at link-time to the framework's binary.
    # The rpath should match the framework bundle name.
    archive_contents_test(
        name = "{}_binary_has_correct_rpath".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:fmwk",
        contains = [
            "$BUNDLE_ROOT/fmwk",
            "$BUNDLE_ROOT/Info.plist",
        ],
        binary_test_file = "$BUNDLE_ROOT/fmwk",
        macho_load_commands_contain = [
            "name @rpath/fmwk.framework/fmwk (offset 24)",
        ],
        tags = [name],
    )

    # Tests that a watchos_framework builds fine without any version info
    # since it isn't required.
    infoplist_contents_test(
        name = "{}_plist_test_with_no_version".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:fmwk_with_no_version",
        not_expected_keys = [
            "CFBundleVersion",
            "CFBundleShortVersionString",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_exported_symbols_list_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:fmwk_dead_stripped",
        binary_test_file = "$BUNDLE_ROOT/fmwk_dead_stripped",
        compilation_mode = "opt",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_anotherFunctionShared"],
        binary_not_contains_symbols = ["_dontCallMeShared", "_anticipatedDeadCode"],
        tags = [name],
    )

    # Test that if a watchos_framework target depends on a prebuilt static library (i.e.,
    # apple_static_framework_import), that the static library is defined in the watchos_framework.
    binary_contents_test(
        name = "{}_defines_static_library_impl".format(name),
        build_type = "simulator",
        binary_test_architecture = "x86_64",
        binary_test_file = "$BUNDLE_ROOT/Frameworks/fmwk_with_imported_static_framework.framework/fmwk_with_imported_static_framework",
        binary_contains_symbols = [
            "-[SharedClass doSomethingShared]",
            "_OBJC_CLASS_$_SharedClass",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_runtime_framework_using_import_static_lib_dep",
        tags = [name],
    )

    # Test that if a watchos_framework target depends on a prebuilt static library (i.e.,
    # apple_static_framework_import), that the static library is NOT defined in its associated
    # watchos_application.
    binary_contents_test(
        name = "{}_associated_watchos_application_does_not_define_static_library_impl".format(name),
        build_type = "simulator",
        binary_test_architecture = "x86_64",
        binary_test_file = "$BINARY",
        binary_not_contains_symbols = [
            "-[SharedClass doSomethingShared]",
            "_OBJC_CLASS_$_SharedClass",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_runtime_framework_using_import_static_lib_dep",
        tags = [name],
    )

    # Tests that if frameworks and applications have different minimum versions that a user
    # actionable error is raised.
    analysis_failure_message_test(
        name = "{}_app_with_baseline_min_os_and_nplus1_fmwk_produces_error".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:app_with_baseline_min_os_and_nplus1_fmwk",
        expected_error = """
ERROR: minimum_os_version {framework_version} on the framework //test/starlark_tests/targets_under_test/watchos/frameworks:fmwk_min_os_nplus1 is too high compared to //test/starlark_tests/targets_under_test/watchos/frameworks:app_with_baseline_min_os_and_nplus1_fmwk's minimum_os_version of {app_version}

Please address the minimum_os_version on framework //test/starlark_tests/targets_under_test/watchos/frameworks:fmwk_min_os_nplus1 to match //test/starlark_tests/targets_under_test/watchos/frameworks:app_with_baseline_min_os_and_nplus1_fmwk's minimum_os_version.
""".format(app_version = common.min_os_watchos.requires_single_target_app, framework_version = common.min_os_watchos.requires_single_target_app_nplus1),
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_base_bundle_id_derived_bundle_id_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:fmwk_with_base_bundle_id_derived_bundle_id",
        expected_values = {
            "CFBundleIdentifier": "com.bazel.app.example.fmwk-with-base-bundle-id-derived-bundle-id",
        },
        tags = [name],
    )

    # Test framework with App Intents generates and bundles Metadata.appintents bundle.
    archive_contents_test(
        name = "{}_with_app_intents_contains_app_intents_metadata_bundle_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos/frameworks:framework_with_app_intents",
        contains = [
            "$BUNDLE_ROOT/Metadata.appintents/extract.actionsdata",
            "$BUNDLE_ROOT/Metadata.appintents/version.json",
        ],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
