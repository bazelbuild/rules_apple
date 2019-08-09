# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Starlark test testing failures by the contents of their message using the analysis test framework.
https://docs.bazel.build/versions/0.27.0/skylark/testing.html#failure-testing
"""

load(
    "@bazel_skylib//lib:unittest.bzl",
    "analysistest",
    "asserts",
)

def _analysis_failure_message_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, ctx.attr.expected_error)
    return analysistest.end(env)

analysis_failure_message_test = analysistest.make(
    _analysis_failure_message_test_impl,
    expect_failure = True,
    attrs = {
        "expected_error": attr.string(
            mandatory = True,
            doc = "Text expected to see in the error output.",
        ),
    },
)
