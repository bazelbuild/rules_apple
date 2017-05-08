# Copyright 2017 The Bazel Authors. All rights reserved.
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

"""Actions used to process resources in Apple bundles."""

load("@build_bazel_rules_apple//apple/bundling:bundling_support.bzl",
     "bundling_support")
load("@build_bazel_rules_apple//apple/bundling:file_support.bzl", "file_support")
load("@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
     "platform_support")
load("@build_bazel_rules_apple//apple/bundling:product_support.bzl",
     "apple_product_type",
     "product_support")
load("@build_bazel_rules_apple//apple/bundling:resource_support.bzl",
     "resource_support")
load("@build_bazel_rules_apple//apple:utils.bzl",
     "basename",
     "bash_array_string",
     "group_files_by_directory",
     "intersperse",
     "optionally_prefixed_path",
     "remove_extension",
     "replace_extension",
     "split_extension")
load("@build_bazel_rules_apple//apple:utils.bzl", "xcrun_action")


# Sentinel value used as the key in the dictionary returned by
# `group_resources` whose value is the set of files that didn't satisfy any of
# the groupings.
_UNGROUPED = ""


def _group_resources(files, groupings):
  """Groups files based on their directory or file extension.

  This function does not directly use the `group_files_by_directory` helper
  function; it is implemented in such a way that it only requires one pass
  through the `files` set, since walking Skylark sets can be slow.

  Args:
    files: The set of `File` objects representing resources that should be
        grouped.
    groupings: A list of strings denoting file or directory extensions by which
        groups should be created. The extensions do not contain the leading
        dot. If a string ends with a slash (such as "xcassets/"), then a
        grouping is created that contains all files under directories with
        that extension, regardless of the individual files' extensions. If a
        string does not end with a slash (such as "xib"), then a grouping is
        created that contains all files with that extension. If a file would
        satisfy two different groupings (for example, a file in an "xcassets/"
        directory that has an extension in the list), then the directory
        grouping takes precedence.
  Returns:
    A dictionary whose keys are the groupings from `groupings` and the values
    are sets of `File` objects that are in that grouping. An additional key,
    `_UNGROUPED`, contains files that did not satisfy any of the groupings. In
    other words, the union of all the sets in the returned dictionary is equal
    to `resources` and the intersection of any two sets is empty.
  """
  grouped_files = {g: depset() for g in groupings}
  grouped_files[_UNGROUPED] = depset()

  # Pull out the directory groupings because we need to actually iterate over
  # these to find matches.
  dir_groupings = [g for g in groupings if g.endswith("/")]

  for f in files:
    path = f.path

    # Try to find a directory-based match first.
    matched_group = None
    for extension_candidate in dir_groupings:
      search_string = "." + extension_candidate
      if search_string in path:
        matched_group = extension_candidate
        break

    # If no directory match was found, use the file's extension to group it.
    if not matched_group:
      _, extension = split_extension(path)
      # Strip the leading dot.
      extension = extension[1:]
      matched_group = extension if extension in grouped_files else _UNGROUPED

    grouped_files[matched_group] = grouped_files[matched_group] | [f]

  return grouped_files


def _compile_plist(ctx, input_file, resource_info):
  """Creates an action that converts a plist file to binary format.

  Args:
    ctx: The Skylark context.
    input_file: The property list file that should be converted.
    resource_info: A struct returned by `resource_support.resource_info` that
        contains information needed by the resource processing functions.
  Returns:
    A struct as defined by `_process_resources` that will be merged with those
    from other processing functions.
  """
  bundle_dir = resource_info.bundle_dir

  path = resource_info.path_transform(input_file)
  out_file = file_support.intermediate(
      ctx, "%{name}.resources/%{path}", path=path, prefix=bundle_dir)

  input_path = input_file.path
  if input_path.endswith(".strings"):
    mnemonic = "CompileStrings"
  else:
    mnemonic = "CompilePlist"

  xcrun_action(
      ctx,
      inputs=[input_file],
      outputs=[out_file],
      arguments=[
          "/usr/bin/plutil",
          "-convert", "binary1",
          "-o", out_file.path,
          "--", input_file.path,
      ],
      mnemonic=mnemonic,
  )

  full_bundle_path = optionally_prefixed_path(path, bundle_dir)
  return struct(
      bundle_merge_files=depset([
          bundling_support.resource_file(ctx, out_file, full_bundle_path)
      ]),
  )


