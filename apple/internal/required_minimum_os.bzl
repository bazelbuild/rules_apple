# Copyright 2025 The Bazel Authors. All rights reserved.
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

"""Required minimum OS versions for Apple platforms."""

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

# Based on https://developer.apple.com/support/xcode/ for Xcode 16 as of 2025-08-01.
_REQUIRED_MINIMUM_OS_VERSION = {
    "ios": "15.0",
    "macos": "10.13",  # TODO: b/433768882 - Move up to 11.0 for Xcode 26.
    "tvos": "12.0",  # TODO: b/433768882 - Move up to 15.0 for Xcode 16.0.
    "visionos": "1.0",
    "watchos": "8.0",
}

def _validate(*, minimum_os_version, platform_type, rule_label):
    """Verifies that the given minimum OS version is supported for the given platform type."""
    if (apple_common.dotted_version(minimum_os_version) <
        apple_common.dotted_version(_REQUIRED_MINIMUM_OS_VERSION[platform_type])):
        fail("""
Error: The declared minimum OS version for {rule_label} is "{minimum_os_version}", which is lower \
than the required minimum OS version of "{required_minimum_os_version}".

Please update the minimum_os_version attribute to "{required_minimum_os_version}" or higher.
        """.format(
            rule_label = str(rule_label),
            minimum_os_version = minimum_os_version,
            required_minimum_os_version = _REQUIRED_MINIMUM_OS_VERSION[platform_type],
        ))

required_minimum_os = struct(
    validate = _validate,
)
