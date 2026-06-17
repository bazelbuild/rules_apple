# Copyright 2017 The Bazel Authors. All rights reserved.
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

"""Deprecated compatibility macro for the macOS test runner."""

load(
    "//apple/testing/default_runner:apple_xctestrun_runner.bzl",
    "apple_xctestrun_runner",
)

_DEPRECATION_MESSAGE = (
    "macos_test_runner is deprecated. Use apple_xctestrun_runner instead."
)

def macos_test_runner(
        name,
        execution_requirements = None,
        post_action = None,
        post_action_determines_exit_code = False,
        pre_action = None,
        test_environment = None,
        **kwargs):
    """Deprecated. Use apple_xctestrun_runner instead."""
    runner_kwargs = dict(kwargs)
    runner_kwargs.update({
        "name": name,
        "post_action_determines_exit_code": post_action_determines_exit_code,
    })
    if execution_requirements != None:
        runner_kwargs["execution_requirements"] = execution_requirements
    if post_action != None:
        runner_kwargs["post_action"] = post_action
    if pre_action != None:
        runner_kwargs["pre_action"] = pre_action
    if test_environment != None:
        runner_kwargs["test_environment"] = test_environment
    if "deprecation" not in runner_kwargs:
        runner_kwargs["deprecation"] = _DEPRECATION_MESSAGE

    apple_xctestrun_runner(**runner_kwargs)
