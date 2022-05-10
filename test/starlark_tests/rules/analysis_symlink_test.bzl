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

"Starlark test for verifying targets that generate actions related to symlinks."

load(
    "@bazel_skylib//lib:unittest.bzl",
    "analysistest",
    "unittest",
)

def _analysis_symlink_test_impl(ctx):
    "Test that a `lipo` action does not exist, and the target is symlinked."
    env = analysistest.begin(ctx)

    no_symlink = True
    for action in analysistest.target_actions(env):
        if hasattr(action, "argv") and action.argv:
            concat_action_argv = " ".join(action.argv)
            if "lipo " in concat_action_argv:
                unittest.fail(env, "An unexpected lipo action was found.")
        elif action.mnemonic == "Symlink":
            no_symlink = False

    if no_symlink:
        unittest.fail(env, "Did not find any symlink actions to test.")
    return analysistest.end(env)

analysis_symlink_test = analysistest.make(
    _analysis_symlink_test_impl,
    config_settings = {
        "//command_line_option:macos_cpus": "x86_64",
        "//command_line_option:ios_multi_cpus": "x86_64",
        "//command_line_option:tvos_cpus": "x86_64",
        "//command_line_option:watchos_cpus": "x86_64",
    },
)
