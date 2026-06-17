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

"""Deprecated compatibility macro for the tvOS test runner."""

load(
    "//apple/testing/default_runner:apple_xctestrun_runner.bzl",
    "apple_xctestrun_runner",
)

_DEPRECATION_MESSAGE = (
    "tvos_test_runner is deprecated. Use apple_xctestrun_runner instead."
)

def tvos_test_runner(
        name,
        device_type = "",
        execution_requirements = None,
        os_version = "",
        **kwargs):
    """Deprecated. Use apple_xctestrun_runner instead.

    Args:
      name: Name for the runner target.
      device_type: Simulator device type to pass through to apple_xctestrun_runner.
      execution_requirements: Optional execution requirements override.
      os_version: Simulator OS version to pass through to apple_xctestrun_runner.
      **kwargs: Additional keyword arguments forwarded to apple_xctestrun_runner.
    """
    runner_kwargs = dict(kwargs)
    runner_kwargs.update({
        "name": name,
        "device_type": device_type,
        "execution_requirements": execution_requirements or {"requires-darwin": ""},
        "os_version": os_version,
    })
    if "deprecation" not in runner_kwargs:
        runner_kwargs["deprecation"] = _DEPRECATION_MESSAGE

    apple_xctestrun_runner(**runner_kwargs)
