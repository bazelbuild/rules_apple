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

"""Starlark test rules for CcInfo compilation_context."""

load(
    "@bazel_skylib//lib:unittest.bzl",
    "analysistest",
    "asserts",
)

def _compilation_context_test_impl(ctx):
    """Implementation of the compilation_context_test rule."""
    env = analysistest.begin(ctx)
    target_under_test = ctx.attr.target_under_test
    expected_attributes = ctx.attr.expected_attributes

    asserts.true(
        env,
        CcInfo in target_under_test,
        msg = "Expected CcInfo provider not found",
    )

    asserts.true(
        env,
        hasattr(target_under_test[CcInfo], "compilation_context"),
        msg = "Expected CcInfo's compilation_context not found",
    )

    conliation_context = target_under_test[CcInfo].compilation_context
    for expected_attribute in expected_attributes:
        asserts.true(
            env,
            hasattr(conliation_context, expected_attribute),
            msg = "Expected CcInfo compilation context not found\n\n\"{0}\"".format(
                expected_attribute,
            ),
        )

    return analysistest.end(env)

compilation_context_test = analysistest.make(
    _compilation_context_test_impl,
    attrs = {
        "expected_attributes": attr.string_list(
            mandatory = True,
            doc = """List of CcInfo compilation attribute that should be present in the target.""",
        ),
    },
)
