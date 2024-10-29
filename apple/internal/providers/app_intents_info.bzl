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

"""AppIntentsInfo provider implementation for AppIntents support for Apple rules."""

visibility([
    "//apple/hints/...",
    "//apple/internal/...",
])

AppIntentsHintInfo = provider(
    doc = "Private provider to mark targets that are hinted to define AppIntents processing.",
    fields = {},
)

AppIntentsInfo = provider(
    doc = "Private provider to propagate source files required by AppIntents processing.",
    fields = {
        "metadata_bundle_inputs": """
A depset of structs with the following fields, which represent providers from targets that have
providers that must be processed at the top level bundling rule through the
`app_intents_metadata_bundle` partial:

*   `module_name`: A String representing the module name that these files belong to.

*   `owner`: A String based on the label of the target that provided this metadata bundle input.

*   `swift_source_files`: A List of the Swift source files for this module.

*   `swiftconstvalues_files`:  A List of the swiftconstvalues files for this module.
""",
    },
)

AppIntentsBundleInfo = provider(
    doc = "Private provider to propagate AppIntents metadata bundle files to dependencies.",
    fields = {
        "owned_metadata_bundles": """
A depset of structs defined as the following:

*   `bundle`: A File representing the metadata bundle file.

*   `owner`: A String based on the label of the target that provided this metadata bundle.
""",
    },
)
