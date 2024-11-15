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

"""AppleResourceHintInfo provider implementation."""

visibility([
    "@build_bazel_rules_apple//apple/hints/...",
    "@build_bazel_rules_apple//apple/internal/aspects/...",
])

def _apple_resource_hint_info_init(
        *,
        needs_swift_srcs,
        needs_transitive_swift_srcs):
    if needs_transitive_swift_srcs and not needs_swift_srcs:
        fail("""
Internal Error: If needs_transitive_swift_srcs is True, that implies needs_swift_srcs should be
True, but instead it was explicitly set to False.
""")
    return {
        "needs_swift_srcs": needs_swift_srcs,
        "needs_transitive_swift_srcs": needs_transitive_swift_srcs,
    }

AppleResourceHintInfo, _ = provider(
    doc = "Provider that propagates aspect hint information that affects Apple resource processing",
    fields = {
        "needs_swift_srcs": """
`Boolean`. True if the hinted target indicates that swift_library sources are to be passed down to
Apple resource processing.
""",
        "needs_transitive_swift_srcs": """
`Boolean`. True if the hinted target indicates that swift_library sources and module names are both
to be received from the target's hinted ancestors as well as forwarded down to descendants, along
with the target's current Swift sources and module name, for the purposes of Apple resource
processing.
""",
    },
    init = _apple_resource_hint_info_init,
)
