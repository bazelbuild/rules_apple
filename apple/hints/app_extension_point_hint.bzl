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

"""Aspect hint for declaring targets that define App Extension Points."""

visibility(["@build_bazel_rules_apple//apple/internal/..."])

AppExtensionPointHintInfo = provider(
    doc = """
Provider used to identify targets providing AppExtensionPoint hints.
""",
    fields = {},
)

def _app_extension_point_hint_impl(_ctx):
    return [AppExtensionPointHintInfo()]

app_extension_point_hint = rule(
    implementation = _app_extension_point_hint_impl,
    doc = """
Declares that the target defines an App Extension Point, which should trigger metadata extraction.
""",
    provides = [AppExtensionPointHintInfo],
)
