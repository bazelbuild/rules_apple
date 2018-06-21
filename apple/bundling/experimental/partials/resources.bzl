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

"""Partial implementations for resource processing."""

load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
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

def _plists(ctx, parent_dir, files):
  """Processes the grouped resource plists by merging them into one."""
  if parent_dir:
    out_plist = intermediates.file(
        ctx.actions, ctx.label.name, paths.join(parent_dir, "Info.plist"),
    )
    resource_actions.merge_resource_infoplists(
        ctx, paths.basename(parent_dir), files.to_list(), out_plist,
    )
    return [(processor.location.resource, parent_dir, depset([out_plist]))]
  else:
    # TODO(kaipi): Process root Info.plist differently, as it needs to be
    # merged with other plists (e.g. actool plist).
    return []

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
    An array of tuples as described in processor.bzl.
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

  return [(processor.location.resource, parent_dir, depset(png_files))]

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
  return [(
      processor.location.resource, parent_dir, depset([linked_storyboard_dir])
  )]

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
    An array of tuples as described in processor.bzl.
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

  return [(processor.location.resource, parent_dir, depset(string_files))]

def _xcassets(ctx, parent_dir, files):
  """Processes xcasset files."""
  # Only merge the resulting plist for the top level bundle. For resource
  # bundles, skip generating the plist.
  assets_plist = None
  if not parent_dir:
    # TODO(kaipi): Merge this into the top level Info.plist.
    assets_plist_path = paths.join(parent_dir or "", "xcassets-info.plist")
    assets_plist = intermediates.file(
        ctx.actions, ctx.label.name, assets_plist_path,
    )

  assets_dir = intermediates.directory(
      ctx.actions, ctx.label.name, paths.join(parent_dir or "", "xcassets"),
  )

  resource_actions.compile_asset_catalog(
      ctx, files.to_list(), assets_dir, assets_plist,
  )

  return [(processor.location.resource, parent_dir, depset([assets_dir]))]

def _noop(ctx, parent_dir, files):
  """Registers files to be bundled as is."""
  _ignore = [ctx]
  return [(processor.location.resource, parent_dir, files)]

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
      processor_files.extend(
          processing_func(ctx, parent, files, **extra_args)
      )

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