def _actool_args_for_special_file_types(ctx, asset_catalogs, resource_info):
  """Returns command line arguments needed to compile special assets.

  This function is called by `_actool` to scan for specially recognized asset
  types, such as app icons and launch images, and determine any extra command
  line arguments that need to be passed to `actool` to handle them. It also
  checks the validity of those assets, if any (for example, by permitting only
  one app icon set or launch image set to be present).

  Args:
    ctx: The Skylark context.
    asset_catalogs: The asset catalog files.
    resource_info: A struct returned by `resource_support.resource_info` that
        contains information needed by the resource processing functions.
  Returns:
    An array of extra arguments to pass to `actool`, which may be empty.
  """
  args = []

  product_type = product_support.product_type(ctx)
  if product_type in (apple_product_type.messages_extension,
                      apple_product_type.messages_sticker_pack_extension):
    appicon_extension = "stickersiconset"
    icon_files = [f for f in asset_catalogs if ".stickersiconset/" in f.path]

    args.extend([
        "--sticker-pack-identifier-prefix",
        resource_info.bundle_id + ".sticker-pack."
    ])

    # Fail if the user has included .appiconset folders in their asset catalog;
    # Message extensions must use .stickersiconset instead.
    appiconset_files = [f for f in asset_catalogs if ".appiconset/" in f.path]
    if appiconset_files:
      appiconset_dirs = group_files_by_directory(appiconset_files,
                                                 ["appiconset"],
                                                 attr="app_icons").keys()
      formatted_dirs = "[\n  %s\n]" % ",\n  ".join(appiconset_dirs)
      fail("Message extensions must use Messages Extensions Icon Sets " +
           "(named .stickersiconset), not traditional App Icon Sets " +
           "(.appiconset). Found the following: " +
           formatted_dirs, "app_icons")
  else:
    appicon_extension = "appiconset"
    icon_files = [f for f in asset_catalogs if ".appiconset/" in f.path]

  # Add arguments for app icons, if there are any.
  if icon_files:
    icon_dirs = group_files_by_directory(icon_files,
                                         [appicon_extension],
                                         attr="app_icons").keys()
    if len(icon_dirs) != 1:
      formatted_dirs = "[\n  %s\n]" % ",\n  ".join(icon_dirs)
      fail("The asset catalogs should contain exactly one directory named " +
           "*.%s among its asset catalogs, " % appicon_extension +
           "but found the following: " + formatted_dirs, "app_icons")

    app_icon_name = remove_extension(basename(icon_dirs[0]))
    args += ["--app-icon", app_icon_name]

  # Add arguments for launch images, if there are any.
  launch_image_files = [f for f in asset_catalogs if ".launchimage/" in f.path]
  if launch_image_files:
    launch_image_dirs = group_files_by_directory(launch_image_files,
                                                 ["launchimage"],
                                                 attr="launch_images").keys()
    if len(launch_image_dirs) != 1:
      formatted_dirs = "[\n  %s\n]" % ",\n  ".join(launch_image_dirs)
      fail("The asset catalogs should contain exactly one directory named " +
           "*.launchimage among its asset catalogs, but found the " +
           "following: " + formatted_dirs, "launch_images")

    launch_image_name = remove_extension(basename(launch_image_dirs[0]))
    args += ["--launch-image", launch_image_name]

  return args


