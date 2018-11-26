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

load(
    "@build_bazel_rules_apple//apple/bundling:bundling_support.bzl",
    "bundling_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:file_support.bzl",
    "file_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:product_support.bzl",
    "apple_product_type",
    "product_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:xcode_support.bzl",
    "xcode_support",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "apple_action",
    "group_files_by_directory",
    "optionally_prefixed_path",
    "xcrun_action",
)
load(
    "@build_bazel_rules_apple//common:path_utils.bzl",
    "path_utils",
)
load(
    "@bazel_skylib//lib:collections.bzl",
    "collections",
)
load(
    "@bazel_skylib//lib:new_sets.bzl",
    "sets",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

# Sentinel value used as the key in the dictionary returned by
# `group_resources` whose value is the set of files that didn't satisfy any of
# the groupings.
_UNGROUPED = ""

def _lproj_rooted_path_or_basename(f):
    """Returns an `.lproj`-rooted path for the given file if possible.

    If the file is nested in a `*.lproj` directory, then the `.lproj`-rooted path
    to the file will be returned; for example, "fr.lproj/foo.strings". If the
    file is not in a `*.lproj` directory, only the basename of the file is
    returned.

    Args:
      f: The `File` whose `.lproj`-rooted name or basename should be returned.
    Returns:
      The `.lproj`-rooted name or basename.
    """
    if f.dirname.endswith(".lproj"):
        filename = f.basename
        dirname = paths.basename(f.dirname)
        return dirname + "/" + filename

    return f.basename

def _resource_info(
        bundle_id,
        bundle_dir,
        path_transform = _lproj_rooted_path_or_basename,
        swift_module = None):
    """Returns a struct to be passed to `_process_single_resource_grouping`.

    Args:
      bundle_id: The id of the bundle to which the resources belong. Required.
      bundle_dir: The bundle directory that should be prefixed to any bundlable
          files returned by the resource processing action.
      path_transform: If provided, a function that will be called on each input
          file to obtain its relative output path in the bundle. The default
          behavior is to only preserve .lproj folders but otherwise flatten the
          directory structure and retain only the basename.
      swift_module: The name of the Swift module to which the resources belong,
          if any.
    Returns:
      A struct that should be passed to `_process_single_resource_grouping` and
      its callees.
    """
    return struct(
        bundle_dir = bundle_dir,
        bundle_id = bundle_id,
        path_transform = path_transform,
        swift_module = swift_module,
    )

def _group_files(files, groupings):
    """Groups files based on their directory or file extension.

    This function does not directly use the `group_files_by_directory` helper
    function; it is implemented in such a way that it only requires one pass
    through the `files` set, since walking Skylark sets can be slow.

    Args:
      files: The set of `File` objects representing resources that should be
          grouped.
      groupings: A list of tuples of strings denoting file or directory extensions
          by which groups should be created. The extensions do not contain the
          leading dot. If a string ends with a slash (such as "xcassets/"), then a
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

    flattened_extensions = [ext for extensions in groupings for ext in extensions]

    # Pull out the directory groupings because we need to actually iterate over
    # these to find matches.
    dir_groupings = [g for g in flattened_extensions if g.endswith("/")]

    for f in files:
        path = f.path

        # Try to find a directory-based match first.
        matched_extension = None
        for extension_candidate in dir_groupings:
            search_string = "." + extension_candidate
            if search_string in path:
                matched_extension = extension_candidate
                break

        # If no directory match was found, use the file's extension to group it.
        if not matched_extension:
            _, extension = paths.split_extension(path)

            # Strip the leading dot.
            extension = extension[1:]
            matched_extension = (
                extension if extension in flattened_extensions else None
            )

        if not matched_extension:
            matched_group = _UNGROUPED
        else:
            matched_group = [g for g in groupings if matched_extension in g][0]
        grouped_files[matched_group] = grouped_files[matched_group] | [f]

    return grouped_files

def _compile_plist(ctx, input_file, resource_info):
    """Creates an action that compiles plist and strings files.

    When compilation mode is "opt" the compiler will convert plist and strings
    files into binary format.

    Args:
      ctx: The Skylark context.
      input_file: The property list file that should be converted.
      resource_info: A struct returned by `_resource_info` that contains
          information needed by the resource processing functions.
    Returns:
      A struct as defined by `_process_resources` that will be merged with those
      from other processing functions.
    """
    bundle_dir = resource_info.bundle_dir

    path = resource_info.path_transform(input_file)
    if ctx.var["COMPILATION_MODE"] == "opt":
        out_file = file_support.intermediate(
            ctx,
            "%{name}.resources/%{path}",
            path = path,
            prefix = bundle_dir,
        )

        input_path = input_file.path
        if input_path.endswith(".strings"):
            mnemonic = "CompileStrings"
        else:
            mnemonic = "CompilePlist"

        # This command will check whether the input file is non-empty, and then
        # execute the version of plutil that takes the file directly. If the file is
        # empty, it will echo an new line and then pipe it into plutil. We do this
        # to handle empty files as plutil doesn't handle them very well.
        plutil_command = "plutil -convert binary1 -o %s --" % out_file.path
        complete_command = ("([[ -s {in_file} ]] && {plutil_command} {in_file} ) " +
                            "|| ( echo | {plutil_command} -)").format(
            in_file = input_file.path,
            plutil_command = plutil_command,
        )

        # Ideally we should be able to use command, which would set up the
        # /bin/sh -c prefix for us.
        # TODO(b/77637734): Change this to use command instead.
        apple_action(
            ctx,
            arguments = [
                "-c",
                complete_command,
            ],
            executable = "/bin/sh",
            inputs = [input_file],
            mnemonic = mnemonic,
            outputs = [out_file],
        )
    else:
        out_file = input_file

    full_bundle_path = optionally_prefixed_path(path, bundle_dir)
    return struct(
        bundle_merge_files = depset([
            bundling_support.resource_file(ctx, out_file, full_bundle_path),
        ]),
    )

def _png_copy(ctx, input_file, resource_info):
    """Creates an action that copies and compresses a png using copypng.

    Args:
      ctx: The Skylark context.
      input_file: The png file to be copied.
      resource_info: A struct returned by `_resource_info` that contains
          information needed by the resource processing functions.
    Returns:
      A struct as defined by `_process_resources` that will be merged with those
      from other processing functions.
    """
    bundle_dir = resource_info.bundle_dir

    path = resource_info.path_transform(input_file)
    out_file = file_support.intermediate(
        ctx,
        "%{name}.resources/%{path}",
        path = path,
        prefix = bundle_dir,
    )

    xcrun_action(
        ctx,
        arguments = [
            "copypng",
            "-strip-PNG-text",
            "-compress",
            input_file.path,
            out_file.path,
        ],
        inputs = [input_file],
        mnemonic = "CopyPng",
        outputs = [out_file],
    )

    full_bundle_path = optionally_prefixed_path(path, bundle_dir)
    return struct(
        bundle_merge_files = depset([
            bundling_support.resource_file(ctx, out_file, full_bundle_path),
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
      resource_info: A struct returned by `_resource_info` that contains
          information needed by the resource processing functions.
    Returns:
      An array of extra arguments to pass to `actool`, which may be empty.
    """
    args = []

    product_type = product_support.product_type(ctx)
    if product_type in (
        apple_product_type.messages_extension,
        apple_product_type.messages_sticker_pack_extension,
    ):
        appicon_extension = "stickersiconset"
        icon_files = [f for f in asset_catalogs if ".stickersiconset/" in f.path]

        args.extend([
            "--sticker-pack-identifier-prefix",
            resource_info.bundle_id + ".sticker-pack.",
        ])

        # Fail if the user has included .appiconset folders in their asset catalog;
        # Message extensions must use .stickersiconset instead.
        #
        # NOTE: This is mostly caught via the validation in ios_extension of the
        # app_icons attribute; however, since different resource attributes from
        # *_library targets are merged into here, other resources could show up
        # so until the resource handing is revisited (b/77804841), things could
        # still show up that don't make sense.
        appiconset_files = [f for f in asset_catalogs if ".appiconset/" in f.path]
        if appiconset_files:
            appiconset_dirs = group_files_by_directory(
                appiconset_files,
                ["appiconset"],
                attr = "app_icons",
            ).keys()
            formatted_dirs = "[\n  %s\n]" % ",\n  ".join(appiconset_dirs)
            fail("Message extensions must use Messages Extensions Icon Sets " +
                 "(named .stickersiconset), not traditional App Icon Sets " +
                 "(.appiconset). Found the following: " +
                 formatted_dirs, "app_icons")
    else:
        platform_type = platform_support.platform_type(ctx)
        if platform_type == apple_common.platform_type.tvos:
            appicon_extension = "brandassets"
            icon_files = [f for f in asset_catalogs if ".brandassets/" in f.path]
        else:
            appicon_extension = "appiconset"
            icon_files = [f for f in asset_catalogs if ".appiconset/" in f.path]

    # Add arguments for app icons, if there are any.
    if icon_files:
        icon_dirs = group_files_by_directory(
            icon_files,
            [appicon_extension],
            attr = "app_icons",
        ).keys()
        if len(icon_dirs) != 1:
            formatted_dirs = "[\n  %s\n]" % ",\n  ".join(icon_dirs)
            fail("The asset catalogs should contain exactly one directory named " +
                 "*.%s among its asset catalogs, " % appicon_extension +
                 "but found the following: " + formatted_dirs, "app_icons")

        app_icon_name = paths.split_extension(paths.basename(icon_dirs[0]))[0]
        args += ["--app-icon", app_icon_name]

    # Add arguments for launch images, if there are any.
    launch_image_files = [f for f in asset_catalogs if ".launchimage/" in f.path]
    if launch_image_files:
        launch_image_dirs = group_files_by_directory(
            launch_image_files,
            ["launchimage"],
            attr = "launch_images",
        ).keys()
        if len(launch_image_dirs) != 1:
            formatted_dirs = "[\n  %s\n]" % ",\n  ".join(launch_image_dirs)
            fail("The asset catalogs should contain exactly one directory named " +
                 "*.launchimage among its asset catalogs, but found the " +
                 "following: " + formatted_dirs, "launch_images")

        launch_image_name = paths.split_extension(
            paths.basename(launch_image_dirs[0]),
        )[0]
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
      resource_info: A struct returned by `_resource_info` that contains
          information needed by the resource processing functions.
    Returns:
      A struct as defined by `_process_resources` that will be merged with those
      from other processing functions.
    """
    bundle_dir = resource_info.bundle_dir

    out_dir = file_support.intermediate_dir(
        ctx,
        "%{name}.resources/%{path}",
        path = "actool-output",
        prefix = bundle_dir,
    )
    out_plist = file_support.intermediate(
        ctx,
        "%{name}.resources/%{path}",
        path = "actool-PartialInfo.plist",
        prefix = bundle_dir,
    )

    platform = platform_support.platform(ctx)
    min_os = platform_support.minimum_os(ctx)
    actool_platform = platform.name_in_plist.lower()

    args = [
        "actool",
        "--compile",
        file_support.xctoolrunner_path(out_dir.path),
        "--platform",
        actool_platform,
        "--output-partial-info-plist",
        file_support.xctoolrunner_path(out_plist.path),
        "--minimum-deployment-target",
        min_os,
        "--compress-pngs",
    ]

    if xcode_support.is_xcode_at_least_version(
        ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
        "8",
    ):
        product_type = product_support.product_type(ctx)
        if product_type:
            args.extend(["--product-type", product_type])

    args.extend(_actool_args_for_special_file_types(
        ctx,
        asset_catalogs,
        resource_info,
    ))
    args.extend(collections.before_each(
        "--target-device",
        platform_support.families(ctx),
    ))

    xcassets = group_files_by_directory(
        asset_catalogs,
        ["xcassets", "xcstickers"],
        attr = "asset_catalogs",
    ).keys()
    args.extend([file_support.xctoolrunner_path(p) for p in xcassets])

    platform_support.xcode_env_action(
        ctx,
        inputs = list(asset_catalogs),
        outputs = [out_dir, out_plist],
        executable = ctx.executable._xctoolrunner,
        arguments = args,
        mnemonic = "AssetCatalogCompile",
        no_sandbox = True,
    )

    return struct(
        bundle_merge_files = depset([
            bundling_support.resource_file(
                ctx,
                out_dir,
                bundle_dir,
                contents_only = True,
            ),
        ]),
        partial_infoplists = depset([out_plist]),
    )

def _prefix_with_swift_module(path, resource_info):
    """Prepends a path with the resource info's Swift module, if set.

    Args:
      path: The path to prepend.
      resource_info: The resource info struct.
    Returns: The path with the Swift module name prepended if it was set, or just
      the path itself if there was no module name.
    """
    swift_module = resource_info.swift_module
    if swift_module:
        return swift_module + "-" + path
    return path

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
        "--minimum-deployment-target",
        min_os,
    ] + collections.before_each(
        "--target-device",
        platform_support.families(ctx),
    )

def _compile_xib(ctx, input_file, resource_info):
    """Creates an action that compiles a XIB file.

    Args:
      ctx: The Skylark context.
      input_file: The XIB file to compile.
      resource_info: A struct returned by `_resource_info` that contains
          information needed by the resource processing functions.
    Returns:
      A struct as defined by `_process_resources` that will be merged with those
      from other processing functions.
    """
    bundle_dir = resource_info.bundle_dir
    swift_module = resource_info.swift_module

    # Even the root outputs of ibtool are unpredictable for XIBs based on minimum
    # OS version; foo.xib could end up as foo~iphone.nib even if we pass foo.nib
    # to the --compile argument, for example. So we just create a directory to
    # hold the outputs and then bundle the _contents_ of that directory.
    bundle_relative_path = resource_info.path_transform(input_file)
    out_dir_path = paths.replace_extension(
        bundle_relative_path,
        ".ibtool-outputs",
    )
    nib_name = paths.replace_extension(
        paths.basename(bundle_relative_path),
        ".nib",
    )

    out_dir = file_support.intermediate_dir(
        ctx,
        _prefix_with_swift_module("%{name}.resources/%{path}", resource_info),
        path = out_dir_path,
        prefix = bundle_dir,
    )

    args = [
        "ibtool",
        "--compile",
        file_support.xctoolrunner_path(out_dir.path) + "/" + nib_name,
    ]
    args.extend(_ibtool_arguments(ctx))
    args.extend([
        "--module",
        swift_module or ctx.label.name,
        file_support.xctoolrunner_path(input_file.path),
    ])

    platform_support.xcode_env_action(
        ctx,
        inputs = [input_file],
        outputs = [out_dir],
        executable = ctx.executable._xctoolrunner,
        arguments = args,
        mnemonic = "XibCompile",
        no_sandbox = True,
    )

    full_bundle_path = optionally_prefixed_path(
        paths.dirname(bundle_relative_path),
        bundle_dir,
    )
    return struct(bundle_merge_files = depset([
        bundling_support.resource_file(
            ctx,
            out_dir,
            full_bundle_path,
            contents_only = True,
        ),
    ]))

def _compile_storyboard(ctx, input_file, resource_info):
    """Creates an action that compiles a storyboard.

    Args:
      ctx: The Skylark context.
      input_file: The storyboard to compile.
      resource_info: A struct returned by `_resource_info` that contains
          information needed by the resource processing functions.
    Returns:
      A struct as defined by `_process_resources` that will be merged with those
      from other processing functions.
    """
    bundle_dir = resource_info.bundle_dir
    swift_module = resource_info.swift_module

    path = resource_info.path_transform(input_file)
    path = paths.replace_extension(path, ".storyboardc")

    out_dir = file_support.intermediate_dir(
        ctx,
        _prefix_with_swift_module("%{name}.resources/%{path}", resource_info),
        path = path,
        prefix = bundle_dir,
    )

    args = [
        "ibtool",
        "--compilation-directory",
        file_support.xctoolrunner_path(out_dir.dirname),
    ]
    args.extend(_ibtool_arguments(ctx))
    args.extend([
        "--module",
        swift_module or ctx.label.name,
        file_support.xctoolrunner_path(input_file.path),
    ])

    platform_support.xcode_env_action(
        ctx,
        inputs = [input_file],
        outputs = [out_dir],
        executable = ctx.executable._xctoolrunner,
        arguments = args,
        mnemonic = "StoryboardCompile",
        no_sandbox = True,
    )

    return struct(compiled_storyboards = depset([out_dir]))

def _link_storyboards(ctx, storyboardc_dirs, resource_info):
    """Creates an action that links multiple compiled storyboards.

    Storyboards that reference each other must be linked, and this operation also
    copies them into a directory structure matching that which should appear in
    the final bundle.

    Args:
      ctx: The Skylark context.
      storyboardc_dirs: A list of zipped, compiled storyboards (produced by
          `_compile_storyboard`) that should be linked.
      resource_info: A struct returned by `_resource_info` that contains
          information needed by the resource processing functions.
    Returns:
      The `File` object representing the directory containing the linked
      storyboards.
    """
    bundle_dir = resource_info.bundle_dir
    out_dir_path = _prefix_with_swift_module(
        "linked-storyboards",
        resource_info,
    )
    out_dir = file_support.intermediate_dir(
        ctx,
        "%{name}.resources/%{path}",
        path = out_dir_path,
        prefix = bundle_dir,
    )

    args = ["ibtool", "--link", file_support.xctoolrunner_path(out_dir.path)]
    args.extend(_ibtool_arguments(ctx))
    args.extend([f.path for f in storyboardc_dirs])

    platform_support.xcode_env_action(
        ctx,
        inputs = storyboardc_dirs,
        outputs = [out_dir],
        executable = ctx.executable._xctoolrunner,
        arguments = args,
        mnemonic = "StoryboardLink",
        no_sandbox = True,
    )

    return out_dir

def _mapc(ctx, input_files, resource_info):
    """Creates actions that compile a Core Data mapping model files.

    Each file should be contained inside a .xcmappingmodel directory.

    Args:
      ctx: The Skylark context.
      input_files: An iterable of files in all mapping models that should be
          compiled and packaged as part of the application.
      resource_info: A struct returned by `_resource_info` that contains
          information needed by the resource processing functions.
    Returns:
      A struct as defined by `_process_resources` that will be merged with those
      from other processing functions.
    """

    bundle_dir = resource_info.bundle_dir
    grouped_models = group_files_by_directory(
        input_files,
        ["xcmappingmodel"],
        attr = "resources",
    )

    out_files = []

    for model, children in grouped_models.items():
        compiled_model_name = paths.replace_extension(
            paths.basename(model),
            ".cdm",
        )

        out_file = file_support.intermediate(
            ctx,
            "%%{name}.%s" % compiled_model_name,
            bundle_dir,
        )
        out_files.append(out_file)

        args = [
            "mapc",
            file_support.xctoolrunner_path(model),
            file_support.xctoolrunner_path(out_file.path),
        ]

        platform_support.xcode_env_action(
            ctx,
            inputs = list(children),
            outputs = [out_file],
            executable = ctx.executable._xctoolrunner,
            arguments = args,
            mnemonic = "MappingModelCompile",
        )

    full_bundle_path = optionally_prefixed_path(compiled_model_name, bundle_dir)
    return struct(
        bundle_merge_files = depset([
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
      resource_info: A struct returned by `_resource_info` that contains
          information needed by the resource processing functions.
    Returns:
      A struct as defined by `_process_resources` that will be merged with those
      from other processing functions.
    """

    # Before grouping the files by .xcdatamodel, we need to filter out any
    # .xccurrentversion files that might be present in versioned data models. We
    # add them back when the individual actions are registered.
    bundle_dir = resource_info.bundle_dir
    swift_module = resource_info.swift_module

    xccurrentversions = {
        f.dirname: f
        for f in input_files
        if f.basename == ".xccurrentversion"
    }
    inputs_without_versions = [
        f
        for f in input_files
        if f.dirname not in xccurrentversions
    ]

    models_to_compile = {}
    grouped_models = group_files_by_directory(
        inputs_without_versions,
        ["xcdatamodel"],
        attr = "datamodels",
    )

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

    bundle_merge_files = []

    platform = platform_support.platform(ctx)
    platform_name = platform.name_in_plist.lower()
    deployment_target_option = "--%s-deployment-target" % platform_name
    min_os = platform_support.minimum_os(ctx)

    for model, children in models_to_compile.items():
        # Add the .xccurrentversion file back if this was a versioned model so that
        # it gets included as an input to the action.
        if model in xccurrentversions:
            children = depset([xccurrentversions[model]], transitive = [children])

        model_name = paths.split_extension(paths.basename(model))[0]
        if model.endswith(".xcdatamodeld"):
            out_file_name = model_name + ".momd"
            out_file = file_support.intermediate_dir(
                ctx,
                "%{name}.resources/%{path}",
                path = out_file_name,
                prefix = bundle_dir,
            )
        else:
            out_file_name = model_name + ".mom"
            out_file = file_support.intermediate(
                ctx,
                "%{name}.resources/%{path}",
                path = out_file_name,
                prefix = bundle_dir,
            )

        bundle_merge_files.append(bundling_support.resource_file(
            ctx,
            out_file,
            optionally_prefixed_path(out_file_name, bundle_dir),
        ))

        args = [
            "momc",
            deployment_target_option,
            min_os,
            "--module",
            swift_module or ctx.label.name,
            file_support.xctoolrunner_path(model),
            file_support.xctoolrunner_path(out_file.path),
        ]

        platform_support.xcode_env_action(
            ctx,
            inputs = children.to_list(),
            outputs = [out_file],
            executable = ctx.executable._xctoolrunner,
            arguments = args,
            mnemonic = "MomCompile",
        )

    return struct(bundle_merge_files = depset(bundle_merge_files))

# The arity of a resource processing function, which denotes whether the
# matching files should be processed individually (`each`) or by a single
# action (`all`).
_arity = struct(
    all = "all",
    each = "each",
)

# The following constants are lists of tuples describing resource types and how
# they should be processed. Each tuple must contain exactly four elements:
#
# 1. The tuple of file or directory extensions corresponding to a type of
#    resource. Directory extensions should be indicated with a trailing slash.
#    Extensions should not have a leading dot.
# 2. The "arity" of the function that processes this type of resource. Legal
#    values are `_arity.each`, which means that the function will be called
#    separately for each file in the set; and `_arity.all`, which calls the
#    function only once and passes it the entire set of files.
# 3. A Boolean value indicating whether or not the Swift module is used as an
#    input argument when processing the resource.
# 4. The function that should be called for resources of this type.
#
# The function described above takes three arguments:
#
# 1. The Skylark context (`ctx`).
# 2. A `File` object (if arity was `_arity.each`) or a set of `File` objects
#    (if arity was `_arity.all`).
# 3. The resource info struct (as returned by `_resource_info`) containing
#    additional information about the resources being processed.
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
# Because these are being evaluated at global scope, they must remain *below*
# any of the functions to which they refer, but *above* the resource processing
# functions that refer to them.

_PLIST_AND_STRING_GROUPING_RULES = [
    # Property lists.
    (
        ("plist",),
        _arity.each,
        False,
        _compile_plist,
    ),
    # Localizable strings files.
    (
        ("strings",),
        _arity.each,
        False,
        _compile_plist,
    ),
]

_ALL_GROUPING_RULES = [
    # Asset catalogs.
    (
        ("xcassets/", "xcstickers/"),
        _arity.all,
        False,
        _actool,
    ),
    # Core Data data models (versioned and unversioned).
    (
        ("xcdatamodeld/",),
        _arity.all,
        True,
        _momc,
    ),
    (
        ("xcdatamodel/",),
        _arity.all,
        True,
        _momc,
    ),
    # Core Data mapping models.
    (
        ("xcmappingmodel/",),
        _arity.all,
        False,
        _mapc,
    ),
    # Interface Builder files.
    (
        ("storyboard",),
        _arity.each,
        True,
        _compile_storyboard,
    ),
    (
        ("xib",),
        _arity.each,
        True,
        _compile_xib,
    ),
    # Other files.
    (
        ("png",),
        _arity.each,
        True,
        _png_copy,
    ),
] + _PLIST_AND_STRING_GROUPING_RULES

def _process_single_resource_grouping(
        ctx,
        files,
        resource_info,
        group_extensions,
        grouping_rules,
        file_filter_partial):
    """Creates actions that processes files in a single resource group.

    The specified files are already assumed to have been grouped such that all of
    them correspond to the same resource type and belong to the same bundle and
    Swift module.

    Args:
      ctx: The Skylark context.
      files: The set of `File` objects representing resources that should be
          processed.
      resource_info: A struct returned by `_resource_info` that contains
          information needed by the resource processing functions.
      group_extensions: The tuple of file/directory extensions that was used to
          create the grouping represented by `files`.
      grouping_rules: A list of grouping rules (as defined in tuples above) that
          define the groupings that will be processed. Any files placed in the
          `_UNGROUPED` grouping will be copied verbatim. This allows a subset of
          the rules to be applied; for example, the strings and plists in an
          `objc_bundle` can be processed while the other files can be copied
          without processing.
      file_filter_partial: A partial that can be used to filter files out of
          `files` before they are processed. If it is None, then `files `is passed
          through unfiltered.
    Returns:
      A struct containing information that needs to be propagated back from
      individual actions to the main bundler. It contains the following fields:
      `bundle_merge_files`, a set of bundlable files that should be merged into
      the bundle at specific locations; `compiled_storyboards`, a set of `File`
      objects representing compiled storyboards that should be linked in the
      bundle; and `partial_infoplists`, a set of `File` objects representing
      plists generated by resource processing actions that should be merged into
      the bundle's final Info.plist.
    """
    bundle_merge_files = depset()
    compiled_storyboards = depset()
    partial_infoplists = depset()

    if file_filter_partial:
        filtered_files = [f for f in files if partial.call(file_filter_partial, f)]
    else:
        filtered_files = files

    if filtered_files:
        if group_extensions != _UNGROUPED:
            # Find the grouping rule that was used to create this group.
            for grouping_rule in grouping_rules:
                if group_extensions == grouping_rule[0]:
                    _, arity, uses_module, function = grouping_rule

            if arity == _arity.all:
                action_results = [function(ctx, filtered_files, resource_info)]
            elif arity == _arity.each:
                action_results = [
                    function(ctx, f, resource_info)
                    for f in filtered_files
                ]
            else:
                fail(("_process_resources is broken. Expected arity 'all' or 'each' " +
                      "but got '%s'") % arity)

            # Collect the results from the individual actions.
            for result in action_results:
                new_items = getattr(result, "bundle_merge_files", None)
                if new_items:
                    bundle_merge_files = depset(
                        transitive = [new_items, bundle_merge_files],
                    )
                new_items = getattr(result, "compiled_storyboards", None)
                if new_items:
                    compiled_storyboards = depset(
                        transitive = [new_items, compiled_storyboards],
                    )
                new_items = getattr(result, "partial_infoplists", None)
                if new_items:
                    partial_infoplists = depset(
                        transitive = [new_items, partial_infoplists],
                    )
        else:
            # Add any unprocessed resources to the list of files that will just be
            # copied into the bundle.
            bundle_merge_files = depset(
                [
                    bundling_support.resource_file(ctx, f, optionally_prefixed_path(
                        resource_info.path_transform(f),
                        resource_info.bundle_dir,
                    ))
                    for f in filtered_files
                ],
                transitive = [bundle_merge_files],
            )

    return struct(
        bundle_merge_files = bundle_merge_files,
        compiled_storyboards = compiled_storyboards,
        partial_infoplists = partial_infoplists,
    )

def _create_resource_groupings(resource_sets, resource_set_key, grouping_rules):
    """Groups resources by their bundle directory, extension, and Swift module.

    This function takes into consideration whether or not the resources *use* the
    Swift module and groups them accordingly. For example, asset catalogs do not
    take the module name as an input so all asset catalogs are placed into a
    single group regardless of which Swift module actually propagated them. XIB
    files, on the other hand, use the Swift module name as an input so their
    groupings are kept separate.

    The grouping returned by this function is a complex nested structure that
    looks like the following example:

        {
            "foo.bundle": {
                ("xcassets/", "xcstickers/"): [
                    struct(swift_module=None, files=[Files...]),
                ],
                ("xib",): [
                    struct(swift_module="Module1", files=[Files...]),
                    struct(swift_module="Module2", files=[Files...]),
                ],
                ...,
                _UNGROUPED: [...],
            },
        }

    Args:
      resource_sets: A list of resource sets that should be grouped.
      resource_set_key: The name of the field in the resource set representing the
          files that should be grouped; for example, "resources",
          "structured_resources", or "objc_bundle_imports".
      grouping_rules: A list of grouping rules (as defined in tuples above) that
          define the groupings that will be returned. Any files not covered by
          these rules will be placed in the `_UNGROUPED` group.
    Returns:
      A dictionary of the form above, where the keys are bundle directories and
      the values are dictionaries that break down the resources into files that
      are themselves grouped based on their Swift module.
    """
    resource_groupings = {}

    # Get the flattened list of extensions across all processable resources
    # types to pass to _group_files.
    all_extensions = [g[0] for g in grouping_rules]

    for r in resource_sets:
        grouped_files = _group_files(getattr(r, resource_set_key), all_extensions)
        resource_map = resource_groupings.get(r.bundle_dir, {})

        for (extensions, _, uses_module, _) in grouping_rules:
            files_in_group = grouped_files[extensions]
            if not files_in_group:
                continue

            current_list = resource_map.get(extensions, [])

            if uses_module:
                # If the resource processing depends on the module, build a list of
                # structs that separate the resources based on their module name.
                current_list.append(struct(
                    files = files_in_group,
                    swift_module = r.swift_module,
                ))
            else:
                # If the resource processing doesn't depend on the module, we can just
                # group them into a single list with swift_module=None in the struct.
                current_list = [struct(
                    files = (
                        (current_list[0].files if current_list else []) +
                        files_in_group.to_list()
                    ),
                    swift_module = None,
                )]

            resource_map[extensions] = current_list

        if grouped_files[_UNGROUPED]:
            current_list = resource_map.get(_UNGROUPED, []) + [struct(
                files = grouped_files[_UNGROUPED].to_list(),
                swift_module = None,
            )]
            resource_map[_UNGROUPED] = current_list

        resource_groupings[r.bundle_dir] = resource_map

    return resource_groupings

def _process_plists_and_strings(
        ctx,
        bundle_id,
        resource_sets,
        resource_set_key,
        path_transform,
        file_filter_partial):
    """Processes plists and strings but ignores other resource types.

    This function is used to handle legacy objc_bundles and structured_resources,
    where we still want to convert the files to binary format (because there is no
    reason to leave them in the larger text format) but copy every other kind of
    file without any processing.

    Args:
      ctx: The rule context.
      bundle_id: The identifier of the top-level bundle.
      resource_sets: A list of `AppleResourceSet` objects that represent the
          resource sets to be processed.
      resource_set_key: The name of the field in the resource set representing the
          files that should be grouped; for example, "resources",
          "structured_resources", or "objc_bundle_imports".
      path_transform: A function that will be called on each input file to obtain
          its relative output path in the bundle.
      file_filter_partial: A partial that can be used to filter files out of
          `files` before they are processed. If it is None, then `files `is passed
          through unfiltered.
    Returns:
      A list of bundlable files that should be included among the
      `bundle_merge_files` of the bundle being processed.
    """
    bundle_merge_files = []
    resource_groupings = _create_resource_groupings(
        resource_sets,
        resource_set_key,
        _PLIST_AND_STRING_GROUPING_RULES,
    )

    for bundle_dir, resource_map in resource_groupings.items():
        for group_extensions, resource_groups in resource_map.items():
            for resource_group in resource_groups:
                files = resource_group.files
                resource_info = _resource_info(
                    bundle_id,
                    bundle_dir,
                    path_transform = path_transform,
                )
                result = _process_single_resource_grouping(
                    ctx,
                    files,
                    resource_info,
                    group_extensions,
                    _PLIST_AND_STRING_GROUPING_RULES,
                    file_filter_partial,
                )
                bundle_merge_files.extend(list(result.bundle_merge_files))

    return bundle_merge_files

def _locales_to_include(ctx):
    """
    Determines which locales to include in resource actions.

    If the user has specified "apple.locales_to_include" we use those.
    Otherwise we don't filter.
    'Base' is always included.

    Args:
      ctx: The rule context.
    Returns:
      A set of locales to include or None if all should be included.
    """
    user_locales = ctx.var.get("apple.locales_to_include")
    if user_locales != None:
        return sets.make(["Base"] + [l.strip() for l in user_locales.split(",")])
    else:
        return None

def _locale_filter(locales_to_include, locales_included, locales_dropped, f):
    """Filters out any *.lproj folders that are not in `locales_to_include`.

    Args:
      locales_to_include: set of locales to not filter out.
      locales_included: set of locales that have been included.
      locales_dropped: set of locales that have been dropped.
      f: The file to potentially filter.
    Returns:
      True if the file should be used.
    """
    dirname = f.dirname
    loc = dirname.find(".lproj")
    if loc == -1:
        return True

    # If there was more after '.lproj', then it has to be a directory, otherwise
    # it was part of some other extension.
    if (loc + 6) > len(dirname) and dirname[loc + 6] != "/":
        return True

    # Extract the locale directory.
    dirlocale_start = dirname.rfind("/", end = loc)
    if dirlocale_start < 0:
        dirlocale = dirname[0:loc]
    else:
        dirlocale = dirname[dirlocale_start + 1:loc]

    if sets.contains(locales_to_include, dirlocale):
        sets.insert(locales_included, dirlocale)
        return True

    sets.insert(locales_dropped, dirlocale)
    return False

def _process_resource_sets(ctx, bundle_id, resource_sets):
    """Processes all of the resource sets for a bundle (and its nested bundles).

    Args:
      ctx: The rule context.
      bundle_id: The identifier of the top-level bundle.
      resource_sets: A list of `AppleResourceSet` objects that represent the
          resource sets to be processed.
    Returns:
      A struct containing three fields:
      1. `bundle_infoplists`, a dictionary from bundle directories to lists of
         partial Info.plist files that should be merged in that bundle
      2. `bundle_merge_files`, a list of bundlable files that should be included
         in the bundle.
      3. `bundle_merge_zips`, a list of ZIP files whose contents should be
         included in the bundle.
      4. `bundle_dir_to_resource_bundle_target_datas`, a dictionary from bundle
         directories to the AppleResourceBundleTargetData of the target if the
         target was a resource bundle.
    """
    bundle_merge_files = []
    bundle_merge_zips = []
    bundle_infoplists = {}
    bundle_to_tgt_datas = {}
    locales_included = sets.make(["Base"])
    locales_dropped = sets.make()

    locales_to_include = _locales_to_include(ctx)
    if locales_to_include:
        file_filter_partial = partial.make(
            _locale_filter,
            locales_to_include,
            locales_included,
            locales_dropped,
        )
    else:
        file_filter_partial = None

    bundle_resources = _create_resource_groupings(
        resource_sets,
        "resources",
        _ALL_GROUPING_RULES,
    )
    for bundle_dir, resource_map in bundle_resources.items():
        for group_extensions, resource_groups in resource_map.items():
            for resource_group in resource_groups:
                files = resource_group.files
                resource_info = _resource_info(
                    bundle_id,
                    bundle_dir,
                    swift_module = resource_group.swift_module,
                )
                result = _process_single_resource_grouping(
                    ctx,
                    files,
                    resource_info,
                    group_extensions,
                    _ALL_GROUPING_RULES,
                    file_filter_partial,
                )
                bundle_merge_files.extend(list(result.bundle_merge_files))

                # Link the storyboards in the bundle, which not only resolves references
                # between different storyboards, but also copies the results to the
                # correct location in the bundle in a platform-agnostic way; for
                # example, storyboards in watchOS applications are simple plists and
                # don't retain the same .storyboardc directory structure that others do.
                if result.compiled_storyboards:
                    linked_storyboards = _link_storyboards(
                        ctx,
                        result.compiled_storyboards.to_list(),
                        resource_info,
                    )
                    bundle_merge_files.append(bundling_support.resource_file(
                        ctx,
                        linked_storyboards,
                        bundle_dir,
                        contents_only = True,
                    ))

                if result.partial_infoplists:
                    infoplists_so_far = bundle_infoplists.get(bundle_dir, [])
                    infoplists_so_far.extend(list(result.partial_infoplists))
                    bundle_infoplists[bundle_dir] = infoplists_so_far

    # Partition out plists and strings files from legacy objc_bundles and
    # structured_resources because we need to compile them as well. For everything
    # else, copy the files verbatim.
    bundle_merge_files.extend(_process_plists_and_strings(
        ctx,
        bundle_id,
        resource_sets,
        "objc_bundle_imports",
        path_utils.bundle_relative_path,
        file_filter_partial,
    ))
    bundle_merge_files.extend(_process_plists_and_strings(
        ctx,
        bundle_id,
        resource_sets,
        "structured_resources",
        path_utils.owner_relative_path,
        file_filter_partial,
    ))

    for r in resource_sets:
        # Copy any structured_resource_zips found in the resource sets.
        bundle_merge_zips.extend([
            bundling_support.resource_file(ctx, f, r.bundle_dir)
            for f in r.structured_resource_zips
        ])

        # Track any additional infoplists that were propagated by dependencies.
        if r.infoplists:
            infoplists_so_far = bundle_infoplists.get(r.bundle_dir, [])
            infoplists_so_far.extend(list(r.infoplists))
            bundle_infoplists[r.bundle_dir] = infoplists_so_far

        if r.bundle_dir and r.resource_bundle_target_data:
            existing = bundle_to_tgt_datas.get(r.bundle_dir)
            if existing:
                if existing.label != r.resource_bundle_target_data.label:
                    fail(("Internal error: AppleResourceSets with different " +
                          "resource_bundle_target_datas?! (%r: %r vs %r)") %
                         (
                             r.bundle_dir,
                             str(existing.label),
                             str(r.resource_bundle_target_data.label),
                         ))
            else:
                bundle_to_tgt_datas[r.bundle_dir] = r.resource_bundle_target_data

    if file_filter_partial and sets.length(locales_dropped):
        # If something was filtered away, then warn the user if there was they
        # wanted to keep but it wasn't found. It could be just a typo on the
        # filter so the message makes it easier to notice. The down side is it
        # could be chatty if there is a bundle that legitimately doesn't
        # support the locale; this is attempted to be mitigated by ensuring
        # something was dropped before producing this message.
        if not sets.is_equal(locales_to_include, locales_included):
            unused_locales = sets.difference(locales_to_include, locales_included)
            print(("Warning: Bundle '" + bundle_id + "' did not have resources that " +
                   "matched " + sets.str(unused_locales) + " in locale filter. " +
                   "Please verify apple.locales_to_include is defined properly."))
    return struct(
        bundle_dir_to_resource_bundle_target_datas = bundle_to_tgt_datas,
        bundle_infoplists = bundle_infoplists,
        bundle_merge_files = bundle_merge_files,
        bundle_merge_zips = bundle_merge_zips,
    )

# Define the loadable module that lists the exported symbols in this file.
resource_actions = struct(
    process_resource_sets = _process_resource_sets,
)
