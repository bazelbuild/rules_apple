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

"""Rules for testing the contents of action input artifacts."""

load("@bazel_skylib//lib:collections.bzl", "collections")
load("@bazel_skylib//lib:unittest.bzl", "analysistest", "unittest")

def _action_inputs_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    actions = analysistest.target_actions(env)
    mnemonic = ctx.attr.mnemonic
    matching_actions = [
        action
        for action in actions
        if action.mnemonic == mnemonic
    ]

    if not matching_actions:
        actual_mnemonics = collections.uniq(
            [action.mnemonic for action in actions],
        )
        unittest.fail(
            env,
            ("Target '{}' registered no actions with the mnemonic '{}' " +
             "(it had {}).").format(
                str(target_under_test.label),
                mnemonic,
                actual_mnemonics,
            ),
        )
        return analysistest.end(env)

    action_inputs = []
    for action in matching_actions:
        action_inputs.append([
            file.short_path
            for file in action.inputs.to_list()
        ])

    if ctx.attr.expected_inputs:
        matched_expected_inputs = False
        for inputs in action_inputs:
            contains_all_expected_inputs = True
            for expected_input in ctx.attr.expected_inputs:
                found_expected_input = False
                for actual_input in inputs:
                    if expected_input in actual_input:
                        found_expected_input = True
                        break
                if not found_expected_input:
                    contains_all_expected_inputs = False
                    break

            if contains_all_expected_inputs:
                matched_expected_inputs = True
                break

        if not matched_expected_inputs:
            unittest.fail(
                env,
                ("Expected at least one '{}' action for target '{}' to contain all expected " +
                 "inputs {}. Actual inputs: {}").format(
                    mnemonic,
                    str(target_under_test.label),
                    ctx.attr.expected_inputs,
                    action_inputs,
                ),
            )
            return analysistest.end(env)

    if ctx.attr.not_expected_inputs:
        for inputs in action_inputs:
            for not_expected_input in ctx.attr.not_expected_inputs:
                for actual_input in inputs:
                    if not_expected_input in actual_input:
                        unittest.fail(
                            env,
                            ("Expected '{}' action for target '{}' to not contain input '{}', " +
                             "but it did: {}").format(
                                mnemonic,
                                str(target_under_test.label),
                                not_expected_input,
                                inputs,
                            ),
                        )
                        return analysistest.end(env)

    return analysistest.end(env)

def make_action_inputs_test_rule(config_settings = {}):
    """Returns a new `action_inputs_test`-like rule with custom configs."""
    return analysistest.make(
        _action_inputs_test_impl,
        attrs = {
            "expected_inputs": attr.string_list(
                doc = """\
A list of path substrings that must all be present in the inputs of at least
one action with the requested mnemonic.
""",
            ),
            "mnemonic": attr.string(
                mandatory = True,
                doc = """\
The mnemonic of the action to inspect on the target under test. It is expected
that at least one action with this mnemonic exists.
""",
            ),
            "not_expected_inputs": attr.string_list(
                doc = """\
A list of path substrings that must not be present in the inputs of any action
with the requested mnemonic.
""",
            ),
        },
        config_settings = config_settings,
    )

action_inputs_test = make_action_inputs_test_rule()
