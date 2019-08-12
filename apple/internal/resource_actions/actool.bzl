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

"""ACTool related actions."""

load(
    "@build_bazel_apple_support//lib:xcode_support.bzl",
    "xcode_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:legacy_actions.bzl",
    "legacy_actions",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:xctoolrunner.bzl",
    "xctoolrunner",
)
load(
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/internal:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "group_files_by_directory",
)
load(
    "@bazel_skylib//lib:collections.bzl",
    "collections",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

def _actool_args_for_special_file_types(ctx, asset_files):
    """Returns command line arguments needed to compile special assets.

    This function is called by `actool` to scan for specially recognized asset
    types, such as app icons and launch images, and determine any extra command
    line arguments that need to be passed to `actool` to handle them. It also
    checks the validity of those assets, if any (for example, by permitting only
    one app icon set or launch image set to be present).

    Args:
      ctx: The target's rule context.
      asset_files: The asset catalog files.

    Returns:
      An array of extra arguments to pass to `actool`, which may be empty.
    """
    args = []

    product_type = ctx.attr._product_type
    if product_type in (
        apple_product_type.messages_extension,
        apple_product_type.messages_sticker_pack_extension,
    ):
        appicon_extension = "stickersiconset"
        icon_files = [f for f in asset_files if ".stickersiconset/" in f.path]

        # TODO(kaipi): We might be processing a resource bundle inside an
        # ios_extension, in which case the bundle ID might not be appropriate here.
        args.extend([
            "--sticker-pack-identifier-prefix",
            ctx.attr.bundle_id + ".sticker-pack.",
        ])

        # Fail if the user has included .appiconset folders in their asset catalog;
        # Message extensions must use .stickersiconset instead.
        #
        # NOTE: This is mostly caught via the validation in ios_extension of the
        # app_icons attribute; however, since different resource attributes from
        # *_library targets are merged into here, other resources could show up
        # so until the resource handing is revisited (b/77804841), things could
        # still show up that don't make sense.
        appiconset_files = [f for f in asset_files if ".appiconset/" in f.path]
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
            icon_files = [f for f in asset_files if ".brandassets/" in f.path]
        else:
            appicon_extension = "appiconset"
            icon_files = [f for f in asset_files if ".appiconset/" in f.path]

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
    launch_image_files = [f for f in asset_files if ".launchimage/" in f.path]
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

def compile_asset_catalog(ctx, asset_files, output_dir, output_plist):
    """Creates an action that compiles asset catalogs.

    This action populates a directory with compiled assets that must be merged
    into the application/extension bundle. It also produces a partial Info.plist
    that must be merged info the application's main plist if an app icon or
    launch image are requested (if not, the actool plist is empty).

    Args:
      ctx: The target's rule context.
      asset_files: An iterable of files in all asset catalogs that should be
          packaged as part of this catalog. This should include transitive
          dependencies (i.e., assets not just from the application target, but
          from any other library targets it depends on) as well as resources like
          app icons and launch images.
      output_dir: The directory where the compiled outputs should be placed.
      output_plist: The file reference for the output plist that should be merged
        into Info.plist. May be None if the output plist is not desired.
    """
    platform = platform_support.platform(ctx)
    min_os = platform_support.minimum_os(ctx)
    actool_platform = platform.name_in_plist.lower()

    args = [
        "actool",
        "--compile",
        xctoolrunner.prefixed_path(output_dir.path),
        "--platform",
        actool_platform,
        "--minimum-deployment-target",
        min_os,
        "--compress-pngs",
    ]

    if xcode_support.is_xcode_at_least_version(
        ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
        "8",
    ):
        product_type = ctx.attr._product_type
        if product_type:
            args.extend(["--product-type", product_type])

    args.extend(_actool_args_for_special_file_types(
        ctx,
        asset_files,
    ))
    args.extend(collections.before_each(
        "--target-device",
        platform_support.families(ctx),
    ))

    outputs = [output_dir]
    if output_plist:
        outputs.append(output_plist)
        args.extend([
            "--output-partial-info-plist",
            xctoolrunner.prefixed_path(output_plist.path),
        ])

    xcassets = group_files_by_directory(
        asset_files,
        ["xcassets", "xcstickers"],
        attr = "asset_catalogs",
    ).keys()

    args.extend([xctoolrunner.prefixed_path(xcasset) for xcasset in xcassets])

    legacy_actions.run(
        ctx,
        inputs = asset_files,
        outputs = outputs,
        executable = ctx.executable._xctoolrunner,
        arguments = args,
        mnemonic = "AssetCatalogCompile",
        execution_requirements = {"no-sandbox": "1"},
    )
