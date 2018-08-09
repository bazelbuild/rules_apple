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

"""Partial implementations for resource processing.

Resources are procesed according to type, by a series of methods that deal with the specifics for
each resource type. Each of this methods returns a struct, which always have a `files` field
containing resource tuples as described in processor.bzl. Optionally, the structs can also have an
`infoplists` field containing a list of plists that should be merged into the root Info.plist.
"""

load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "group_files_by_directory",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:processor.bzl",
    "processor",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:resources.bzl",
    "NewAppleResourceInfo",
    "resources",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:resource_actions.bzl",
    "resource_actions",
)
load(
    "@build_bazel_rules_apple//common:define_utils.bzl",
    "define_utils",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:outputs.bzl",
    "outputs",
)

def _datamodels(ctx, parent_dir, files, swift_module):
    datamodel_files = files.to_list()

    standalone_models = []
    grouped_models = []

    # Split the datamodels into whether they are inside an xcdatamodeld bundle or not.
    for datamodel in datamodel_files:
        if ".xcdatamodeld/" in datamodel.short_path:
            grouped_models.append(datamodel)
        else:
            standalone_models.append(datamodel)

    # Create a map of highest-level datamodel bundle to the files it contains. Datamodels can be
    # present within standalone .xcdatamodel/ folders or in a versioned bundle, in which many
    # .xcdatamodel/ are contained inside an .xcdatamodeld/ bundle. .xcdatamodeld/ bundles are
    # processed altogether, while .xcdatamodel/ bundles are processed by themselves.
    datamodel_groups = group_files_by_directory(
        grouped_models,
        ["xcdatamodeld"],
        attr = "datamodels",
    )
    datamodel_groups.update(group_files_by_directory(
        standalone_models,
        ["xcdatamodel"],
        attr = "datamodels",
    ))

    output_files = []
    module_name = swift_module or ctx.label.name
    for datamodel_path, files in datamodel_groups.items():
        datamodel_name = paths.replace_extension(paths.basename(datamodel_path), "")

        datamodel_parent = parent_dir
        if datamodel_path.endswith(".xcdatamodeld"):
            basename = datamodel_name + ".momd"
            output_file = intermediates.directory(
                ctx.actions,
                ctx.label.name,
                basename,
            )
            datamodel_parent = paths.join(datamodel_parent or "", basename)
        else:
            output_file = intermediates.file(
                ctx.actions,
                ctx.label.name,
                datamodel_name + ".mom",
            )

        resource_actions.compile_datamodels(
            ctx,
            datamodel_path,
            module_name,
            files.to_list(),
            output_file,
        )
        output_files.append(
            (processor.location.resource, datamodel_parent, depset(direct = [output_file])),
        )

    return struct(files = output_files)

def _frameworks(ctx, parent_dir, files):
    """Processes files that need to be packaged as frameworks."""
    _ignore = [ctx]

    # Filter framework files to remove any header related files from being packaged into the final
    # bundle.
    framework_files = []
    for file in files.to_list():
        file_short_path = file.short_path

        # TODO(b/36435385): Use the new tuple argument format to check for both extensions in one
        # call.
        if file_short_path.endswith(".h"):
            continue
        if file_short_path.endswith(".modulemap"):
            continue
        if "Headers/" in file_short_path:
            continue
        if "PrivateHeaders/" in file_short_path:
            continue
        if "Modules/" in file_short_path:
            continue
        framework_files.append(file)

    return struct(
        files = [
            (processor.location.framework, parent_dir, depset(direct = framework_files)),
        ],
    )

def _plists(ctx, parent_dir, files):
    """Processes plists.

    If parent_dir is not empty, the files will be treated as resource bundle infoplists and are
    merged into one. If parent_dir is empty (or None), the files are be treated as root level
    infoplist and returned to be processed along with other root plists (e.g. xcassets returns a
    plist that needs to be merged into the root.).

    Args:
        ctx: The target's context.
        parent_dir: The path under which the merged Info.plist should be placed for resource
            bundles.
        files: The infoplist files to process.

    Returns:
        A struct containing a `files` field with tuples as described in processor.bzl, and an
        `infoplists` field with the plists that need to be merged for the root Info.plist
    """
    if parent_dir:
        out_plist = intermediates.file(
            ctx.actions,
            ctx.label.name,
            paths.join(parent_dir, "Info.plist"),
        )
        resource_actions.merge_resource_infoplists(
            ctx,
            paths.basename(parent_dir),
            files.to_list(),
            out_plist,
        )
        return struct(
            files = [
                (processor.location.resource, parent_dir, depset(direct = [out_plist])),
            ],
        )
    else:
        return struct(files = [], infoplists = files.to_list())

