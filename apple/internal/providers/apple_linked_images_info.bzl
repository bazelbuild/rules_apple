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

"""AppleLinkedImagesInfo provider implementation."""

visibility("@build_bazel_rules_apple//apple/internal/...")

AppleLinkedImagesInfo = provider(
    doc = """
Private provider that propagates the linkmaps of a linked Apple binary and of every image that the
rules know will be loaded into the same process as that binary (embedded dynamic frameworks,
transitively, and the bundle loader of a bundle).

Only propagated when the `apple.validate_duplicate_linked_objects` feature is enabled, so that
targets loading this image can check that no object file is linked into more than one image.
""",
    fields = {
        "linkmaps": """
A `depset` of `struct`s, one per image and architecture, with the following fields:

*   `architecture`: The architecture of the linked binary (e.g. `arm64`).
*   `image`: A string naming the image in messages, i.e. the label of the target that linked it.
*   `linkmap`: The ld64 linkmap `File` of the linked binary.
""",
    },
)
