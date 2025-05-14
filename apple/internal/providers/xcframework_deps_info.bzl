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

XCFrameworkDepsInfo = provider(
    doc = "Contains information about the framework contents of a dynamic framework XCFramework.",
    fields = {
        "direct_framework_deps": """\
A List of structs to indicate direct XCFramework dependencies with these fields:

*   `apple_dynamic_framework_info`: An AppleDynamicFrameworkInfo provider representing one
    framework's linking information.

*   `apple_resource_info`: An optional AppleFrameworkInfo provider representing the resource
    contents of a given framework.

*   `architectures`: A list of architectures that the framework supports for validation.

*   `label`: The label of the XCFramework that these dependencies are associated with.

*   `target_environment`: A `String` representing the selected target environment (e.g. "device",
        "simulator").

*   `target_os`: A `String` representing the selected Apple OS.
""",
        "transitive_framework_deps": """\
A depset of structs with the same fields as `direct_framework_deps` to indicate transitive deps.
This is a superset of `direct_framework_deps` including all transitive dependencies.
""",
    },
)
