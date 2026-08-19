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

"""ExtensionFoundationInfo provider."""

visibility(["@build_bazel_rules_apple//apple/internal/..."])

ExtensionFoundationInfo = provider(
    doc = """
Provider used by app extensions to discover the concrete ExtensionFoundation logic
(boilerplate, property wrappers) implemented by the developer. This is attached
to the extension's source library targets via the `extension_foundation_hint` and
relays the raw files necessary for the extension rule to generate the
`EXAppExtensionAttributes.plist` metadata block it needs in its Info.plist.
""",
    fields = {
        "swiftconstvalues_files": """
A `depset` of `.swiftconstvalues` files carrying metadata from the concrete implementation
of this extension and its transitive dependencies.
""",
    },
)
