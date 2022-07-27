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

"Starlark test for verifying targets that generate actions related to lipo."

load(
    "@bazel_skylib//lib:unittest.bzl",
    "analysistest",
    "unittest",
)

def _analysis_lipo_test_impl(ctx):
    "Test the `lipo` action exists with expected environment variables."
    env = analysistest.begin(ctx)
    expected_env = {
        "APPLE_SDK_PLATFORM": ctx.attr.expected_sdk_platform,
    }

    no_lipo = True
    for action in analysistest.target_actions(env):
        if hasattr(action, "argv") and action.argv:
            concat_action_argv = " ".join(action.argv)
            if not "lipo " in concat_action_argv:
                continue
            for test_env_key in expected_env.keys():
                if not test_env_key in action.env:
                    unittest.fail(env, "\"{}\" not in lipo's environment, instead found: \"{}\".".format(
                        test_env_key,
                        " ".join(action.env.keys()),
                    ))
                if action.env[test_env_key] != expected_env[test_env_key]:
                    unittest.fail(env, "\"{}\" did not match expected value \"{}\" for lipo's environment variable given key of \"{}\".".format(
                        action.env[test_env_key],
                        expected_env[test_env_key],
                        test_env_key,
                    ))
            no_lipo = False

    if no_lipo:
        unittest.fail(env, "Did not find any lipo actions to test.")
    return analysistest.end(env)

analysis_lipo_test = analysistest.make(
    _analysis_lipo_test_impl,
    attrs = {
        "expected_sdk_platform": attr.string(
            mandatory = True,
            doc = "The expected Apple SDK platform that lipo will be called under.",
        ),
    },
    config_settings = {
        "//command_line_option:macos_cpus": "arm64,x86_64",
        "//command_line_option:ios_multi_cpus": "sim_arm64,x86_64",
        "//command_line_option:tvos_cpus": "sim_arm64,x86_64",
        "//command_line_option:watchos_cpus": "arm64_32,armv7k",
    },
)
