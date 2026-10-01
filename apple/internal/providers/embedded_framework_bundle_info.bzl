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

"""AppleEmbeddedFrameworkBundleInfo provider implementation.

Used for embedded framework bundle propagation.
"""

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

AppleEmbeddedFrameworkBundleInfo = provider(
    doc = """
Internal provider used to propagate embedded framework bundles and their signed framework paths
that a top-level bundling rule will need to package into its `Frameworks` directory.
""",
    fields = {
        "frameworks": """
A depset with the zipped archives or files of framework bundles that need to be packaged into the
Frameworks section of the packaging bundle.
""",
        "signed_frameworks": """
A depset of strings referencing frameworks that have already been codesigned.
""",
    },
)
