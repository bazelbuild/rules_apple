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

"""Implementation of the `extension_foundation_hint` rule."""

visibility("public")

ExtensionFoundationHintInfo = provider(
    doc = """
Provider used to identify targets providing ExtensionFoundation hints.
""",
    fields = {},
)

def _extension_foundation_hint_impl(_ctx):
    return [ExtensionFoundationHintInfo()]

extension_foundation_hint = rule(
    doc = """
Rule to declare aspect hints appropriate for controlling Extension Foundation metadata processing.
""",
    attrs = {},
    implementation = _extension_foundation_hint_impl,
    provides = [ExtensionFoundationHintInfo],
)
