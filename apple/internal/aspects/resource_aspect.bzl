# Copyright 2018 The Bazel Authors. All rights reserved.
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

"""Implementation of the resource propagation aspect."""

load(
    "@build_bazel_rules_apple//apple/internal:resources.bzl",
    "resources",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleResourceInfo",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "SwiftInfo",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)

# List of native resource attributes to use to collect by default. This list should dissapear in the
# long term; objc_library will remove the resource specific attributes and the native rules (that
# have these attributes) will dissapear. The new resource rules will either have specific attributes
# or use data, but in any of those cases, this list won't be used as if there are specific
# attributes, we will not merge them to split them again.
_NATIVE_RESOURCE_ATTRS = [
    "asset_catalogs",
    "data",
    "datamodels",
    "resources",
    "storyboards",
    "strings",
    "xibs",
]

def _apple_resource_aspect_impl(target, ctx):
    """Implementation of the resource propation aspect."""

    # If the target already propagates a AppleResourceInfo, do nothing.
    if AppleResourceInfo in target:
        return []

    providers = []

    bucketize_args = {}
    collect_args = {}

    # Owner to attach to the resources as they're being bucketed.
    owner = None

    if ctx.rule.kind == "objc_library":
        collect_args["res_attrs"] = _NATIVE_RESOURCE_ATTRS

        # Only set objc_library targets as owners if they have srcs, non_arc_srcs or deps. This
        # treats objc_library targets without sources as resource aggregators.
        if ctx.rule.attr.srcs or ctx.rule.attr.non_arc_srcs or ctx.rule.attr.deps:
            owner = str(ctx.label)

        if hasattr(ctx.rule.attr, "bundles"):
            # Collect objc_library's bundles dependencies and propagate them.
            providers.extend([
                x[AppleResourceInfo]
                for x in ctx.rule.attr.bundles
            ])

    elif ctx.rule.kind == "swift_library":
        bucketize_args["swift_module"] = target[SwiftInfo].module_name
        collect_args["res_attrs"] = ["data"]
        owner = str(ctx.label)

    elif ctx.rule.kind == "apple_binary":
        # Set the binary targets as the default_owner to avoid losing ownership information when
        # aggregating dependencies resources that have an owners on one branch, and that don't have
        # an owner on another branch. When rules_apple stops using apple_binary intermediaries this
        # should be removed as there would not be an intermediate aggregator.
        owner = str(ctx.label)

    elif apple_common.Objc in target:
        # TODO(kaipi): Clean up usages of the ObjcProvider as means to propagate resources, then
        # remove this case.
        resource_zips = getattr(target[apple_common.Objc], "merge_zip", None)
        if resource_zips:
            merge_zips = resource_zips.to_list()
            merge_zips_provider = resources.bucketize_typed(
                merge_zips,
                bucket_type = "resource_zips",
            )
            providers.append(merge_zips_provider)

    # Collect all resource files related to this target.
    files = resources.collect(ctx.rule.attr, **collect_args)
    if files:
        providers.append(
            resources.bucketize(files, owner = owner, **bucketize_args),
        )

    # If the target has structured_resources, we need to process them with a different
    # parent_dir_param
    if hasattr(ctx.rule.attr, "structured_resources"):
        if ctx.rule.attr.structured_resources:
            # TODO(kaipi): Validate that structured_resources doesn't have processable resources,
            # e.g. we shouldn't accept xib files that should be compiled before bundling.
            structured_files = resources.collect(
                ctx.rule.attr,
                res_attrs = ["structured_resources"],
            )

            # Avoid processing PNG files that are referenced through the structured_resources
            # attribute. This is mostly for legacy reasons and should get cleaned up in the future.
            providers.append(
                resources.bucketize(
                    structured_files,
                    owner = owner,
                    parent_dir_param = partial.make(
                        resources.structured_resources_parent_dir,
                        parent_dir = None,
                    ),
                    avoid_buckets = ["pngs"],
                ),
            )

    # Get the providers from dependencies.
    for attr in ["deps", "data"]:
        if hasattr(ctx.rule.attr, attr):
            providers.extend([
                x[AppleResourceInfo]
                for x in getattr(ctx.rule.attr, attr)
                if AppleResourceInfo in x
            ])

    if providers:
        # If any providers were collected, merge them.
        return [resources.merge_providers(providers, default_owner = owner)]
    return []

apple_resource_aspect = aspect(
    implementation = _apple_resource_aspect_impl,
    # TODO(kaipi): The aspect should also propagate through the data attribute.
    attr_aspects = ["bundles", "deps"],
    doc = """Aspect that collects and propagates resource information to be bundled by a top-level
bundling rule.""",
)
