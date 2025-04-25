# Copyright 2025 The Bazel Authors. All rights reserved.
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

"""AppleFeatureAllowlistInfo provider implementation for controlling usage a features by the rules_apple."""

visibility("@build_bazel_rules_apple//apple/...")

AppleFeatureAllowlistInfo = provider(
    doc = """\
Describes a set of features and the packages and aspects that are allowed to
request or disable them.

This provider is an internal implementation detail of the rules; users should
not rely on it or assume that its structure is stable
""",
    fields = {
        "allowlist_label": """\
A string containing the label of the `apple_feature_allowlist` target that
created this provider.
""",
        "managed_features": """\
A list of strings representing feature names or their negations that packages in
the `packages` list are allowed to explicitly request or disable.
""",
        "package_specs": """\
A list of `struct` values representing package specifications that indicate
which packages (possibly recursive) can request or disable a feature managed by
the allowlist.
""",
    },
)
