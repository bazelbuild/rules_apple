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
    "@build_bazel_rules_apple//apple/bundling/experimental:resources.bzl",
    "NewAppleResourceInfo",
    "resources",
)
load(
    "@build_bazel_rules_apple//common:path_utils.bzl",
    "path_utils",
)
load(
    "@build_bazel_rules_apple//common:define_utils.bzl",
    "define_utils",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
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
    "storyboard",
    "strings",
    "xibs",
]

def _structured_resources_parent_dir(resource):
    """Returns the package relative path for the parent directory of a resource.

    Args:
        resource: The resource for which to calculate the package relative path.

    Returns:
        The package relative path to the parent directory of the resource.
    """
    package_relative = path_utils.owner_relative_path(resource)
    path = paths.dirname(package_relative).rstrip("/")
    return path or None

def _bundle_relative_parent_dir(resource, extension):
    """Returns the bundle relative path to the resource rooted at the bundle.

    Looks for the first instance of a folder with the suffix specified by `extension`, and then
    returns the directory path to the file within the bundle. For example, for a resource with path
    my/package/Contents.bundle/directory/foo.txt and `extension` equal to `"bundle"`, it would
    return Contents.bundle/directory.

    Args:
        resource: The resource for which to calculate the bundle relative path.
        extension: The bundle extension to use when finding the relative path.

    Returns:
        The bundle relative path, rooted at the outermost bundle.
    """
    bundle_path = path_utils.farthest_directory_matching(resource.short_path, extension)
    bundle_relative_path = paths.relativize(resource.short_path, bundle_path)

    parent_dir = paths.basename(bundle_path)
    bundle_relative_dir = paths.dirname(bundle_relative_path).strip("/")
    if bundle_relative_dir:
        parent_dir = paths.join(parent_dir, bundle_relative_dir)
    return parent_dir

def _objc_bundle_parent_dir(resource):
    return _bundle_relative_parent_dir(resource, "bundle")

def _objc_framework_parent_dir(resource):
    return _bundle_relative_parent_dir(resource, "framework")

def _apple_resource_aspect_impl(target, ctx):
    """Implementation of the resource propation aspect."""

    # Kill switch to disable the aspect unless explicitly required.
    if not define_utils.bool_value(
        ctx,
        "apple.experimental.resource_propagation",
        False,
    ):
        return []

    # If the target already propagates a NewAppleResourceInfo, do nothing.
    if NewAppleResourceInfo in target:
        return []

    providers = []

    bucketize_args = {}
    collect_args = {}
    # Owner to attach to the resources as they're being bucketed.
    owner = None
    if ctx.rule.kind == "objc_bundle":
        bucketize_args["parent_dir_param"] = _objc_bundle_parent_dir
        collect_args["res_attrs"] = ["bundle_imports"]

    elif ctx.rule.kind == "objc_bundle_library":
        parent_dir_param = "%s.bundle" % ctx.label.name
        bucketize_args["parent_dir_param"] = parent_dir_param
        collect_args["res_attrs"] = _NATIVE_RESOURCE_ATTRS

        # Collect the specified infoplists that should be merged together. The replacement for
        # objc_bundle_library should handle it within its implementation.
        plist_provider = resources.bucketize_typed(
            ctx.rule.attr,
            bucket_type = "plists",
            res_attrs = ["infoplist", "infoplists"],
            parent_dir_param = parent_dir_param,
        )
        providers.append(plist_provider)

    elif ctx.rule.kind == "objc_library":
        collect_args["res_attrs"] = _NATIVE_RESOURCE_ATTRS
        # Only set objc_library targets as owners if they have srcs. This treats objc_library
        # targets without sources as resource aggregators.
        if ctx.rule.attr.srcs:
            owner = str(ctx.label)

    elif ctx.rule.kind == "swift_library":
        # TODO(kaipi): Properly handle swift modules, this is just a placeholder that won't work in
        # all cases.
        bucketize_args["swift_module"] = ctx.rule.attr.module_name
        collect_args["res_attrs"] = ["resources"]
        owner = str(ctx.label)

    elif ctx.rule.kind == "objc_framework" and ctx.rule.attr.is_dynamic:
        # Treat dynamic objc_framework files as resources that need to be packaged into the
        # Frameworks section of the bundle.
        # TODO(kaipi): Only collect bundleable files (i.e. filter headers and module maps) so we
        # don't propagate them as they're unneeded for bundling.
        frameworks_provider = resources.bucketize_typed(
            ctx.rule.attr,
            bucket_type = "frameworks",
            res_attrs = ["framework_imports"],
            # Since objc_framework contains code that might reference the resources, set the
            # objc_framework target as the owner for these resources.
            owner = str(ctx.label),
            parent_dir_param = _objc_framework_parent_dir,
        )
        providers.append(frameworks_provider)

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
            # TODO(kaipi): Handle collecting structured_resources from objc_bundle_library. It
            # should prepend the parent_dir with the bundle name.
            # TODO(kaipi): Validate that structured_resources doesn't have processable resources,
            # e.g. we shouldn't accept xib files that should be compiled before bundling.
            structured_files = resources.collect(
                ctx.rule.attr,
                res_attrs = ["structured_resources"],
            )
            providers.append(
                resources.bucketize(
                    structured_files,
                    owner = owner,
                    parent_dir_param = _structured_resources_parent_dir,
                ),
            )

    # Get the providers from dependencies.
    for attr in ["data", "deps", "bundles"]:
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
