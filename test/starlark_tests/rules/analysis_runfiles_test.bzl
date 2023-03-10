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

"Starlark test for verifying that the runfiles of targets are properly set."

load(
    "@bazel_skylib//lib:unittest.bzl",
    "analysistest",
    "unittest",
)

def _analysis_runfiles_test_impl(ctx):
    "Test that runfiles of the given target under test is properly set."
    env = analysistest.begin(ctx)

    file_list = [x.short_path for x in analysistest.target_under_test(env)[DefaultInfo].data_runfiles.files.to_list()]

    for expected_runfile in ctx.attr.expected_runfiles:
        if expected_runfile not in file_list:
            unittest.fail(env, "\"{}\" not in target's runfiles, instead found:\n\"{}\".".format(
                expected_runfile,
                "\n".join(file_list),
            ))

    return analysistest.end(env)

analysis_runfiles_test = analysistest.make(
    _analysis_runfiles_test_impl,
    attrs = {
        "expected_runfiles": attr.string_list(
            mandatory = True,
            doc = "A list of runfiles expected to be found in the given target.",
        ),
    },
)