def _actool(ctx, asset_catalogs, resource_info):
  """Creates an action that compiles asset catalogs.

  This action produces an .actool.zip file containing compiled assets that must
  be merged into the application/extension bundle. It also produces a partial
  Info.plist that must be merged info the application's main plist if an app
  icon or launch image are requested (if not, the actool plist is empty).

  Args:
    ctx: The Skylark context.
    asset_catalogs: An iterable of files in all asset catalogs that should be
        packaged as part of the application. This should include transitive
        dependencies (i.e., assets not just from the application target, but
        from any other library targets it depends on) as well as resources like
        app icons and launch images.
    resource_info: A struct returned by `resource_support.resource_info` that
        contains information needed by the resource processing functions.
  Returns:
    A struct as defined by `_process_resources` that will be merged with those
    from other processing functions.
  """
  bundle_dir = resource_info.bundle_dir

  out_zip = file_support.intermediate(
      ctx, "%{name}.resources/%{path}", path="actool-output.zip",
      prefix=bundle_dir)
  out_plist = file_support.intermediate(
      ctx, "%{name}.resources/%{path}", path="actool-PartialInfo.plist",
      prefix=bundle_dir)

  platform, _ = platform_support.platform_and_sdk_version(ctx)
  min_os = platform_support.minimum_os(ctx)
  actool_platform = platform.name_in_plist.lower()

  args = [
      out_zip.path,
      "--platform", actool_platform,
      "--output-partial-info-plist", out_plist.path,
      "--minimum-deployment-target", min_os,
      "--compress-pngs",
  ]

  product_type = product_support.product_type(ctx)
  if product_type:
    args.extend(["--product-type", product_type])
  args.extend(_actool_args_for_special_file_types(
      ctx, asset_catalogs, resource_info))
  args.extend(intersperse("--target-device", platform_support.families(ctx)))

  xcassets = group_files_by_directory(asset_catalogs,
                                      ["xcassets", "xcstickers"],
                                      attr="asset_catalogs").keys()
  args.extend(xcassets)

  platform_support.xcode_env_action(
      ctx,
      inputs=list(asset_catalogs),
      outputs=[out_zip, out_plist],
      executable=ctx.executable._actoolwrapper,
      arguments=args,
      mnemonic="AssetCatalogCompile",
      no_sandbox=True,
  )

  return struct(
      bundle_merge_zips=depset([
          bundling_support.resource_file(ctx, out_zip, bundle_dir)
      ]),
      partial_infoplists=depset([out_plist]),
  )


def _ibtool_arguments(ctx):
  """Returns common `ibtool` command line arguments.

  This function returns the common arguments used by both xib and storyboard
  compilation, as well as storyboard linking. Callers should add their own
  arguments to the returned array for their specific purposes.

  Args:
    ctx: The Skylark context.
  Returns:
    An array of command-line arguments to pass to ibtool.
  """
  min_os = platform_support.minimum_os(ctx)

  return [
      "--minimum-deployment-target", min_os,
  ] + intersperse("--target-device", platform_support.families(ctx))


def _ibtool_compile(ctx, input_file, resource_info):
  """Creates an action that compiles a storyboard or xib file.

  Args:
    ctx: The Skylark context.
    input_file: The storyboard or xib file to compile.
    resource_info: A struct returned by `resource_support.resource_info` that
        contains information needed by the resource processing functions.
  Returns:
    A struct as defined by `_process_resources` that will be merged with those
    from other processing functions.
  """
  bundle_dir = resource_info.bundle_dir
  swift_module = resource_info.swift_module

  path = resource_info.path_transform(input_file)

  if path.endswith(".storyboard"):
    is_storyboard = True
    mnemonic = "StoryboardCompile"
    out_name = replace_extension(path, ".storyboardc")
  else:
    is_storyboard = False
    mnemonic = "XibCompile"
    out_name = replace_extension(path, ".nib")

  out_file = file_support.intermediate(
      ctx, "%{name}.resources/%{path}", path=path + ".zip", prefix=bundle_dir)

  # The first two arguments are those required by ibtoolwrapper; the remaining
  # ones are passed to ibtool verbatim.
  args = [out_file.path, out_name] + _ibtool_arguments(ctx) + [
      "--module", swift_module or ctx.label.name,
      input_file.path
  ]

  platform_support.xcode_env_action(
      ctx,
      inputs=[input_file],
      outputs=[out_file],
      executable=ctx.executable._ibtoolwrapper,
      arguments=args,
      mnemonic=mnemonic,
      no_sandbox=True,
  )

  if is_storyboard:
    return struct(compiled_storyboards=depset([out_file]))
  else:
    return struct(bundle_merge_zips=depset([
        bundling_support.resource_file(ctx, out_file, bundle_dir)
    ]))


