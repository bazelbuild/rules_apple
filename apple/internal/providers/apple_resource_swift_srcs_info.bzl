# Copyright 2024 The Bazel Authors. All rights reserved.
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

"""AppleResourceSwiftSrcsInfo provider implementation."""

visibility([
    "//apple/internal/...",
])

AppleResourceSwiftSrcsInfo = provider(
    doc = "Provider that propagates Swift source information affecting Apple resource processing",
    fields = {
        "transitive_swift_src_infos": """
A depset of structs with the following fields, which represent transitive Swift sources given module
names and the Swift source files that they belong to.

*   `module_name`: a String representing the module's name.

*   `src_files`: a depset of Files representing source files that belong to the given Swift module.

From the perspective of resource processing, the "direct" module and its sources are assumed to be
sufficiently represented by the current swift_library target, and is not modelled through this
provider.
""",
    },
)
