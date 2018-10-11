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

"""Implementation of resource bundle/importing rules."""

load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleResourceBundleInfo",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "group_files_by_directory",
)
load(
    "@build_bazel_rules_apple//apple/internal:resources.bzl",
    "NewAppleResourceInfo",
    "resources",
)

def _apple_bundle_import_impl(ctx):
    """Implementation of the apple_bundle_import rule."""
    bundle_groups = group_files_by_directory(
        ctx.files.bundle_imports,
        ["bundle"],
        attr = "bundle_imports",
    )

    if len(bundle_groups) != 1:
        fail(
            "There has to be exactly 1 imported bundle. Found:\n{}".format(
                "\n".join(bundle_groups.keys()),
            ),
        )

    parent_dir_param = partial.make(
        resources.bundle_relative_parent_dir,
        extension = "bundle",
    )
    resource_provider = resources.bucketize(
        ctx.files.bundle_imports,
        parent_dir_param = parent_dir_param,
    )
    return [
        AppleResourceBundleInfo(),
        resource_provider,
    ]

apple_bundle_import = rule(
    implementation = _apple_bundle_import_impl,
    attrs = {
        "bundle_imports": attr.label_list(
            allow_empty = False,
            allow_files = True,
            mandatory = True,
            doc = """
The list of files under a .bundle directory to be propagated to the top-level bundling target.
""",
        ),
    },
    doc = """
This rule encapsulates an already-built bundle. It is defined by a list of files in exactly one
.bundle directory. apple_bundle_import targets need to be added to library targets through the
data attribute, or to other resource targets (i.e. apple_resource_bundle) through the resources
attribute.
""",
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
                avoid_buckets = ["pngs"],
            ),
        )

    # Find any targets added through resources which might propagate the NewAppleResourceInfo
    # provider, for example, apple_resource_bundle or apple_bundle_import targets.
    resource_providers = [
        x[NewAppleResourceInfo]
        for x in ctx.attr.resources
        if NewAppleResourceInfo in x
    ]
    if resource_providers:
        resources_merged_provider = resources.merge_providers(resource_providers)
        providers.append(resources.nest_in_bundle(resources_merged_provider, bundle_name))

    return [
        AppleResourceBundleInfo(),
        resources.merge_providers(providers),
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
