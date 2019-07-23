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

"""Implementation of apple_resource_bundle rule."""

load(
    "@build_bazel_rules_apple//apple/internal:resources.bzl",
    "resources",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleResourceBundleInfo",
    "AppleResourceInfo",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)

def _apple_resource_bundle_impl(ctx):
    providers = []
    bundle_name = "{}.bundle".format(ctx.attr.bundle_name or ctx.label.name)

    infoplists = resources.collect(ctx.attr, res_attrs = ["infoplists"])
    if infoplists:
        providers.append(
            resources.bucketize_typed(
                infoplists,
                "infoplists",
                parent_dir_param = bundle_name,
            ),
        )

    resource_files = resources.collect(ctx.attr, res_attrs = ["resources"])
    if resource_files:
        providers.append(
            resources.bucketize(
                resource_files,
                parent_dir_param = bundle_name,
            ),
        )

    if ctx.attr.structured_resources:
        # Avoid processing PNG files that are referenced through the structured_resources
        # attribute. This is mostly for legacy reasons and should get cleaned up in the future.
        providers.append(
            resources.bucketize(
                resources.collect(ctx.attr, res_attrs = ["structured_resources"]),
                parent_dir_param = partial.make(
                    resources.structured_resources_parent_dir,
                    parent_dir = bundle_name,
                ),
                allowed_buckets = ["strings", "plists"],
            ),
        )

    # Find any targets added through resources which might propagate the AppleResourceInfo
    # provider, for example, apple_resource_bundle or apple_bundle_import targets.
    resource_providers = [
        x[AppleResourceInfo]
        for x in ctx.attr.resources
        if AppleResourceInfo in x
    ]
    if resource_providers:
        # Process resources that already have the AppleResourceInfo to add the nesting for the
        # current apple_resource_bundle.
        resources_merged_provider = resources.merge_providers(resource_providers)
        providers.append(resources.nest_in_bundle(resources_merged_provider, bundle_name))

    if providers:
        complete_resource_provider = resources.merge_providers(providers)
    else:
        # If there were no resources to bundle, propagate an empty provider to signal that this
        # target has already been processed anyways.
        complete_resource_provider = AppleResourceInfo(
            owners = depset(),
            unowned_resources = depset(),
        )

    return [
        # TODO(b/122578556): Remove this ObjC provider instance.
        apple_common.new_objc_provider(),
        complete_resource_provider,
        AppleResourceBundleInfo(),
    ]

apple_resource_bundle = rule(
    implementation = _apple_resource_bundle_impl,
    attrs = {
        "bundle_name": attr.string(
            doc = """
The desired name of the bundle (without the `.bundle` extension). If this attribute is not set,
then the `name` of the target will be used instead.
""",
        ),
        "infoplists": attr.label_list(
            allow_empty = True,
            allow_files = True,
            doc = """
Infoplist files to be merged into the bundle's Info.plist. Duplicate keys between infoplist files
will cause an error if and only if the values conflict.
Bazel will perform variable substitution on the Info.plist file for the following values (if they
are strings in the top-level dict of the plist):

${BUNDLE_NAME}: This target's name and bundle suffix (.bundle or .app) in the form name.suffix.
${PRODUCT_NAME}: This target's name.
${TARGET_NAME}: This target's name.
The key in ${} may be suffixed with :rfc1034identifier (for example
${PRODUCT_NAME::rfc1034identifier}) in which case Bazel will replicate Xcode's behavior and replace
non-RFC1034-compliant characters with -.
""",
        ),
        "resources": attr.label_list(
            allow_empty = True,
            allow_files = True,
            doc = """
Files to include in the resource bundle. Files that are processable resources, like .xib,
.storyboard, .strings, .png, and others, will be processed by the Apple bundling rules that have
those files as dependencies. Other file types that are not processed will be copied verbatim. These
files are placed in the root of the resource bundle (e.g. Payload/foo.app/bar.bundle/...) in most
cases. However, if they appear to be localized (i.e. are contained in a directory called *.lproj),
they will be placed in a directory of the same name in the app bundle.

You can also add other `apple_resource_bundle` and `apple_bundle_import` targets into `resources`,
and the resource bundle structures will be propagated into the final bundle.
""",
        ),
        "structured_resources": attr.label_list(
            allow_empty = True,
            allow_files = True,
            doc = """
Files to include in the final resource bundle. They are not processed or compiled in any way
besides the processing done by the rules that actually generate them. These files are placed in the
bundle root in the same structure passed to this argument, so ["res/foo.png"] will end up in
res/foo.png inside the bundle.
""",
        ),
    },
    doc = """
This rule encapsulates a target which is provided to dependers as a bundle. An
apple_resource_bundle's resources are put in a resource bundle in the top level Apple bundle
dependent. apple_resource_bundle targets need to be added to library targets through the
data attribute.
""",
)