def _pngs(ctx, parent_dir, files):
    """Register PNG processing actions.

    If compilation mode is `opt`, the PNG files will be copied using `pngcopy` to make them smaller.
    Otherwise, they will be copied verbatim to avoid the extra processing time.

    Args:
        ctx: The target's context.
        parent_dir: The path under which the images should be placed.
        files: The PNG files to process.

    Returns:
        A struct containing a `files` field with tuples as described in processor.bzl.
    """

    # If this is not an optimized build, then just copy the files
    if ctx.var["COMPILATION_MODE"] != "opt":
        return _noop(ctx, parent_dir, files)

    png_files = []
    for file in files.to_list():
        png_path = paths.join(parent_dir or "", file.basename)
        png_file = intermediates.file(ctx.actions, ctx.label.name, png_path)
        resource_actions.copy_png(ctx, file, png_file)
        png_files.append(png_file)

    return struct(files = [(processor.location.resource, parent_dir, depset(direct = png_files))])

def _storyboards(ctx, parent_dir, files, swift_module):
    """Processes storyboard files."""
    swift_module = swift_module or ctx.label.name

    # First, compile all the storyboard files and collect the output folders.
    compiled_storyboardcs = []
    for storyboard in files.to_list():
        storyboardc_path = paths.join(
            parent_dir or "",
            paths.replace_extension(storyboard.basename, ".storyboardc"),
        )
        storyboardc_dir = intermediates.directory(
            ctx.actions,
            ctx.label.name,
            storyboardc_path,
        )
        resource_actions.compile_storyboard(
            ctx,
            swift_module,
            storyboard,
            storyboardc_dir,
        )
        compiled_storyboardcs.append(storyboardc_dir)

    # Then link all the output folders into one folder, which will then be the
    # folder to be bundled.
    linked_storyboard_dir = intermediates.directory(
        ctx.actions,
        ctx.label.name,
        paths.join(parent_dir or "", "storyboards"),
    )
    resource_actions.link_storyboards(
        ctx,
        compiled_storyboardcs,
        linked_storyboard_dir,
    )
    return struct(
        files = [
            (processor.location.resource, parent_dir, depset(direct = [linked_storyboard_dir])),
        ],
    )

def _strings(ctx, parent_dir, files):
    """Processes strings files.

    If compilation mode is `opt`, the string files will be compiled into binary to make them
    smaller. Otherwise, they will be copied verbatim to avoid the extra processing time.

    Args:
        ctx: The target's context.
        parent_dir: The path under which the strings should be placed.
        files: The string files to process.

    Returns:
        A struct containing a `files` field with tuples as described in processor.bzl.
    """

    # If this is not an optimized build, then just copy the files
    if ctx.var["COMPILATION_MODE"] != "opt":
        return _noop(ctx, parent_dir, files)

    string_files = []
    for file in files.to_list():
        string_file = intermediates.file(
            ctx.actions,
            ctx.label.name,
            paths.join(parent_dir or "", file.basename),
        )
        resource_actions.compile_plist(ctx, file, string_file)
        string_files.append(string_file)

    return struct(
        files = [
            (processor.location.resource, parent_dir, depset(direct = string_files)),
        ],
    )

def _texture_atlases(ctx, parent_dir, files):
    """Processes texture atlas files."""
    atlases_groups = group_files_by_directory(
        files.to_list(),
        ["atlas"],
        attr = "texture_atlas",
    )

    atlasc_files = []
    for atlas_path, files in atlases_groups.items():
        atlasc_path = paths.join(
            parent_dir or "",
            paths.replace_extension(paths.basename(atlas_path), ".atlasc"),
        )
        atlasc_dir = intermediates.directory(
            ctx.actions,
            ctx.label.name,
            atlasc_path,
        )
        resource_actions.compile_texture_atlas(
            ctx,
            atlas_path,
            files,
            atlasc_dir,
        )
        atlasc_files.append(atlasc_dir)

    return struct(
        files = [
            (processor.location.resource, parent_dir, depset(direct = atlasc_files)),
        ],
    )

