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

"""watchos_ui_test Starlark tests leveraging watchos_single_target_application."""

load(
    ":common.bzl",
    "common",
)
load(
    "//test/starlark_tests/rules:apple_verification_test.bzl",
    "apple_verification_test",
)
load(
    "//test/starlark_tests/rules:dsyms_test.bzl",
    "dsyms_test",
)
load(
    "//test/starlark_tests/rules:infoplist_contents_test.bzl",
    "infoplist_contents_test",
)

def watchos_single_target_ui_test_test_suite(name):
    """Test suite for watchos_ui_test leveraging watchos_single_target_application.

    Args:
      name: the base name to be used in things created by this macro
    """
    apple_verification_test(
        name = "{}_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:single_target_ui_test",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [
            name,
            "never-on-beta",  # TODO(b/249829891): Remove once internal beta testing issue is fixed.
        ],
    )

    dsyms_test(
        name = "{}_dsyms_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:single_target_ui_test",
        expected_direct_dsyms = ["single_target_ui_test.__internal__.__test_bundle_dsyms/single_target_ui_test.xctest"],
        expected_transitive_dsyms = ["single_target_ui_test.__internal__.__test_bundle_dsyms/single_target_ui_test.xctest"],
        tags = [
            name,
        ],
    )

    infoplist_contents_test(
        name = "{}_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:single_target_ui_test",
        expected_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "single_target_ui_test",
            "CFBundleIdentifier": "com.google.exampleTests",
            "CFBundleName": "single_target_ui_test",
            "CFBundlePackageType": "BNDL",
            "CFBundleSupportedPlatforms:0": "WatchSimulator*",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "watchsimulator",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "watchsimulator*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "MinimumOSVersion": common.min_os_watchos.test_runner_support,
            "UIDeviceFamily:0": "4",
        },
        tags = [
            name,
        ],
    )

    native.test_suite(
        name = name,
        tags = [
            name,
        ],
    )
