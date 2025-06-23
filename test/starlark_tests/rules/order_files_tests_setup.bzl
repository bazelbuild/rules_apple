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

"""order_file Starlark tests setup."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

visibility("//test/starlark_tests/...")

def _provider_contents_test_impl(ctx):
    env = analysistest.begin(ctx)

    target_under_test = analysistest.target_under_test(env)
    target_linking_context = target_under_test[CcInfo].linking_context
    linker_inputs = target_linking_context.linker_inputs.to_list()
    additional_inputs = [file for linker_input in linker_inputs for file in linker_input.additional_inputs]
    user_link_flags = [flag for linker_input in linker_inputs for flag in linker_input.user_link_flags]

    asserts.true(env, additional_inputs[0])
    asserts.true(env, user_link_flags[0].startswith("-Wl,-order_file,"))

    return analysistest.end(env)

provider_contents_test = analysistest.make(
    _provider_contents_test_impl,
    config_settings = {
        "//command_line_option:compilation_mode": "opt",
    },
)

def _opt_transition_impl(_, __):
    return {"//command_line_option:compilation_mode": "opt"}

opt_transition = transition(
    implementation = _opt_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:compilation_mode"],
)

def _file_contents_test_impl(ctx):
    target_under_test = ctx.attr.target_under_test
    linker_inputs = target_under_test[CcInfo].linking_context.linker_inputs.to_list()
    additional_inputs = [file for linker_input in linker_inputs for file in linker_input.additional_inputs]

    actual = additional_inputs[0]

    body = """
echo Testing that {file} matches {expected}
cmp {file_path} {expected_path} || err=1
""".format(
        file_path = actual.short_path,
        expected_path = ctx.file.expected.short_path,
        file = actual.path,
        expected = ctx.file.expected.path,
    )

    script = "\n".join(
        ["err=0"] +
        [body] +
        ["exit $err"],
    )

    ctx.actions.write(
        output = ctx.outputs.executable,
        content = script,
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [actual, ctx.file.expected])
    return [DefaultInfo(runfiles = runfiles)]

file_contents_test = rule(
    _file_contents_test_impl,
    cfg = opt_transition,
    attrs = {
        "target_under_test": attr.label(
            mandatory = True,
        ),
        "expected": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
    },
    test = True,
)
