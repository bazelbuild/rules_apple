# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""Starlark test rules for custom_malloc usage."""

load(
    "@build_bazel_rules_apple//test/starlark_tests/rules:analysis_target_actions_test.bzl",
    "make_analysis_target_actions_test",
)

visibility("//test/starlark_tests/...")

# Adds a custom allocator flag.
_custom_malloc_test = make_analysis_target_actions_test(
    config_settings = {
        "//command_line_option:custom_malloc": "@build_bazel_rules_apple//test/starlark_tests/resources:custom_allocator",
        "//command_line_option:macos_cpus": "arm64,x86_64",
        "//command_line_option:ios_multi_cpus": "sim_arm64,x86_64",
        "//command_line_option:tvos_cpus": "sim_arm64,x86_64",
        "//command_line_option:watchos_cpus": "arm64,i386,x86_64",
    },
)

# Verifies that the addition of the custom allocator flag puts our allocator library into our link.
def custom_malloc_test(name, target_under_test):
    _custom_malloc_test(
        name = "{}_custom_malloc_test".format(name),
        target_mnemonic = "ObjcLink",
        expected_argv = [
            "libcustom_allocator.a",
        ],
        tags = [name],
        target_under_test = target_under_test,
    )
