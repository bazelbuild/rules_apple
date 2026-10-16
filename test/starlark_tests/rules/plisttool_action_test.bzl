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

"""Test rule for verifying plisttool actions."""

load(
    "@bazel_skylib//lib:unittest.bzl",
    "analysistest",
)

visibility("//test/starlark_tests/...")

def _plisttool_action_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    mnemonic = ctx.attr.target_mnemonic
    actions = [a for a in target_under_test.actions if a.mnemonic == mnemonic]
    if not actions:
        analysistest.fail(env, "No action found with mnemonic {}".format(mnemonic))
        return analysistest.end(env)

    action = actions[0]

    # The JSON string is the last argument.
    json_str = action.argv[-1]

    # Unquote shell string if it was quoted by shell.quote()
    if json_str.startswith("'") and json_str.endswith("'"):
        json_str = json_str[1:-1].replace("'\\''", "'")

    actual_dict = json.decode(json_str)

    expected_dict = json.decode(ctx.attr.expected_control_dict)

    for key, expected_value in expected_dict.items():
        if key not in actual_dict:
            analysistest.fail(env, "Key '{}' not found in plisttool control dict. Actual dict: {}".format(key, actual_dict))
            continue

        actual_value = actual_dict[key]

        if type(expected_value) == "list" and type(actual_value) == "list":
            if len(expected_value) != len(actual_value):
                # If expected value is just ["*"], we might just allow any list of any length?
                # The user asked: "potentially have a '*' for each of the incoming files"
                # This implies the length should match and each element in expected could be "*".
                if expected_value != ["*"]:
                    analysistest.fail(env, "Length of '{}' (expected: {}, actual: {}) doesn't match".format(key, len(expected_value), len(actual_value)))
                    continue

            # If the expected value is exactly ["*"], we don't need to match element by element
            if expected_value == ["*"]:
                continue

            for i, (e, a) in enumerate(zip(expected_value, actual_value)):
                if e != "*" and e != a:
                    analysistest.fail(env, "List item {} of '{}' (expected: {}, actual: {}) doesn't match".format(i, key, e, a))
        elif expected_value != "*" and expected_value != actual_value:
            analysistest.fail(env, "Value of '{}' (expected: {}, actual: {}) doesn't match".format(key, expected_value, actual_value))

    return analysistest.end(env)

plisttool_action_test = analysistest.make(
    _plisttool_action_test_impl,
    attrs = {
        "target_mnemonic": attr.string(mandatory = True),
        "expected_control_dict": attr.string(mandatory = True, doc = "JSON encoded dict of expected values."),
    },
)
