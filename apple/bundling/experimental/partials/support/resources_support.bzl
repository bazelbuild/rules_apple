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

"""Support code for resource processing.

All methods in this file follow this convention:
  - The argument signature is (ctx, parent_dir, files) or (ctx, parent_dir, files, swift_module).
    The latter signature is only used for processing resources which need the name of the Swift
    module where the resources are referenced (e.g. Storyboards use it for compiling the full name
    of referenced clases).
  - They all return a struct with the following optional fields:
      - files: A list of tuples with the following structure:
          - Processor location: The location type in the archive where these files should be placed.
          - Parent directory: The structured path on where the files should be placed, within the
            processor location.
          - Files: Depset of files to be placed in the location described, under the name described
            by their basenames.
      - infoplists: A list of files representing plist files that will be merged to compose the main
        bundle's Info.plist.
"""

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
    "@build_bazel_rules_apple//apple/bundling/experimental:resource_actions.bzl",
    "resource_actions",
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

def _infoplists(ctx, parent_dir, files):
    """Processes infoplists.

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

def _mappingmodels(ctx, parent_dir, files):
    """Processes mapping models."""
    grouped_mappingmodels = group_files_by_directory(
        files.to_list(),
        ["xcmappingmodel"],
        attr = "resources",
    )

    output_files = []
    for mappingmodel_path, input_files in grouped_mappingmodels.items():
        compiled_model_name = paths.replace_extension(paths.basename(mappingmodel_path), ".cdm")
        output_file = intermediates.file(
            ctx.actions,
            ctx.label.name,
            paths.join(parent_dir or "", compiled_model_name),
        )

        resource_actions.compile_mappingmodel(ctx, mappingmodel_path, input_files, output_file)

        output_files.append(
            (processor.location.resource, parent_dir, depset(direct = [output_file])),
        )

    return struct(files = output_files)

def _plists_and_strings(ctx, parent_dir, files, force_binary = False):
    """Processes plists and string files.

    If compilation mode is `opt`, or if force_binary is True, the plist files will be compiled into
    binary to make them smaller. Otherwise, they will be copied verbatim to avoid the extra
    processing time.

    Args:
        ctx: The target's context.
        parent_dir: The path under which the files should be placed.
        files: The plist or string files to process.
        force_binary: If true, files will be converted to binary independently of the compilation
            mode.

    Returns:
        A struct containing a `files` field with tuples as described in processor.bzl.
    """

    # If this is not an optimized build, and force_compile is False, then just copy the files
    if not force_binary and ctx.var["COMPILATION_MODE"] != "opt":
        return _noop(ctx, parent_dir, files)

    plist_files = []
    for file in files.to_list():
        plist_file = intermediates.file(
            ctx.actions,
            ctx.label.name,
            paths.join(parent_dir or "", file.basename),
        )
        resource_actions.compile_plist(ctx, file, plist_file)
        plist_files.append(plist_file)

    return struct(
        files = [
            (processor.location.resource, parent_dir, depset(direct = plist_files)),
        ],
    )

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
            # We append something at the end of the name to avoid having X.lproj names in the path.
            # It seems like ibtool will output with different paths depending on whether it is part
            # of a localization bundle. By appending something at the end, we avoid having X.lproj
            # directory names in ibtool's arguments. This is not the case from the storyboard
            # linking action, so we do not change the path there.
            (parent_dir or "") + "_storyboardc",
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
        paths.join("storyboards", parent_dir or "", swift_module or ""),
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

resources_support = struct(
    datamodels = _datamodels,
    infoplists = _infoplists,
    mappingmodels = _mappingmodels,
    noop = _noop,
    plists_and_strings = _plists_and_strings,
    pngs = _pngs,
    storyboards = _storyboards,
    texture_atlases = _texture_atlases,
    xcassets = _xcassets,
    xibs = _xibs,
)
