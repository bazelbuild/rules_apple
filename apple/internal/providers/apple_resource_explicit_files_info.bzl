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

"""AppleResourceExplicitFilesInfo provider implementation."""

visibility([
    "@build_bazel_rules_apple//apple/internal/...",
])

AppleResourceExplicitFilesInfo = provider(
    doc = "Provides a set of explicit files that should be bundled as resources.",
    fields = {
        "files": """\
Required. A `list` or `depset` of `File`s that should be bundled. These files will \
bypass any resource processing logic and be copied as-is directly into the bundle.
""",
    },
)
