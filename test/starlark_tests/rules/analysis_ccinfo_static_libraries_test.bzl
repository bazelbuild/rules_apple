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

"""Analysis test for verifying static libraries propagated in CcInfo."""

load(
    "@bazel_skylib//lib:unittest.bzl",
    "analysistest",
    "unittest",
)
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def _analysis_ccinfo_static_libraries_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    if CcInfo not in target_under_test:
        unittest.fail(env, "Target does not provide CcInfo")
        return analysistest.end(env)

    static_library_paths = []
    for linker_input in target_under_test[CcInfo].linking_context.linker_inputs.to_list():
        for library in linker_input.libraries:
            if library.static_library:
                static_library_paths.append(library.static_library.path)

    for expected_library in ctx.attr.expected_static_libraries:
        found = False
        for static_library_path in static_library_paths:
            if expected_library in static_library_path:
                found = True
                break
        if not found:
            unittest.fail(
                env,
                "Expected static library '{}' not found in CcInfo.\nActual static libraries: {}".format(
                    expected_library,
                    static_library_paths,
                ),
            )
            return analysistest.end(env)

    return analysistest.end(env)

analysis_ccinfo_static_libraries_test = analysistest.make(
    _analysis_ccinfo_static_libraries_test_impl,
    attrs = {
        "expected_static_libraries": attr.string_list(
            doc = """
A list of strings that should be substrings of paths in the CcInfo static libraries.
Each expected static library must match at least one linked static library path.""",
        ),
    },
)
