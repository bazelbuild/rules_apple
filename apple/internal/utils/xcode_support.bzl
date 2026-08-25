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

"""Utility functions for inspecting Xcode configuration and versions."""

visibility("@build_bazel_rules_apple//apple/internal/...")

def _xcode_build_version(*, xcode_version_config):
    """Read the build version from the fourth component of the Xcode version."""
    xcode_version_split = str(xcode_version_config.xcode_version()).split(".")
    if len(xcode_version_split) < 4:
        fail("""\
Internal Error: Expected xcode_config to report the Xcode version with the build version as the \
fourth component of the full version string, but instead found {xcode_version_string}. Please file \
an issue with the Apple BUILD rules with repro steps.
""".format(
            xcode_version_string = str(xcode_version_config.xcode_version()),
        ))
    return xcode_version_split[3]

xcode_support = struct(
    xcode_build_version = _xcode_build_version,
)
