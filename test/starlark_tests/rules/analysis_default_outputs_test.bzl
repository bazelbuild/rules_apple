# Copyright 2024 The Bazel Authors. All rights reserved.
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

"""Starlark test rule for OutputGroupInfo output group files."""

load(
    "@build_bazel_rules_apple//test/starlark_tests/rules:analysis_provider_test.bzl",
    "make_provider_test_rule",
)
load(
    "@build_bazel_rules_apple//test/starlark_tests/rules:assertions.bzl",
    "assertions",
)

visibility("//test/starlark_tests/...")

def _get_default_info_files(_, provider):
    """Returns list of files from DefaultInfo."""
    return getattr(provider, "files").to_list()

analysis_default_outputs_simulator_test = make_provider_test_rule(
    provider = DefaultInfo,
    provider_fn = _get_default_info_files,
    assertion_fn = (
        lambda ctx, env, default_info_files: assertions.contains_files(
            env = env,
            expected_files = [],
            actual_files = default_info_files,
        )
    ),
    attrs = {
        "expected_outputs": attr.string_list(
            mandatory = True,
            doc = "List of relative output file paths expected as outputs of DefaultInfo.",
        ),
    },
    config_settings = {
        # macOS is undefined; there is no "simulator" for macOS.
        "//command_line_option:ios_multi_cpus": "sim_arm64,x86_64",
        "//command_line_option:tvos_cpus": "sim_arm64,x86_64",
        "//command_line_option:visionos_cpus": "sim_arm64",
        "//command_line_option:watchos_cpus": "arm64,x86_64",
    },
)
