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
  - The argument signature is a combination of; actions, bundle_id, executables, files, parent_dir,
    platform_prerequisites, product_type, and/or rule_label. Only the arguments required for each
    resource action should be referenced directly by keyword in the argument signature and
    implementation. Arguments should not be referenced through kwargs. The presence of kwargs is
    only necessary to ignore unused keywords.
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
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/internal:processor.bzl",
    "processor",
)
load(
    "@build_bazel_rules_apple//apple/internal:resource_actions.bzl",
    "resource_actions",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "group_files_by_directory",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

def _compile_datamodels(
        *,
        actions,
        datamodel_groups,
        label_name,
        parent_dir,
        platform_prerequisites,
        swift_module,
        xctoolrunner_executable):
    "Compiles datamodels into mom files."
    output_files = []
    module_name = swift_module or label_name
    for datamodel_path, files in datamodel_groups.items():
        datamodel_name = paths.replace_extension(paths.basename(datamodel_path), "")

        datamodel_parent = parent_dir
        if datamodel_path.endswith(".xcdatamodeld"):
            basename = datamodel_name + ".momd"
            output_file = intermediates.directory(
                actions,
                label_name,
                basename,
            )
            datamodel_parent = paths.join(datamodel_parent or "", basename)
        else:
            output_file = intermediates.file(
                actions,
                label_name,
                datamodel_name + ".mom",
            )

        resource_actions.compile_datamodels(
            actions = actions,
            datamodel_path = datamodel_path,
            input_files = files.to_list(),
            module_name = module_name,
            output_file = output_file,
            platform_prerequisites = platform_prerequisites,
            xctoolrunner_executable = xctoolrunner_executable,
        )
        output_files.append(
            (processor.location.resource, datamodel_parent, depset(direct = [output_file])),
        )

    return output_files

def _compile_mappingmodels(
        *,
        actions,
        label_name,
        mappingmodel_groups,
        parent_dir,
        platform_prerequisites,
        xctoolrunner_executable):
    """Compiles mapping models into cdm files."""
    output_files = []
    for mappingmodel_path, input_files in mappingmodel_groups.items():
        compiled_model_name = paths.replace_extension(paths.basename(mappingmodel_path), ".cdm")
        output_file = intermediates.file(
            actions,
            label_name,
            paths.join(parent_dir or "", compiled_model_name),
        )

        resource_actions.compile_mappingmodel(
            actions = actions,
            input_files = input_files,
            mappingmodel_path = mappingmodel_path,
            output_file = output_file,
            platform_prerequisites = platform_prerequisites,
            xctoolrunner_executable = xctoolrunner_executable,
        )

        output_files.append(
            (processor.location.resource, parent_dir, depset(direct = [output_file])),
        )

    return output_files

def _asset_catalogs(
        *,
        actions,
        bundle_id,
        executables,
        files,
        parent_dir,
        platform_prerequisites,
        product_type,
        rule_label,
        **kwargs):
    """Processes asset catalog files."""

    # Only merge the resulting plist for the top level bundle. For resource
    # bundles, skip generating the plist.
    assets_plist = None
    infoplists = []
    if not parent_dir:
        # TODO(kaipi): Merge this into the top level Info.plist.
        assets_plist_path = paths.join(parent_dir or "", "xcassets-info.plist")
        assets_plist = intermediates.file(
            actions,
            rule_label.name,
            assets_plist_path,
        )
        infoplists.append(assets_plist)

    assets_dir = intermediates.directory(
        actions,
        rule_label.name,
        paths.join(parent_dir or "", "xcassets"),
    )

    resource_actions.compile_asset_catalog(
        actions = actions,
        asset_files = files.to_list(),
        bundle_id = bundle_id,
        output_dir = assets_dir,
        output_plist = assets_plist,
        platform_prerequisites = platform_prerequisites,
        product_type = product_type,
        xctoolrunner_executable = executables._xctoolrunner,
    )

    return struct(
        files = [(processor.location.resource, parent_dir, depset(direct = [assets_dir]))],
        infoplists = infoplists,
    )

def _datamodels(
        *,
        actions,
        executables,
        files,
        parent_dir,
        platform_prerequisites,
        rule_label,
        swift_module,
        **kwargs):
    "Processes datamodel related files."
    datamodel_files = files.to_list()

    standalone_datamodels = []
    grouped_datamodels = []
    mappingmodels = []

    # Split the datamodels into whether they are inside an xcdatamodeld bundle or not.
    for datamodel in datamodel_files:
        datamodel_short_path = datamodel.short_path
        if ".xcmappingmodel/" in datamodel_short_path:
            mappingmodels.append(datamodel)
        elif ".xcdatamodeld/" in datamodel_short_path:
            grouped_datamodels.append(datamodel)
        else:
            standalone_datamodels.append(datamodel)

    # Create a map of highest-level datamodel bundle to the files it contains. Datamodels can be
    # present within standalone .xcdatamodel/ folders or in a versioned bundle, in which many
    # .xcdatamodel/ are contained inside an .xcdatamodeld/ bundle. .xcdatamodeld/ bundles are
    # processed altogether, while .xcdatamodel/ bundles are processed by themselves.
    datamodel_groups = group_files_by_directory(
        grouped_datamodels,
        ["xcdatamodeld"],
        attr = "datamodels",
    )
    datamodel_groups.update(group_files_by_directory(
        standalone_datamodels,
        ["xcdatamodel"],
        attr = "datamodels",
    ))
    mappingmodel_groups = group_files_by_directory(
        mappingmodels,
        ["xcmappingmodel"],
        attr = "resources",
    )

    output_files = list(_compile_datamodels(
        actions = actions,
        label_name = rule_label.name,
        parent_dir = parent_dir,
        swift_module = swift_module,
        datamodel_groups = datamodel_groups,
        platform_prerequisites = platform_prerequisites,
        xctoolrunner_executable = executables._xctoolrunner,
    ))
    output_files.extend(_compile_mappingmodels(
        actions = actions,
        label_name = rule_label.name,
        parent_dir = parent_dir,
        mappingmodel_groups = mappingmodel_groups,
        platform_prerequisites = platform_prerequisites,
        xctoolrunner_executable = executables._xctoolrunner,
    ))

    return struct(files = output_files)

def _infoplists(
        *,
        actions,
        executables,
        files,
        parent_dir,
        platform_prerequisites,
        rule_label,
        **kwargs):
    """Processes infoplists.

    If parent_dir is not empty, the files will be treated as resource bundle infoplists and are
    merged into one. If parent_dir is empty (or None), the files are be treated as root level
    infoplist and returned to be processed along with other root plists (e.g. asset catalog
    processing returns a plist that needs to be merged into the root).

    Args:
        actions: The actions provider from `ctx.actions`.
        executables: Struct containing executable files defined by a rule.
        files: The infoplist files to process.
        parent_dir: The path under which the merged Info.plist should be placed for resource bundles.
        platform_prerequisites: Struct containing information on the platform being targeted.
        rule_label: The label of the target being analyzed.
        **kwargs: Extra parameters forwarded to this support macro.

    Returns:
        A struct containing a `files` field with tuples as described in processor.bzl, and an
        `infoplists` field with the plists that need to be merged for the root Info.plist
    """
    if parent_dir:
        input_files = files.to_list()
        processed_origins = {}
        out_plist = intermediates.file(
            actions,
            rule_label.name,
            paths.join(parent_dir, "Info.plist"),
        )
        processed_origins[out_plist.short_path] = [f.short_path for f in input_files]
        resource_actions.merge_resource_infoplists(
            actions = actions,
            bundle_name_with_extension = paths.basename(parent_dir),
            input_files = input_files,
            output_plist = out_plist,
            platform_prerequisites = platform_prerequisites,
            plisttool = executables._plisttool,
            rule_label = rule_label,
        )
        return struct(
            files = [
                (processor.location.resource, parent_dir, depset(direct = [out_plist])),
            ],
            processed_origins = processed_origins,
        )
    else:
        return struct(files = [], infoplists = files.to_list())

def _metals(
        *,
        actions,
        rule_label,
        parent_dir,
        platform_prerequisites,
        files,
        output_filename = "default.metallib",
        **kwargs):
    """Processes metal files.

    The metal files will be compiled into a Metal library named `default.metallib`.

    Args:
        actions: The actions provider from `ctx.actions`.
        rule_label: The label of the target being analyzed.
        parent_dir: The path under which the library should be placed.
        platform_prerequisites: Struct containing information on the platform being targeted.
        files: The metal files to process.
        output_filename: The output .metallib filename.
        **kwargs: Ignored

    Returns:
        A struct containing a `files` field with tuples as described in processor.bzl.
    """
    metallib_path = paths.join(parent_dir or "", output_filename)
    metallib_file = intermediates.file(
        actions,
        rule_label.name,
        metallib_path,
    )
    resource_actions.compile_metals(
        actions = actions,
        input_files = files.to_list(),
        output_file = metallib_file,
        platform_prerequisites = platform_prerequisites,
    )

    return struct(
        files = [(
            processor.location.resource,
            parent_dir,
            depset(direct = [metallib_file]),
        )],
    )

def _mlmodels(
        *,
        actions,
        executables,
        files,
        parent_dir,
        platform_prerequisites,
        rule_label,
        **kwargs):
    """Processes mlmodel files."""

    mlmodel_bundles = []
    infoplists = []
    for file in files.to_list():
        basename = file.basename

        output_bundle = intermediates.directory(
            actions,
            rule_label.name,
            paths.join(parent_dir or "", paths.replace_extension(basename, ".mlmodelc")),
        )
        output_plist = intermediates.file(
            actions,
            rule_label.name,
            paths.join(parent_dir or "", paths.replace_extension(basename, ".plist")),
        )

        resource_actions.compile_mlmodel(
            actions = actions,
            input_file = file,
            output_bundle = output_bundle,
            output_plist = output_plist,
            platform_prerequisites = platform_prerequisites,
            xctoolrunner_executable = executables._xctoolrunner,
        )

        mlmodel_bundles.append(
            (
                processor.location.resource,
                paths.join(parent_dir or "", output_bundle.basename),
                depset(direct = [output_bundle]),
            ),
        )
        infoplists.append(output_plist)

    return struct(
        files = mlmodel_bundles,
        infoplists = infoplists,
    )

def _plists_and_strings(
        *,
        actions,
        files,
        force_binary = False,
        rule_label,
        parent_dir,
        platform_prerequisites,
        **kwargs):
    """Processes plists and string files.

    If compilation mode is `opt`, or if force_binary is True, the plist files will be compiled into
    binary to make them smaller. Otherwise, they will be copied verbatim to avoid the extra
    processing time.

    Args:
        actions: The actions provider from `ctx.actions`.
        files: The plist or string files to process.
        force_binary: If true, files will be converted to binary independently of the compilation
            mode.
        rule_label: The label of the target being analyzed.
        parent_dir: The path under which the files should be placed.
        platform_prerequisites: Struct containing information on the platform being targeted.
        **kwargs: Extra parameters forwarded to this support macro.

    Returns:
        A struct containing a `files` field with tuples as described in processor.bzl.
    """

    # If this is not an optimized build, and force_compile is False, then just copy the files
    if not force_binary and platform_prerequisites.config_vars["COMPILATION_MODE"] != "opt":
        return _noop(
            parent_dir = parent_dir,
            files = files,
        )

    plist_files = []
    processed_origins = {}
    for file in files.to_list():
        plist_file = intermediates.file(
            actions,
            rule_label.name,
            paths.join(parent_dir or "", file.basename),
        )
        processed_origins[plist_file.short_path] = [file.short_path]
        resource_actions.compile_plist(
            actions = actions,
            input_file = file,
            output_file = plist_file,
            platform_prerequisites = platform_prerequisites,
        )
        plist_files.append(plist_file)

    return struct(
        files = [
            (processor.location.resource, parent_dir, depset(direct = plist_files)),
        ],
        processed_origins = processed_origins,
    )

def _pngs(
        *,
        actions,
        files,
        parent_dir,
        platform_prerequisites,
        rule_label,
        **kwargs):
    """Register PNG processing actions.

    The PNG files will be copied using `pngcopy` to make them smaller.

    Args:
        actions: The actions provider from `ctx.actions`.
        files: The PNG files to process.
        parent_dir: The path under which the images should be placed.
        platform_prerequisites: Struct containing information on the platform being targeted.
        rule_label: The label of the target being analyzed.
        **kwargs: Extra parameters forwarded to this support macro.

    Returns:
        A struct containing a `files` field with tuples as described in processor.bzl.
    """
    png_files = []
    processed_origins = {}
    for file in files.to_list():
        png_path = paths.join(parent_dir or "", file.basename)
        png_file = intermediates.file(actions, rule_label.name, png_path)
        processed_origins[png_file.short_path] = [file.short_path]
        resource_actions.copy_png(
            actions = actions,
            input_file = file,
            output_file = png_file,
            platform_prerequisites = platform_prerequisites,
        )
        png_files.append(png_file)

    return struct(
        files = [
            (processor.location.resource, parent_dir, depset(direct = png_files)),
        ],
        processed_origins = processed_origins,
    )

def _storyboards(
        *,
        actions,
        executables,
        files,
        parent_dir,
        platform_prerequisites,
        rule_label,
        swift_module,
        **kwargs):
    """Processes storyboard files."""
    swift_module = swift_module or rule_label.name

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
            actions,
            rule_label.name,
            storyboardc_path,
        )
        resource_actions.compile_storyboard(
            actions = actions,
            input_file = storyboard,
            output_dir = storyboardc_dir,
            platform_prerequisites = platform_prerequisites,
            swift_module = swift_module,
            xctoolrunner_executable = executables._xctoolrunner,
        )
        compiled_storyboardcs.append(storyboardc_dir)

    # Then link all the output folders into one folder, which will then be the
    # folder to be bundled.
    linked_storyboard_dir = intermediates.directory(
        actions,
        rule_label.name,
        paths.join("storyboards", parent_dir or "", swift_module or ""),
    )
    resource_actions.link_storyboards(
        actions = actions,
        output_dir = linked_storyboard_dir,
        platform_prerequisites = platform_prerequisites,
        storyboardc_dirs = compiled_storyboardcs,
        xctoolrunner_executable = executables._xctoolrunner,
    )
    return struct(
        files = [
            (processor.location.resource, parent_dir, depset(direct = [linked_storyboard_dir])),
        ],
    )

