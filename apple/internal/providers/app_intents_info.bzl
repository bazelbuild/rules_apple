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
    "@build_bazel_rules_apple//apple/hints/...",
    "@build_bazel_rules_apple//apple/internal/...",
])

AppIntentsHintInfo = provider(
    doc = "Private provider to mark targets that are hinted to define AppIntents processing.",
    fields = {
        "static_metadata": """
If `True`, the hinted target is expected to only provide "static metadata" for App Intents, which
are explicitly used by the appintentsmetadataprocessor tool to declare a set of App Intents that
will be inherited by a "main" "app_intents" hinted target in the build graph for a given top level
target. This allows for sharing App Intents via swift_library targets without creating an ambiguous
main source of truth for the App Intents metadata.
""",
    },
)

AppIntentsInfo = provider(
    doc = "Private provider to propagate source files required by AppIntents processing.",
    fields = {
        "metadata_bundle_inputs": """
A depset of structs with the following fields, which represent providers from targets that have
providers that must be processed at the top level bundling rule through the
`app_intents_metadata_bundle` partial:

*   `direct_app_intents_modules`: A list of String-based module_name-s that must be included as
    dependencies in the generated App Intents metadata bundle.

*   `is_static_metadata`: A Bool indicating if this metadata bundle input is a "static metadata"
    bundle, which are intermediate outputs in the build expected to be referenced by a "main"
    metadata bundle target with the `app_intents` hint in the build graph.

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

*   `app_intents_package_typename`: A File that contains the app intents package typename for
    this particular App Intents metadata bundle, if one was defined. This is only mandatory for
    multi-module App Intents execution-time validation of AppIntentsPackage-s to work.

*   `bundle`: A File representing the metadata bundle file.

*   `should_include_in_bundle`: A Bool indicating if this metadata bundle should be included in the
    final bundle. This is used to exclude "static metadata" bundles that are intermediate
    outputs in the build.

*   `module_name`: A String representing the module name that this bundle was generated from.

*   `owner`: A String based on the label of the target that provided this metadata bundle.
""",
    },
)