def _ibtool_link(ctx, storyboardc_zips):
  """Creates an action that links multiple compiled storyboards.

  Storyboards that reference each other must be linked, and this operation also
  copies them into a directory structure matching that which should appear in
  the final bundle.

  Args:
    ctx: The Skylark context.
    storyboardc_zips: A list of zipped, compiled storyboards (produced by
        `resource_actions.ibtool_compile`) that should be linked.
  Returns:
    The File object representing the ZIP file containing the linked
    storyboards.
  """
  out_zip = file_support.intermediate(
      ctx, "%{name}.resources/%{path}", path="linked-storyboards.zip")

  # The first two arguments are those required by ibtoolwrapper; the remaining
  # ones are passed to ibtool verbatim.
  args = ([out_zip.path, "", "--link"] + _ibtool_arguments(ctx) +
          [f.path for f in storyboardc_zips])

  platform_support.xcode_env_action(
      ctx,
      inputs=storyboardc_zips,
      outputs=[out_zip],
      executable=ctx.executable._ibtoolwrapper,
      arguments=args,
      mnemonic="StoryboardLink",
      no_sandbox=True,
  )

  return out_zip


def _mapc(ctx, input_files, resource_info):
  """Creates actions that compile a Core Data mapping model files.

  Each file should be contained inside a .xcmappingmodel directory.

  Args:
    ctx: The Skylark context.
    input_files: An iterable of files in all mapping models that should be
        compiled and packaged as part of the application.
    resource_info: A struct returned by `resource_support.resource_info` that
        contains information needed by the resource processing functions.
  Returns:
    A struct as defined by `_process_resources` that will be merged with those
    from other processing functions.
  """

  bundle_dir = resource_info.bundle_dir
  grouped_models = group_files_by_directory(input_files,
                                            ["xcmappingmodel"],
                                            attr="resources")

  out_files = []

  for model, children in grouped_models.items():
    compiled_model_name = replace_extension(basename(model), ".cdm")

    out_file = file_support.intermediate(
        ctx, "%%{name}.%s" % compiled_model_name, bundle_dir)
    out_files.append(out_file)

    args = [model, out_file.path]

    platform_support.xcode_env_action(
        ctx,
        inputs=list(children),
        outputs=[out_file],
        executable=ctx.executable._mapcwrapper,
        arguments=args,
        mnemonic="MappingModelCompile",
    )

  full_bundle_path = optionally_prefixed_path(compiled_model_name, bundle_dir)
  return struct(
      bundle_merge_files=depset([
          bundling_support.resource_file(ctx, f, full_bundle_path)
          for f in out_files
      ]),
  )


