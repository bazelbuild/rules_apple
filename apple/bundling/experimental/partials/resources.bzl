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

Resources are procesed according to type, by a series of methods that deal with
the specifics for each resource type. Each of this methods returns a struct,
which always have a `files` field containing resource tuples as described in
processor.bzl. Optionally, the structs can also have an `infoplists` field
containing a list of plists that should be merged into the root Info.plist.
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

def _datamodels(ctx, parent_dir, files, swift_module):
  datamodel_files = files.to_list()

  standalone_models = []
  grouped_models = []
  # Split the datamodels into whether they are inside an xcdatamodeld bundle or
  # not.
  for datamodel in datamodel_files:
    if ".xcdatamodeld/" in datamodel.short_path:
      grouped_models.append(datamodel)
    else:
      standalone_models.append(datamodel)

  # Create a map of highest-level datamodel bundle to the files it contains.
  # Datamodels can be present within standalone .xcdatamodel/ folders or in a
  # versioned bundle, in which many .xcdatamodel/ are contained inside an
  # .xcdatamodeld/ bundle. .xcdatamodeld/ bundles are processed altogether,
  # while .xcdatamodel/ bundles are processed by themselves.
  datamodel_groups = group_files_by_directory(
      grouped_models, ["xcdatamodeld"],
  )
  datamodel_groups.update(group_files_by_directory(
      standalone_models, ["xcdatamodel"],
  ))

  output_files = []
  module_name = swift_module or ctx.label.name
  for datamodel_path, files in datamodel_groups.items():
    datamodel_name = paths.replace_extension(paths.basename(datamodel_path), "")

    datamodel_parent = parent_dir
    if datamodel_path.endswith(".xcdatamodeld"):
      basename = datamodel_name + ".momd"
      output_file = intermediates.directory(
          ctx.actions, ctx.label.name, basename,
      )
      datamodel_parent = paths.join(datamodel_parent or "", basename)
    else:
      output_file = intermediates.file(
          ctx.actions, ctx.label.name, datamodel_name + ".mom",
      )

    resource_actions.compile_datamodels(
        ctx, datamodel_path, module_name, files.to_list(), output_file,
    )
    output_files.append(
        (processor.location.resource, datamodel_parent, depset([output_file]))
    )

  return struct(files=output_files)

def _plists(ctx, parent_dir, files):
  """Processes plists.

  If parent_dir is not empty, the files will be treated as resource bundle
  infoplists and are merged into one. If parent_dir is empty (or None), the
  files are be treated as root level infoplist and returned to be processed
  along with other root plists (e.g. xcassets returns a plist that needs to be
  merged into the root.).

  Args:
    ctx: The target's context.
    parent_dir: The path under which the merged Info.plist should be placed for
      resource bundles.
    files: The infoplist files to process.

  Returns:
    A struct containing a `files` field with tuples as described in
    processor.bzl, and an `infoplists` field with the plists that need to be
    merged for the root Info.plist
  """
  if parent_dir:
    out_plist = intermediates.file(
        ctx.actions, ctx.label.name, paths.join(parent_dir, "Info.plist"),
    )
    resource_actions.merge_resource_infoplists(
        ctx, paths.basename(parent_dir), files.to_list(), out_plist,
    )
    return struct(
        files=[(processor.location.resource, parent_dir, depset([out_plist]))],
    )
  else:
    return struct(files=[], infoplists=files.to_list())

def _pngs(ctx, parent_dir, files):
  """Register PNG processing actions.

  If compilation mode is `opt`, the PNG files will be copied using `pngcopy` to
  make them smaller. Otherwise, they will be copied verbatim to avoid the extra
  processing time.

  Args:
    ctx: The target's context.
    parent_dir: The path under which the images should be placed.
    files: The PNG files to process.

  Returns:
    A struct containing a `files` field with tuples as described in
    processor.bzl.
  """
  # If this is not an optimized build, then just copy the files
  if ctx.var["COMPILATION_MODE"] != "opt":
    return _noop(ctx, parent_dir, files)

  png_files = []
  for file in files.to_list():
    png_path = paths.join(parent_dir or "", file.basename)
    png_file = intermediates.file(ctx.actions, ctx.label.name, png_path)
    resource_actions.png_copy(ctx, file, png_file)
    png_files.append(png_file)

  return struct(
      files=[(processor.location.resource, parent_dir, depset(png_files))],
  )

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
        ctx.actions, ctx.label.name, storyboardc_path,
    )
    resource_actions.compile_storyboard(
        ctx, swift_module, storyboard, storyboardc_dir,
    )
    compiled_storyboardcs.append(storyboardc_dir)

  # Then link all the output folders into one folder, which will then be the
  # folder to be bundled.
  linked_storyboard_dir = intermediates.directory(
      ctx.actions, ctx.label.name, paths.join(parent_dir or "", "storyboards")
  )
  resource_actions.link_storyboards(
      ctx, compiled_storyboardcs, linked_storyboard_dir,
  )
  return struct(
      files=[(
          processor.location.resource, parent_dir, depset([linked_storyboard_dir])
      )],
  )

