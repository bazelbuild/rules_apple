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
    "//test/starlark_tests/rules:analysis_failure_message_test.bzl",
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
            "LSMinimumSystemVersion": common.min_os_macos.baseline,
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

    native.test_suite(
        name = name,
        tags = [name],
    )