def _momc(ctx, input_files, resource_info):
  """Creates actions that compile a Core Data data model files.

  Each file should be contained inside a .xcdatamodel(d) directory.
  .xcdatamodel directories that are not contained inside a .xcdatamodeld (note
  the extra "d") directory are unversioned data models; those contained inside
  a .xcdatamodeld directory are versioned data models. One compilation action
  will be created for each .xcdatamodel directory except for those inside
  .xcdatamodeld directories; in that case, one action will be created for each
  of the .xcdatamodeld directories instead.

  Args:
    ctx: The Skylark context.
    input_files: An iterable of files in all data models that should be
        compiled and packaged as part of the application.
    resource_info: A struct returned by `resource_support.resource_info` that
        contains information needed by the resource processing functions.
  Returns:
    A struct as defined by `_process_resources` that will be merged with those
    from other processing functions.
  """

  # Before grouping the files by .xcdatamodel, we need to filter out any
  # .xccurrentversion files that might be present in versioned data models. We
  # add them back when the individual actions are registered.
  bundle_dir = resource_info.bundle_dir
  swift_module = resource_info.swift_module

  xccurrentversions = {f.dirname:f for f in input_files
                       if f.basename == ".xccurrentversion"}
  inputs_without_versions = [f for f in input_files
                             if f.dirname not in xccurrentversions]

  models_to_compile = {}
  grouped_models = group_files_by_directory(inputs_without_versions,
                                            ["xcdatamodel"],
                                            attr="datamodels")

  # If there are any .xcdatamodel directories that are contained in an
  # .xcdatamodeld directory, fold them all into a single entry keyed by that
  # containing directory.
  for model, children in grouped_models.items():
    if ".xcdatamodeld/" in model:
      name, extension, _ = model.rpartition(".xcdatamodeld/")
      xcdatamodeld = name + extension[:-1]
      if xcdatamodeld not in models_to_compile:
        models_to_compile[xcdatamodeld] = depset()

      models_to_compile[xcdatamodeld] += children
    else:
      models_to_compile[model] = children

  out_files = []

  platform, _ = platform_support.platform_and_sdk_version(ctx)
  platform_name = platform.name_in_plist.lower()
  deployment_target_option = "--%s-deployment-target" % platform_name
  min_os = platform_support.minimum_os(ctx)

  for model, children in models_to_compile.items():
    # Add the .xccurrentversion file back if this was a versioned model so that
    # it gets included as an input to the action.
    if model in xccurrentversions:
      children += depset([xccurrentversions[model]])

    model_name = remove_extension(basename(model))
    extension = ".momd" if model.endswith(".xcdatamodeld") else ".mom"
    archive_root_dir = model_name + extension

    out_file = file_support.intermediate(
        ctx, "%{name}.resources/%{path}",
        path="%s%s.zip" % (model_name, extension), prefix=bundle_dir)
    out_files.append(out_file)

    args = [
        out_file.path,
        archive_root_dir,
        deployment_target_option, min_os,
        "--module", swift_module or ctx.label.name,
        model,
    ]

    platform_support.xcode_env_action(
        ctx,
        inputs=list(children),
        outputs=[out_file],
        executable=ctx.executable._momcwrapper,
        arguments=args,
        mnemonic="MomCompile",
    )

  return struct(
      bundle_merge_zips=depset([
          bundling_support.resource_file(ctx, f, bundle_dir) for f in out_files
      ]),
  )


# The arity of a resource processing function, which denotes whether the
# matching files should be processed individually (`each`) or by a single
# action (`all`).
_arity = struct(
    all="all",
    each="each",
)


# A list of tuples describing resource types and how they should be processed.
# Each tuple must contain exactly three elements:
#
# 1. The file or directory extension corresponding to a type of resource.
#    Directory extensions should be indicated with a trailing slash. Extensions
#    should not have a leading dot.
# 2. The "arity" of the function that processes this type of resource. Legal
#    values are `_arity.each`, which means that the function will be called
#    separately for each file in the set; and `_arity.all`, which calls the
#    function only once and passes it the entire set of files.
# 3. The function that should be called for resources of this type.
#
# The function described above takes three arguments:
#
# 1. The Skylark context (`ctx`).
# 2. A `File` object (if arity was `_arity.each`) or a set of `File` objects
#    (if arity was `_arity.all`).
# 3. The resource info struct (as returned by `resource_support.resource_info`)
#    containing additional information about the resources being processed.
#
# It should return the same `struct` described in the return type of the
# `_process_resources` function; the results across all invocations are merged.
#
# NOTE: The order of these entries matters for directory groupings, which
# is why this is expressed as a list instead of a dictionary. This is necessary
# to handle potentially tricky containment relationships properly. For example,
# Core Data models can be versioned (an .xcdatamodeld/ directory containing
# multiple .xcdatamodel/ directories) or unversioned (a standalone
# .xcdatamodel/ directory). In order to make sure that unversioned ones aren't
# processed independently of their parent, the "xcdatamodeld/" entry must
# appear first. The order of file-based groupings is unimportant, because those
# files are always looked up simply by their extension.
#
# Because this is being evaluated at global scope, it must remain *below* any
# of the functions to which it refers, but *above* _process_resources which
# refers to it.
_PROCESSABLE_RESOURCES = [
    # Asset catalogs.
    (["xcassets/", "xcstickers/"], _arity.all,   _actool),
    # Core Data data models (versioned and unversioned).
    (["xcdatamodeld/"],            _arity.all,   _momc),
    (["xcdatamodel/"],             _arity.all,   _momc),
    # Core Data mapping models.
    (["xcmappingmodel/"],          _arity.all,   _mapc),
    # Interface Builder files.
    (["storyboard"],               _arity.each,  _ibtool_compile),
    (["xib"],                      _arity.each,  _ibtool_compile),
    # Property lists and localizable strings.
    (["plist", "strings"],         _arity.each,  _compile_plist),
]


