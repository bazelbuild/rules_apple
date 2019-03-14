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
    "@build_bazel_rules_apple//apple/internal:file_support.bzl",
    "file_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:resources.bzl",
    "resources",
)
load(
    "@build_bazel_rules_apple//apple/internal:resource_actions.bzl",
    "resource_actions",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleResourceBundleInfo",
    "AppleResourceInfo",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "group_files_by_directory",
)
load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

def _apple_bundle_import_impl(ctx):
    """Implementation of the apple_bundle_import rule."""
    bundle_groups = group_files_by_directory(
        ctx.files.bundle_imports,
        ["bundle"],
        attr = "bundle_imports",
    )

    parent_dir_param = partial.make(
        resources.bundle_relative_parent_dir,
        extension = "bundle",
    )
    resource_provider = resources.bucketize_typed(
        ctx.files.bundle_imports,
        bucket_type = "unprocessed",
        parent_dir_param = parent_dir_param,
    )
    return [
        # TODO(b/120904073): Remove the objc provider. It's here only because objc_library's bundles
        # attribute requires it for now.
        apple_common.new_objc_provider(),
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
This rule encapsulates an already-built bundle. It is defined by a list of files in a .bundle
directory. apple_bundle_import targets need to be added to library targets through the data
attribute, or to other resource targets (i.e. apple_resource_bundle) through the resources
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
        complete_resource_provider = AppleResourceInfo(owners = {})

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
                avoid_buckets = ["pngs"],
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

def _apple_core_ml_library_impl(ctx):
    """Implementation of the apple_core_ml_library."""
    basename = paths.replace_extension(ctx.file.mlmodel.basename, "")

    coremlc_source = ctx.actions.declare_file(
        "{}.m".format(basename),
        sibling = ctx.outputs.source,
    )
    coremlc_header = ctx.actions.declare_file("{}.h".format(basename), sibling = coremlc_source)

    # coremlc doesn't have any configuration on the name of the generated source files, it uses the
    # basename of the mlmodel file instead, so we need to expect those files as outputs.
    resource_actions.generate_objc_mlmodel_sources(
        ctx,
        ctx.file.mlmodel,
        coremlc_source,
        coremlc_header,
    )

    # But we would like our ObjC clients to use <target_name>.h instead, so we create that header
    # too and import the coremlc header.
    public_header = ctx.actions.declare_file("{}.h".format(ctx.attr.header_name))
    ctx.actions.write(
        public_header,
        "#import \"{}\"".format(coremlc_header.path),
    )

    # In order to reference the source file from the macro context, we need to have an implicit
    # output, but those can only reference the name of the target, so we need to symlink the coremlc
    # source into the implicit output. We don't want to do this for the headers since we would like
    # the header to be named as the objc_library target and not the target for this rule.
    file_support.symlink(ctx, coremlc_source, ctx.outputs.source)

    # This rule returns the headers as its outputs so that they can be referenced in the hdrs of the
    # underlying objc_library.
    return [DefaultInfo(files = depset([public_header, coremlc_header]))]

apple_core_ml_library = rule(
    implementation = _apple_core_ml_library_impl,
    attrs = dicts.add(apple_support.action_required_attrs(), {
        "mlmodel": attr.label(
            allow_single_file = ["mlmodel"],
            mandatory = True,
            doc = """
Label to a single mlmodel file from which to generate sources and compile into mlmodelc files.
""",
        ),
        "header_name": attr.string(
            mandatory = True,
            doc = "Private attribute to configure the ObjC header name to be exported.",
        ),
        "_xctoolrunner": attr.label(
            cfg = "host",
            executable = True,
            default = Label("@build_bazel_rules_apple//tools/xctoolrunner"),
        ),
        "_realpath": attr.label(
            cfg = "host",
            allow_single_file = True,
            default = Label("@build_bazel_rules_apple//tools/realpath"),
            executable = True,
        ),
    }),
    output_to_genfiles = True,
    fragments = ["apple"],
    outputs = {
        "source": "%{name}.m",
    },
    doc = """
This rule takes a single mlmodel file and creates a target that can be added as a dependency from
objc_library or swift_library targets. For Swift, just import like any other objc_library target.
For objc_library, this target generates a header named `<target_name>.h` that can be imported from
within the package where this target resides. For example, if this target's label is
`//my/package:coreml`, you can import the header as `#import "my/package/coreml.h"`.

This rule currently only returns an ObjC interface since the Swift generated files do not have the
necessary public interfaces to export its symbols outside of the module.
""",
)
