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

"""Support for restricting access to features based on an allowlist."""

load(
    "@build_bazel_rules_apple//apple/internal/providers:apple_feature_allowlist_info.bzl",
    "AppleFeatureAllowlistInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:package_specs.bzl",
    "parse_package_specs",
)

visibility("public")

def _apple_feature_allowlist_impl(ctx):
    return [AppleFeatureAllowlistInfo(
        allowlist_label = str(ctx.label),
        managed_features = ctx.attr.managed_features,
        package_specs = parse_package_specs(
            package_specs = ctx.attr.packages,
            workspace_name = ctx.label.workspace_name,
        ),
    )]

apple_feature_allowlist = rule(
    attrs = {
        # Swift supports aspect IDs also, maybe pull that over when needed.
        "managed_features": attr.string_list(
            allow_empty = False,
            doc = """\
A list of feature strings that are permitted to be specified by the targets in
the packages matched by the `packages` attribute. This list may include both
feature names and/or negations (a name with a leading `-`); a regular feature
name means that the matching targetsmay explicitly request that the
feature be enabled, and a negated feature means that the target may explicitly
request that the feature be disabled.

For example, `managed_features = ["foo", "-bar"]` means that targets in the
allowlist's packages may request that feature `"foo"` be enabled or that
feature `"bar"` be disabled.
""",
            mandatory = True,
        ),
        "packages": attr.string_list(
            allow_empty = True,
            doc = """\
A list of strings representing packages (possibly recursive) whose targets are
allowed to enable/disable the features in `managed_features`. Each package
pattern is written in the syntax used by the `package_group` function:

*   `//foo/bar`: Targets in the package `//foo/bar` but not in subpackages.

*   `//foo/bar/...`: Targets in the package `//foo/bar` and any of its
    subpackages.

*   A leading `-` excludes packages that would otherwise have been included by
    the patterns in the list.

Exclusions always take priority over inclusions; order in the list is
irrelevant.
""",
            mandatory = True,
        ),
    },
    doc = """\
Limits the ability to request or disable certain features to a set of packages
(and possibly subpackages) in the workspace.

A Apple toolchain target can reference any number (zero or more) of
`apple_feature_allowlist` targets.

A feature that is not managed by any allowlist is allowed to be used by any
package.
""",
    implementation = _apple_feature_allowlist_impl,
)