def _process_resources(ctx, files, resource_info):
  """Creates actions that process resources based on their extensions.

  Args:
    ctx: The Skylark context.
    files: The set of `File` objects representing resources that should be
        processed.
    resource_info: A struct returned by `resource_support.resource_info` that
        contains information needed by the resource processing functions.
  Returns:
    A struct containing information that needs to be propagated back from
    individual actions to the main bundler. It contains the following fields:
    `bundle_merge_files`, a set of bundlable files that should be merged into
    the bundle at specific locations; `bundle_merge_zips`, a set of bundlable
    files that should be unzipped at specific locations in the bundle;
    `compiled_storyboards`, a set of `File` objects representing compiled
    storyboards that should be linked in the bundle; and `partial_infoplists`,
    a set of `File` objects representing plists generated by resource
    processing actions that should be merged into the bundle's final
    Info.plist.
  """
  # Get the flattened list of extensions across all processable resources types
  # to pass to _group_resources.
  extensions = [g[0] for g in _PROCESSABLE_RESOURCES]
  extensions = [e for sublist in extensions for e in sublist]
  grouped_files = _group_resources(files, extensions)
  action_results = []

  for (extensions, arity, function) in _PROCESSABLE_RESOURCES:
    curr_files = depset()
    for extension in extensions:
      curr_files = curr_files + grouped_files[extension]

    if not curr_files:
      continue

    if arity == _arity.all:
      action_results.append(function(ctx, curr_files, resource_info))
    elif arity == _arity.each:
      action_results.extend([function(ctx, f, resource_info)
                             for f in curr_files])
    else:
      fail(("_process_resources is broken. Expected arity 'all' or 'each' " +
            "but got '%s'") % arity)

  # Collect the results from the individual actions.
  bundle_merge_files = depset()
  bundle_merge_zips = depset()
  compiled_storyboards = depset()
  partial_infoplists = depset()

  for result in action_results:
    bundle_merge_files = (
        bundle_merge_files | getattr(result, "bundle_merge_files", []))
    bundle_merge_zips = (
        bundle_merge_zips | getattr(result, "bundle_merge_zips", []))
    compiled_storyboards = (
        compiled_storyboards | getattr(result, "compiled_storyboards", []))
    partial_infoplists = (
        partial_infoplists | getattr(result, "partial_infoplists", []))

  # Add any unprocessed resources to the list of files that will just be copied
  # into the bundle.
  unprocessed_resources = grouped_files[_UNGROUPED]
  bundle_merge_files = bundle_merge_files | depset([
      bundling_support.resource_file(ctx, f, optionally_prefixed_path(
          resource_info.path_transform(f), resource_info.bundle_dir))
      for f in unprocessed_resources
  ])

  return struct(
      bundle_merge_files=bundle_merge_files,
      bundle_merge_zips=bundle_merge_zips,
      compiled_storyboards=compiled_storyboards,
      partial_infoplists=partial_infoplists,
  )


# Define the loadable module that lists the exported symbols in this file.
resource_actions = struct(
    ibtool_link=_ibtool_link,
    process_resources=_process_resources,
)
