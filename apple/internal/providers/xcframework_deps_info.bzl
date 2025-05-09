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

"""XCFrameworkDepsInfo provider implementation."""

visibility([
    "@build_bazel_rules_apple//apple/internal/...",
])

# TODO(b/220185798): Extend this to allow for transitive dependencies of the same types of structs.
XCFrameworkDepsInfo = provider(
    doc = "Contains information about the framework contents of a dynamic framework XCFramework.",
    fields = {
        "direct_framework_deps": """\
A List of structs with these fields:

*   `apple_dynamic_framework_info`: An AppleDynamicFrameworkInfo provider representing one
    framework's linking information.

*   `apple_resource_info`: An optional AppleFrameworkInfo provider representing the resource
    contents of a given framework.

*   `architectures`: A list of architectures that the framework supports for validation.

*   `target_environment`: A `String` representing the selected target environment (e.g. "device",
        "simulator").

#   `target_os`: A `String` representing the selected Apple OS.
""",
    },
)
