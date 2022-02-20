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

"""tvos_framework Starlark tests."""

load(
    ":rules/common_verification_tests.bzl",
    "archive_contents_test",
)
load(
    ":rules/infoplist_contents_test.bzl",
    "infoplist_contents_test",
)

def tvos_framework_test_suite(name):
    """Test suite for tvos_framework.

    Args:
      name: the base name to be used in things created by this macro
    """
    infoplist_contents_test(
        name = "{}_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/tvos:fmwk",
        expected_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "fmwk",
            "CFBundleIdentifier": "com.google.example.framework",
            "CFBundleName": "fmwk",
            "CFBundlePackageType": "FMWK",
            "CFBundleSupportedPlatforms:0": "AppleTVSimulator*",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "appletvsimulator*",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "appletvsimulator*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "MinimumOSVersion": "9.0",
            "UIDeviceFamily:0": "3",
        },
        tags = [name],
    )

    archive_contents_test(
        name = "{}_exported_symbols_list_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/tvos:fmwk_dead_stripped",
        binary_test_file = "$BUNDLE_ROOT/fmwk_dead_stripped",
        compilation_mode = "opt",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_anotherFunctionShared"],
        binary_not_contains_symbols = ["_dontCallMeShared", "_anticipatedDeadCode"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_angle_bracketed_import_in_umbrella_header".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/tvos:static_fmwk",
        text_test_file = "$BUNDLE_ROOT/Headers/static_fmwk.h",
        text_test_values = ["#import <static_fmwk/shared.h>"],
        tags = [name],
    )

    # Verify tvos_framework listed as a runtime_dep of an objc_library gets
    # propagated to tvos_application bundle.
    archive_contents_test(
        name = "{}_includes_objc_library_tvos_framework_runtime_dep".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/tvos:app_with_objc_library_dep_with_tvos_framework_runtime_dep",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk_with_provisioning.framework/fmwk_with_provisioning",
        ],
        tags = [name],
    )

    # Verify nested frameworks from objc_library targets get propagated to
    # tvos_application bundle.
    archive_contents_test(
        name = "{}_includes_multiple_objc_library_tvos_framework_deps".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/tvos:app_with_objc_lib_dep_with_inner_lib_with_runtime_dep_fmwk",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk.framework/fmwk",
            "$BUNDLE_ROOT/Frameworks/fmwk_with_provisioning.framework/fmwk_with_provisioning",
            "$BUNDLE_ROOT/Frameworks/fmwk_with_fmwk.framework/fmwk_with_fmwk",
        ],
        tags = [name],
    )

    # Verify tvos_framework listed as a runtime_dep of an objc_library does not
    # get linked to top-level application (Mach-O LC_LOAD_DYLIB commands).
    archive_contents_test(
        name = "{}_does_not_load_bundled_tvos_framework_runtime_dep".format(name),
        build_type = "simulator",
        binary_test_file = "$BUNDLE_ROOT/app_with_objc_lib_dep_with_inner_lib_with_runtime_dep_fmwk",
        macho_load_commands_not_contain = [
            "name @rpath/fmwk.framework/fmwk (offset 24)",
            "name @rpath/fmwk_with_provisioning.framework/fmwk_with_provisioning (offset 24)",
            "name @rpath/fmwk_with_fmwk.framework/fmwk_with_fmwk (offset 24)",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/tvos:app_with_objc_lib_dep_with_inner_lib_with_runtime_dep_fmwk",
        tags = [name],
    )

    # Verify that both tvos_framework listed as a load time and runtime_dep
    # get bundled to top-level application, and runtime does not get linked.
    archive_contents_test(
        name = "{}_bundles_both_load_and_runtime_framework_dep".format(name),
        build_type = "simulator",
        binary_test_file = "$BUNDLE_ROOT/app_with_load_and_runtime_framework_dep",
        contains = [
            "$BUNDLE_ROOT/Frameworks/fmwk.framework/fmwk",
            "$BUNDLE_ROOT/Frameworks/fmwk_with_provisioning.framework/fmwk_with_provisioning",
        ],
        macho_load_commands_contain = [
            "name @rpath/fmwk.framework/fmwk (offset 24)",
        ],
        macho_load_commands_not_contain = [
            "name @rpath/fmwk_with_provisioning.framework/fmwk_with_provisioning (offset 24)",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/tvos:app_with_load_and_runtime_framework_dep",
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
