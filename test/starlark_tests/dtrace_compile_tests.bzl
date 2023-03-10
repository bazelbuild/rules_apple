# Copyright 2020 The Bazel Authors. All rights reserved.
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

"""`dtrace_compile` Starlark tests."""

load(
    ":rules/output_text_match_test.bzl",
    "output_text_match_test",
)

def dtrace_compile_test_suite(name):
    """Test suite for `dtrace_compile`.

    Args:
      name: the base name to be used in things created by this macro
    """
    output_text_match_test(
        name = "{}_generates_expected_header_contents".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/dtrace:dtrace",
        files_match = {
            "folder1/probes.h": ["PROVIDERA_MYFUNC"],
            "folder2/probes.h": ["PROVIDERB_MYFUNC"],
        },
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
