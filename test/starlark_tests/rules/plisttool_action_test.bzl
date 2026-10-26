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
    if not action.argv or not action.argv[0].endswith(("plisttool", "plisttool_osx")):
        analysistest.fail(
            env,
            "Expected action executable to be plisttool, but got argv: {}".format(action.argv),
        )
        return analysistest.end(env)

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
        elif (
            type(expected_value) == "string" and
            type(actual_value) == "string" and
            expected_value.startswith("*") and
            len(expected_value) > 1
        ):
            if not actual_value.endswith(expected_value[1:]):
                analysistest.fail(
                    env,
                    "Value of '{}' (expected suffix: {}, actual: {}) doesn't match".format(
                        key,
                        expected_value[1:],
                        actual_value,
                    ),
                )
        elif expected_value != "*" and expected_value != actual_value:
            analysistest.fail(env, "Value of '{}' (expected: {}, actual: {}) doesn't match".format(key, expected_value, actual_value))

    for unexpected_key in ctx.attr.unexpected_control_keys:
        if unexpected_key in actual_dict:
            analysistest.fail(
                env,
                "Unexpected key '{}' found in plisttool control dict: {}".format(
                    unexpected_key,
                    actual_dict,
                ),
            )

    for expected_req_key, expected_req_value in ctx.attr.expected_execution_requirements.items():
        if action.execution_info.get(expected_req_key) != expected_req_value:
            analysistest.fail(
                env,
                "Expected execution requirement {}: {} not in action execution_info: {}".format(
                    expected_req_key,
                    expected_req_value,
                    action.execution_info,
                ),
            )

    for not_expected_req_key in ctx.attr.not_expected_execution_requirements:
        if not_expected_req_key in action.execution_info:
            analysistest.fail(
                env,
                "Unexpected execution requirement '{}' found in action execution_info: {}".format(
                    not_expected_req_key,
                    action.execution_info,
                ),
            )

    if ctx.attr.assert_output_bundled:
        bundle_actions = [
            a
            for a in target_under_test.actions
            if a.mnemonic in ("BundleApp", "BundleTreeApp")
        ]
        if not bundle_actions:
            analysistest.fail(env, "No BundleApp or BundleTreeApp action found on target.")
            return analysistest.end(env)
        bundle_inputs = {f: True for f in bundle_actions[0].inputs.to_list()}
        for out_file in action.outputs.to_list():
            if out_file not in bundle_inputs:
                analysistest.fail(
                    env,
                    "Expected plisttool output '{}' to be an input to {}, but it was not.".format(
                        out_file.short_path,
                        bundle_actions[0].mnemonic,
                    ),
                )

    return analysistest.end(env)

def make_plisttool_action_test(config_settings = {}, extra_target_under_test_aspects = []):
    """Returns a `plisttool_action_test`-like rule with custom config_settings.

    Args:
      config_settings: A dictionary of configuration settings and their values
          that should be applied during tests.
      extra_target_under_test_aspects: Optional list of aspects to apply to target_under_test.

    Returns:
      A rule returned by `analysistest.make`.
    """
    return analysistest.make(
        _plisttool_action_test_impl,
        attrs = {
            "assert_output_bundled": attr.bool(
                default = False,
                doc = "If True, asserts that the action's output is an input to BundleApp or " +
                      "BundleTreeApp.",
            ),
            "expected_control_dict": attr.string(
                mandatory = True,
                doc = "JSON encoded dict of expected values.",
            ),
            "expected_execution_requirements": attr.string_dict(
                doc = "Expected execution requirement keys and values on the action.",
            ),
            "not_expected_execution_requirements": attr.string_list(
                doc = "Execution requirement keys that must not be present on the action.",
            ),
            "target_mnemonic": attr.string(mandatory = True),
            "unexpected_control_keys": attr.string_list(
                doc = "Keys that must not be present in the plisttool control dict.",
            ),
        },
        config_settings = config_settings,
        extra_target_under_test_aspects = extra_target_under_test_aspects,
    )

plisttool_action_test = make_plisttool_action_test()
