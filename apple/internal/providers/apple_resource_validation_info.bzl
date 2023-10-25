# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""AppleResourceValidationInfo provider implementation."""

visibility("//apple/internal/...")

AppleResourceValidationInfo = provider(
    doc = """
Private provider to propagate information needed to validate transitive resources up to a top level
bundling rule from the resource aspect.
""",
    fields = {
        "direct_target_bundle_infos": """
A List of structs with the following fields, which represent providers from targets that have
providers that must be validated at the top level bundling rule through the
`child_bundle_info_validation` partial:

*   `apple_bundle_info`: An `AppleBundleInfo` provider from the target propagated from the resource
    aspect.

*   `target_label`: a String representing the full path label for the target propagated from the
    resource aspect.
""",
        "transitive_target_bundle_infos": """
A depset of structs with the following fields, which represent providers from targets that have
providers that must be validated at the top level bundling rule through the
`child_bundle_info_validation` partial:

*   `apple_bundle_info`: An `AppleBundleInfo` provider from the target propagated from the resource
    aspect.

*   `target_label`: a String representing the full path label for the target propagated from the
    resource aspect.
""",
    },
)