def _strings(ctx, parent_dir, files):
  """Processes strings files.

  If compilation mode is `opt`, the string files will be compiled into binary
  to make them smaller. Otherwise, they will be copied verbatim to avoid the
  extra processing time.

  Args:
    ctx: The target's context.
    parent_dir: The path under which the strings should be placed.
    files: The string files to process.

  Returns:
    A struct containing a `files` field with tuples as described in
    processor.bzl.
  """
  # If this is not an optimized build, then just copy the files
  if ctx.var["COMPILATION_MODE"] != "opt":
    return _noop(ctx, parent_dir, files)

  string_files = []
  for file in files.to_list():
    string_file = intermediates.file(
        ctx.actions, ctx.label.name, paths.join(parent_dir or "", file.basename),
    )
    resource_actions.compile_plist(ctx, file, string_file)
    string_files.append(string_file)

  return struct(
      files=[(processor.location.resource, parent_dir, depset(string_files))],
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
        ctx.actions, ctx.label.name, assets_plist_path,
    )
    infoplists.append(assets_plist)

  assets_dir = intermediates.directory(
      ctx.actions, ctx.label.name, paths.join(parent_dir or "", "xcassets"),
  )

  resource_actions.compile_asset_catalog(
      ctx, files.to_list(), assets_dir, assets_plist,
  )

  return struct(
      files=[(processor.location.resource, parent_dir, depset([assets_dir]))],
      infoplists=infoplists,
  )

def _noop(ctx, parent_dir, files):
  """Registers files to be bundled as is."""
  _ignore = [ctx]
  return struct(files=[(processor.location.resource, parent_dir, files)])

def _merge_root_infoplists(ctx, infoplists):
  """Registers the root Info.plist generation action.

  Args:
    ctx: The target's rule context.
    infoplists: List of plists that should be merged into the root Info.plist.

  Returns:
    A list of tuples as described in processor.bzl with the Info.plist file
    reference and the PkgInfo file if required.
  """
  out_infoplist = intermediates.file(ctx.actions, ctx.label.name, "Info.plist")
  files = [out_infoplist]

  out_pkginfo = None
  if ctx.attr._needs_pkginfo:
    out_pkginfo = ctx.actions.declare_file("PkgInfo", sibling=out_infoplist)
    files.append(out_pkginfo)

  resource_actions.merge_root_infoplists(
      ctx, infoplists, out_infoplist, out_pkginfo, bundle_id=ctx.attr.bundle_id,
  )

  return [(processor.location.content, None, depset(files))]

def _resources_partial_impl(
    ctx, plist_attrs=[], targets_to_avoid=[], top_level_attrs=[]):
  """Implementation for the resource processing partial."""
  # TODO(kaipi): Implement resource deduplication.
  _ = targets_to_avoid
  providers = [
      x[NewAppleResourceInfo]
      for x in ctx.attr.deps
      if NewAppleResourceInfo in x
  ]

  # TODO(kaipi): Bucket top_level_attrs directly instead of collecting and
  # splitting.
  files = resources.collect(ctx.attr, res_attrs=top_level_attrs)
  if files:
    providers.append(resources.bucketize(files))

  if plist_attrs:
    plist_provider = resources.bucketize_typed(
        ctx.attr, bucket_type="plists", res_attrs=plist_attrs
    )
    providers.append(plist_provider)

  final_provider = resources.merge_providers(providers)

  # Map of resource provider fields to a tuple that contains the method to use
  # to process those resources and a boolean indicating whether the Swift
  # module is required for that processing.
  provider_field_to_action = {
      "datamodels": (_datamodels, True),
      "plists": (_plists, False),
      "pngs": (_pngs, False),
      "storyboards": (_storyboards, True),
      "strings": (_strings, False),
      "xcassets": (_xcassets, False),
  }

  # List containing all the files that the processor will bundle in their
  # configured location.
  processor_files = []

  fields = [f for f in dir(final_provider) if f not in ["to_json", "to_proto"]]

  infoplists = []
  for field in fields:
    processing_func, requires_swift_module = (
        # If the field type doesn't have a corresponding method, by default the
        # files will be copied as is with no processing.
        provider_field_to_action.get(field, (_noop, False))
    )
    for parent, swift_module, files in getattr(final_provider, field):
      extra_args = {}
      # Only pass the Swift module name if the type of resource to process
      # requires it.
      if requires_swift_module:
        extra_args["swift_module"] = swift_module
      result = processing_func(ctx, parent, files, **extra_args)
      processor_files.extend(result.files)
      if hasattr(result, "infoplists"):
        infoplists.extend(result.infoplists)

  processor_files.extend(_merge_root_infoplists(ctx, infoplists))

  return struct(
      files=processor_files,
      providers=[final_provider],
  )

def resources_partial(plist_attrs=[], targets_to_avoid=[], top_level_attrs=[]):
  """Constructor for the resources processing partial.

  This partial collects and propagates all resources that should be bundled in
  the target being processed.

  Args:
    plist_attrs: List of attributes that should be processed as Info plists
      that should be merged and processed.
    targets_to_avoid: List of targets containing resources that should be
      deduplicated from the target being processed.
    top_level_attrs: List of attributes containing resources that need to
      be processed from the target being processed.

  Returns:
    A partial that returns the bundle location of the resources and the
      resources provider.
  """
  return partial.make(
      _resources_partial_impl,
      plist_attrs=plist_attrs,
      targets_to_avoid=targets_to_avoid,
      top_level_attrs=top_level_attrs,
  )
