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

"""ios_kernel_extension Starlark tests."""

load(
    "//test/starlark_tests/rules:analysis_target_actions_test.bzl",
    "make_analysis_target_actions_test",
)
load(
    "//test/starlark_tests/rules:analysis_target_outputs_test.bzl",
    "analysis_target_outputs_test",
)
load(
    "//test/starlark_tests/rules:infoplist_contents_test.bzl",
    "infoplist_contents_test",
)

_analysis_arm64e_ios_cpu_test = make_analysis_target_actions_test(
    config_settings = {"//command_line_option:ios_multi_cpus": "arm64e"},
)

def ios_kernel_extension_test_suite(name):
    """Test suite for ios_kernel_extension.

    Args:
      name: the base name to be used in things created by this macro
    """
    analysis_target_outputs_test(
        name = "{}_zip_file_output_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:kext",
        expected_outputs = ["kext.zip"],
        tags = [name],
    )

    _analysis_arm64e_ios_cpu_test(
        name = "{}_arm64e_ios_cpu_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:kext",
        target_mnemonic = "ObjcLink",
        expected_argv = [
            "/wrapped_clang",
            "-kext",
            "-target arm64e-apple-ios12.0",
        ],
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:kext",
        expected_values = {
            "CFBundleIdentifier": "com.google.kext",
            "CFBundlePackageType": "KEXT",
        },
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
