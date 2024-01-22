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
    "//apple/hints/...",
    "//apple/internal/aspects/...",
])

AppleResourceHintInfo = provider(
    doc = "Provider that propagates aspect hint information that affects Apple resource processing",
    fields = {
        "needs_swift_srcs": """
`Boolean`. True if the hinted target indicates that swift_library sources are to be passed down to
Apple resource processing.
""",
    },
)