def _texture_atlases(
        *,
        actions,
        files,
        parent_dir,
        platform_prerequisites,
        rule_label,
        **kwargs):
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
            actions,
            rule_label.name,
            atlasc_path,
        )
        resource_actions.compile_texture_atlas(
            actions = actions,
            input_files = files,
            input_path = atlas_path,
            output_dir = atlasc_dir,
            platform_prerequisites = platform_prerequisites,
        )
        atlasc_files.append(atlasc_dir)

    return struct(
        files = [
            (processor.location.resource, parent_dir, depset(direct = atlasc_files)),
        ],
    )

def _xibs(
        *,
        actions,
        executables,
        files,
        parent_dir,
        platform_prerequisites,
        rule_label,
        swift_module,
        **kwargs):
    """Processes Xib files."""
    swift_module = swift_module or rule_label.name
    nib_files = []
    for file in files.to_list():
        basename = paths.replace_extension(file.basename, "")
        out_path = paths.join("nibs", parent_dir or "", basename)
        out_dir = intermediates.directory(actions, rule_label.name, out_path)
        resource_actions.compile_xib(
            actions = actions,
            input_file = file,
            output_dir = out_dir,
            platform_prerequisites = platform_prerequisites,
            swift_module = swift_module,
            xctoolrunner_executable = executables._xctoolrunner,
        )
        nib_files.append(out_dir)

    return struct(files = [(processor.location.resource, parent_dir, depset(direct = nib_files))])

def _noop(
        *,
        parent_dir,
        files,
        **kwargs):
    """Registers files to be bundled as is."""
    processed_origins = {}
    for file in files.to_list():
        processed_origins[file.short_path] = [file.short_path]
    return struct(
        files = [(processor.location.resource, parent_dir, files)],
        processed_origins = processed_origins,
    )

resources_support = struct(
    asset_catalogs = _asset_catalogs,
    datamodels = _datamodels,
    infoplists = _infoplists,
    metals = _metals,
    mlmodels = _mlmodels,
    noop = _noop,
    plists_and_strings = _plists_and_strings,
    pngs = _pngs,
    storyboards = _storyboards,
    texture_atlases = _texture_atlases,
    xibs = _xibs,
)