def _xcassets(ctx, parent_dir, files):
    """Processes xcasset files."""

    # Only merge the resulting plist for the top level bundle. For resource
    # bundles, skip generating the plist.
    assets_plist = None
    infoplists = []
    if not parent_dir:
        # TODO(kaipi): Merge this into the top level Info.plist.
        assets_plist_path = paths.join(parent_dir or "", "xcassets-info.plist")
        assets_plist = intermediates.file(
            ctx.actions,
            ctx.label.name,
            assets_plist_path,
        )
        infoplists.append(assets_plist)

    assets_dir = intermediates.directory(
        ctx.actions,
        ctx.label.name,
        paths.join(parent_dir or "", "xcassets"),
    )

    resource_actions.compile_asset_catalog(
        ctx,
        files.to_list(),
        assets_dir,
        assets_plist,
    )

    return struct(
        files = [(processor.location.resource, parent_dir, depset(direct = [assets_dir]))],
        infoplists = infoplists,
    )

def _xibs(ctx, parent_dir, files, swift_module):
    """Processes Xib files."""
    swift_module = swift_module or ctx.label.name
    nib_files = []
    for file in files.to_list():
        nib_name = paths.replace_extension(file.basename, ".nib")
        nib_path = paths.join(parent_dir or "", nib_name)
        nib_file = intermediates.file(ctx.actions, ctx.label.name, nib_path)
        resource_actions.compile_xib(ctx, swift_module, file, nib_file)
        nib_files.append(nib_file)

    return struct(files = [(processor.location.resource, parent_dir, depset(direct = nib_files))])

def _noop(ctx, parent_dir, files):
    """Registers files to be bundled as is."""
    _ignore = [ctx]
    return struct(files = [(processor.location.resource, parent_dir, files)])

def _merge_root_infoplists(ctx, infoplists, out_infoplist):
    """Registers the root Info.plist generation action.

    Args:
      ctx: The target's rule context.
      infoplists: List of plists that should be merged into the root Info.plist.
      out_infoplist: Reference to the output Info plist.

    Returns:
      A list of tuples as described in processor.bzl with the Info.plist file
      reference and the PkgInfo file if required.
    """
    files = [out_infoplist]

    out_pkginfo = None
    if ctx.attr._needs_pkginfo:
        out_pkginfo = ctx.actions.declare_file("PkgInfo", sibling = out_infoplist)
        files.append(out_pkginfo)

    resource_actions.merge_root_infoplists(
        ctx,
        infoplists,
        out_infoplist,
        out_pkginfo,
        bundle_id = ctx.attr.bundle_id,
    )

    return [(processor.location.content, None, depset(direct = files))]

def _deduplicate(resources_provider, avoid_provider, field):
    """Deduplicates and returns resources between 2 providers for a given field.

    Deduplication happens by comparing the target path of a file and the files
    themselves. If there are 2 resources with the same target path but different
    contents, the files will not be deduplicated.

    This approach is naïve in the sense that it deduplicates resources too
    aggressively. We also need to compare the target that references the
    resources so that they are not deduplicated if they are referenced within
    multiple binary-containing bundles.

    Args:
      resources_provider: The provider with the resources to be bundled.
      avoid_provider: The provider with the resources to avoid bundling.
      field: The field to deduplicate resources on.

    Returns:
      A list of tuples with the resources present in avoid_providers removed from
      resources_providers.
    """
    if not avoid_provider or not hasattr(avoid_provider, field):
        return getattr(resources_provider, field)

    # Build a dictionary with the files under each key for the avoided resources.
    avoid_dict = {}
    for parent_dir, swift_module, files in getattr(avoid_provider, field):
        key = "%s_%s" % (parent_dir or "root", swift_module or "root")
        avoid_dict[key] = files.to_list()

    # Get the resources to keep, compare them to the avoid_dict under the same
    # key, and remove the duplicated file references. Then recreate the original
    # tuple with only the remaining files, if any.
    deduped_tuples = []
    for parent_dir, swift_module, files in getattr(resources_provider, field):
        key = "%s_%s" % (parent_dir or "root", swift_module or "root")

        deduped_files = depset([])
        if key in avoid_dict:
            for to_bundle_file in files.to_list():
                if to_bundle_file in avoid_dict[key]:
                    # If the resource file is present in the provider of resources to avoid, and
                    # smart_dedupe is enabled, we compare the owners of the resource through the
                    # owners dictionaries of the providers. If there are owners present in
                    # resources_provider which are not present in avoid_provider, it means that
                    # there is at least one target that declares usage of the resource which is not
                    # accounted for in avoid_provider. If this is the case, we add the resource to
                    # be bundled in the bundle represented by resource_provider.
                    short_path = to_bundle_file.short_path
                    deduped_owners = [
                        o
                        for o in resources_provider.owners[short_path]
                        if o not in avoid_provider.owners[short_path]
                    ]
                    if deduped_owners:
                        deduped_files = depset(
                            direct = [to_bundle_file],
                            transitive = [deduped_files],
                        )
                else:
                    deduped_files = depset(direct = [to_bundle_file], transitive = [deduped_files])
        else:
            deduped_files = depset(transitive = [deduped_files, files])

        if deduped_files:
            deduped_tuples.append((parent_dir, swift_module, deduped_files))

    return deduped_tuples

