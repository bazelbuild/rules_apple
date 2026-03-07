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

"""Analysis test for verifying XCFramework include paths in CcInfo provider."""

load(
    "@bazel_skylib//lib:unittest.bzl",
    "analysistest",
    "unittest",
)
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def _analysis_xcframework_includes_test_impl(ctx):
    """Implementation of analysis_xcframework_includes_test."""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    # Get CcInfo provider from the target
    if not CcInfo in target_under_test:
        unittest.fail(env, "Target does not provide CcInfo")
        return analysistest.end(env)

    cc_info = target_under_test[CcInfo]
    compilation_context = cc_info.compilation_context

    # Get all include directories as strings
    includes = [inc for inc in compilation_context.includes.to_list()]
    system_includes = [inc for inc in compilation_context.system_includes.to_list()]
    quote_includes = [inc for inc in compilation_context.quote_includes.to_list()]

    all_includes = includes + system_includes + quote_includes

    # Check that expected includes are present
    for expected_include in ctx.attr.expected_includes:
        found = False
        for inc in all_includes:
            if expected_include in inc:
                found = True
                break
        if not found:
            unittest.fail(
                env,
                "Expected include path '{}' not found in CcInfo includes.\nActual includes: {}".format(
                    expected_include,
                    all_includes,
                ),
            )
            return analysistest.end(env)

    # Check that not_expected includes are absent
    for not_expected_include in ctx.attr.not_expected_includes:
        for inc in all_includes:
            if not_expected_include in inc:
                unittest.fail(
                    env,
                    "Include path '{}' should NOT be present but was found in CcInfo includes.\nActual includes: {}".format(
                        not_expected_include,
                        all_includes,
                    ),
                )
                return analysistest.end(env)

    return analysistest.end(env)

analysis_xcframework_includes_test = analysistest.make(
    _analysis_xcframework_includes_test_impl,
    attrs = {
        "expected_includes": attr.string_list(
            doc = """
A list of strings that should be substrings of paths in the CcInfo includes.
Each expected include must match at least one path in the includes.""",
        ),
        "not_expected_includes": attr.string_list(
            doc = """
A list of strings that should NOT be substrings of any paths in the CcInfo includes.
If any of these are found, the test fails.""",
        ),
    },
)
