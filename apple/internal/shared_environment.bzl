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

"""
Environment related functions and providers.
"""

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

_DEFAULT_ENV = {
    "SWIFT_DETERMINISTIC_HASHING": "1",
}

_ARCHIVE_ENV = _DEFAULT_ENV | {
    "RULES_APPLE_USE_ZIP_WRITER": "1",
}

def _archive_env(build_settings):
    """Returns the environment dictionary for macOS archive-producing actions."""
    return _ARCHIVE_ENV if build_settings.use_zip_writer_on_mac else _DEFAULT_ENV

shared_environment = struct(
    archive_env = _archive_env,
    default_env = _DEFAULT_ENV,
)