def _resources_partial_impl(
        ctx,
        plist_attrs = [],
        targets_to_avoid = [],
        top_level_attrs = []):
    """Implementation for the resource processing partial."""
    providers = [
        x[NewAppleResourceInfo]
        for x in ctx.attr.deps
        if NewAppleResourceInfo in x
    ]

    # TODO(kaipi): Bucket top_level_attrs directly instead of collecting and
    # splitting.
    files = resources.collect(ctx.attr, res_attrs = top_level_attrs)
    if files:
        providers.append(resources.bucketize(files, owner = str(ctx.label)))

    if plist_attrs:
        plist_provider = resources.bucketize_typed(
            ctx.attr,
            owner = str(ctx.label),
            bucket_type = "plists",
            res_attrs = plist_attrs,
        )
        providers.append(plist_provider)

    avoid_providers = [
        x[NewAppleResourceInfo]
        for x in targets_to_avoid
        if NewAppleResourceInfo in x
    ]

    avoid_provider = None
    if avoid_providers:
        # Call merge_providers with validate_all_resources_owned set, to ensure that all the
        # resources from dependency bundles have an owner.
        avoid_provider = resources.merge_providers(
            avoid_providers,
            validate_all_resources_owned = True,
        )

    final_provider = resources.merge_providers(providers, default_owner = str(ctx.label))

    # Map of resource provider fields to a tuple that contains the method to use to process those
    # resources and a boolean indicating whether the Swift module is required for that processing.
    provider_field_to_action = {
        "datamodels": (_datamodels, True),
        "frameworks": (_frameworks, False),
        "generics": (_noop, False),
        "plists": (_plists, False),
        "pngs": (_pngs, False),
        "storyboards": (_storyboards, True),
        "strings": (_strings, False),
        "texture_atlases": (_texture_atlases, False),
        "xcassets": (_xcassets, False),
        "xibs": (_xibs, True),
    }

    # List containing all the files that the processor will bundle in their
    # configured location.
    bundle_files = []

    fields = resources.populated_resource_fields(final_provider)

    infoplists = []
    for field in fields:
        processing_func, requires_swift_module = provider_field_to_action[field]
        deduplicated = _deduplicate(final_provider, avoid_provider, field)
        for parent, swift_module, files in deduplicated:
            extra_args = {}

            # Only pass the Swift module name if the type of resource to process
            # requires it.
            if requires_swift_module:
                extra_args["swift_module"] = swift_module
            result = processing_func(ctx, parent, files, **extra_args)
            bundle_files.extend(result.files)
            if hasattr(result, "infoplists"):
                infoplists.extend(result.infoplists)

    out_infoplist = outputs.infoplist(ctx)
    bundle_files.extend(_merge_root_infoplists(ctx, infoplists, out_infoplist))

    return struct(bundle_files = bundle_files, providers = [final_provider])

def resources_partial(plist_attrs = [], targets_to_avoid = [], top_level_attrs = []):
    """Constructor for the resources processing partial.

    This partial collects and propagates all resources that should be bundled in the target being
    processed.

    Args:
        plist_attrs: List of attributes that should be processed as Info plists that should be
            merged and processed.
        targets_to_avoid: List of targets containing resources that should be deduplicated from the
            target being processed.
        top_level_attrs: List of attributes containing resources that need to be processed from the
            target being processed.

    Returns:
        A partial that returns the bundle location of the resources and the resources provider.
    """
    return partial.make(
        _resources_partial_impl,
        plist_attrs = plist_attrs,
        targets_to_avoid = targets_to_avoid,
        top_level_attrs = top_level_attrs,
    )
