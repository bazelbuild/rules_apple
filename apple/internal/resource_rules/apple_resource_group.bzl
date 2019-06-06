# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Implementation of apple_resource_group rule."""

load(
    "@build_bazel_rules_apple//apple/internal:resources.bzl",
    "resources",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleResourceInfo",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)

def _apple_resource_group_impl(ctx):
    """Implementation of the apple_resource_group rule."""
    resource_providers = []
    if ctx.attr.resources:
        resource_files = resources.collect(ctx.attr, res_attrs = ["resources"])
        if resource_files:
            resource_providers.append(
                resources.bucketize(resource_files),
            )
    if ctx.attr.structured_resources:
        # TODO(kaipi): Validate that structured_resources doesn't have processable resources,
        # e.g. we shouldn't accept xib files that should be compiled before bundling.
        structured_files = resources.collect(
            ctx.attr,
            res_attrs = ["structured_resources"],
        )

        # Avoid processing PNG files that are referenced through the structured_resources
        # attribute. This is mostly for legacy reasons and should get cleaned up in the future.
        resource_providers.append(
            resources.bucketize(
                structured_files,
                parent_dir_param = partial.make(
                    resources.structured_resources_parent_dir,
                ),
                allowed_buckets = ["strings", "plists"],
            ),
        )

    # Find any targets added through resources which might propagate the AppleResourceInfo
    # provider, for example, other apple_resource_group and apple_resource_bundle targets.
    resource_providers.extend([
        x[AppleResourceInfo]
        for x in ctx.attr.resources
        if AppleResourceInfo in x
    ])

    if resource_providers:
        # If any providers were collected, merge them.
        return [resources.merge_providers(resource_providers)]
    return []

apple_resource_group = rule(
    implementation = _apple_resource_group_impl,
    attrs = {
        "resources": attr.label_list(
            allow_empty = True,
            allow_files = True,
            doc = """
Files to include in the final bundle that depends on this target. Files that are processable
resources, like .xib, .storyboard, .strings, .png, and others, will be processed by the Apple
bundling rules that have those files as dependencies. Other file types that are not processed will
be copied verbatim. These files are placed in the root of the final bundle (e.g.
Payload/foo.app/...) in most cases. However, if they appear to be localized (i.e. are contained in a
directory called *.lproj), they will be placed in a directory of the same name in the app bundle.

You can also add apple_resource_bundle and apple_bundle_import targets into `resources`, and the
resource bundle structures will be propagated into the final bundle.
""",
        ),
        "structured_resources": attr.label_list(
            allow_empty = True,
            allow_files = True,
            doc = """
Files to include in the final application bundle. They are not processed or compiled in any way
besides the processing done by the rules that actually generate them. These files are placed in the
bundle root in the same structure passed to this argument, so ["res/foo.png"] will end up in
res/foo.png inside the bundle.
""",
        ),
    },
    doc = """
This rule encapsulates a target which provides resources to dependents. An
apple_resource_group's resources are put in the top-level Apple bundle dependent.
apple_resource_group targets need to be added to library targets through the data attribute. If
`apple_resource_bundle` or `apple_bundle_import` dependencies are added to `resources`, the resource
bundle structures are maintained at the final top-level bundle.
""",
)
