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

"""AppExtensionPointInfo provider."""

visibility(["@build_bazel_rules_apple//apple/internal/..."])

AppExtensionPointInfo = provider(
    doc = """
Provider used by host applications to discover the abstract extension points (protocols)
that they support. This is attached to extension protocol definitions via the
`app_extension_point_hint` and relays the module information necessary for the host
application to generate `.appexpt` mapping files during bundling.
""",
    fields = {
        "extension_points": """
A `depset` of Starlark `struct`s containing metadata about the extension point.
Each struct has the following fields:
  - `module_name`: The fully qualified module name of the extension point.
  - `swiftconstvalues_files`: A depset of `.swiftconstvalues` files carrying the
    underlying metadata for the abstract extension point.
  - `owner`: A string representation of the target label that generated this point.
""",
    },
)
