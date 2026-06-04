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

"""Starlark test rule for exact OutputGroupInfo output group files."""

load(
    "//test/starlark_tests/rules:analysis_output_group_info_files_test.bzl",
    "make_analysis_output_group_info_files_test",
)
load(
    "//test/starlark_tests/rules:assertions.bzl",
    "assertions",
)

visibility("//test/starlark_tests/...")

def _analysis_output_group_info_files_exact_test_assertion(ctx, env, output_group_files):
    return assertions.equals_files(
        env = env,
        expected_files = ctx.attr.expected_outputs,
        actual_files = output_group_files,
    )

def make_analysis_output_group_info_files_exact_test(config_settings = {}):
    return make_analysis_output_group_info_files_test(
        config_settings = config_settings,
        assertion_fn = _analysis_output_group_info_files_exact_test_assertion,
    )

analysis_output_group_info_files_exact_test = make_analysis_output_group_info_files_exact_test()
