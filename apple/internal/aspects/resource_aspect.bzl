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
    "NewAppleResourceInfo",
    "resources",
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
# TODO(b/121042700): Enable objc_library resource collection in data.
_NATIVE_RESOURCE_ATTRS = [
    "asset_catalogs",
    "datamodels",
    "resources",
    "storyboards",
    "strings",
    "xibs",
]

def _apple_resource_aspect_impl(target, ctx):
    """Implementation of the resource propation aspect."""

    # If the target already propagates a NewAppleResourceInfo, do nothing.
    if NewAppleResourceInfo in target:
        return []

    providers = []

    bucketize_args = {}
    collect_args = {}

    # Owner to attach to the resources as they're being bucketed.
    owner = None

    # TODO(b/33618143): Remove the objc_bundle and objc_bundle_library cases when they are removed
    # from native bazel.
    if ctx.rule.kind == "objc_bundle":
        bucketize_args["parent_dir_param"] = partial.make(
            resources.bundle_relative_parent_dir,
            extension = "bundle",
        )
        collect_args["res_attrs"] = ["bundle_imports"]

    elif ctx.rule.kind == "objc_bundle_library":
        parent_dir_param = "%s.bundle" % ctx.label.name
        bucketize_args["parent_dir_param"] = parent_dir_param
        collect_args["res_attrs"] = _NATIVE_RESOURCE_ATTRS

        # Collect the specified infoplists that should be merged together. The replacement for
        # objc_bundle_library should handle it within its implementation.
        plists = resources.collect(ctx.rule.attr, res_attrs = ["infoplist", "infoplists"])
        plist_provider = resources.bucketize_typed(
            plists,
            bucket_type = "infoplists",
            parent_dir_param = parent_dir_param,
        )
        providers.append(plist_provider)

        # Nest bundles added through the bundles attribute in objc_bundle_library.
        if ctx.rule.attr.bundles:
            bundle_merged_provider = resources.merge_providers(
                [x[NewAppleResourceInfo] for x in ctx.rule.attr.bundles],
            )

            providers.append(resources.nest_in_bundle(bundle_merged_provider, parent_dir_param))

    elif ctx.rule.kind == "objc_library":
        collect_args["res_attrs"] = _NATIVE_RESOURCE_ATTRS

        # Only set objc_library targets as owners if they have srcs, non_arc_srcs or deps. This
        # treats objc_library targets without sources as resource aggregators.
        if ctx.rule.attr.srcs or ctx.rule.attr.non_arc_srcs or ctx.rule.attr.deps:
            owner = str(ctx.label)

        # Collect objc_library's bundles dependencies and propagate them.
        providers.extend([
            x[NewAppleResourceInfo]
            for x in ctx.rule.attr.bundles
        ])

    elif ctx.rule.kind == "swift_library":
        bucketize_args["swift_module"] = target[SwiftInfo].module_name
        collect_args["res_attrs"] = ["data", "resources"]
        owner = str(ctx.label)

    elif ctx.rule.kind == "apple_binary" or ctx.rule.kind == "apple_stub_binary":
        # Set the binary targets as the default_owner to avoid losing ownership information when
        # aggregating dependencies resources that have an owners on one branch, and that don't have
        # an owner on another branch. When rules_apple stops using apple_binary intermediaries this
        # should be removed as there would not be an intermediate aggregator.
        owner = str(ctx.label)

    elif apple_common.Objc in target:
        # TODO(kaipi): Clean up usages of the ObjcProvider as means to propagate resources, then
        # remove this case.
        if hasattr(target[apple_common.Objc], "merge_zip"):
            merge_zips = target[apple_common.Objc].merge_zip.to_list()
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

            if ctx.rule.kind == "objc_bundle_library":
                # TODO(kaipi): Once we remove the native objc_bundle_library, there won't be a need
                # for repeating the bundle name here.
                structured_parent_dir = "%s.bundle" % ctx.label.name
            else:
                structured_parent_dir = None

            # Avoid processing PNG files that are referenced through the structured_resources
            # attribute. This is mostly for legacy reasons and should get cleaned up in the future.
            providers.append(
                resources.bucketize(
                    structured_files,
                    owner = owner,
                    parent_dir_param = partial.make(
                        resources.structured_resources_parent_dir,
                        parent_dir = structured_parent_dir,
                    ),
                    avoid_buckets = ["pngs"],
                ),
            )

    # Get the providers from dependencies.
    for attr in ["deps", "data"]:
        if hasattr(ctx.rule.attr, attr):
            providers.extend([
                x[NewAppleResourceInfo]
                for x in getattr(ctx.rule.attr, attr)
                if NewAppleResourceInfo in x
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
