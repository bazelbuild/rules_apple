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

"""Location types for bundling."""

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

# Location enum that can be used to tag files into their appropriate location
# in the final archive.
location_enum = struct(
    app_clip = "app_clip",
    archive = "archive",
    binary = "binary",
    bundle = "bundle",
    content = "content",
    extension = "extension",
    framework = "framework",
    plugin = "plugin",
    resource = "resource",
    watch = "watch",
    xpc_service = "xpc_service",
)
