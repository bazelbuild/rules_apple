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
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "group_files_by_directory",
)
load(
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/internal:bundling_support.bzl",
    "bundling_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:xctoolrunner.bzl",
    xctoolrunner_support = "xctoolrunner",
)

visibility("@build_bazel_rules_apple//apple/internal/...")

def _validate_sticker_icon_sets(*, icon_bundle_files, stickers_icon_files, xcasset_appicon_files):
    """Validates that the asset files contain only sticker icon sets."""
    message = ("Message extensions must use Messages Extensions Icon Sets " +
               "(named .stickersiconset), not traditional App Icon Sets")
    bundling_support.ensure_single_xcassets_type(
        extension = "stickersiconset",
        files = stickers_icon_files,
        message = message,
    )

    # Check that there are no .appiconset files, which are not allowed for messages extensions.
    bundling_support.ensure_asset_catalog_files_not_in_xcassets(
        extension = "appiconset",
        files = xcasset_appicon_files,
        message = message,
    )

    if icon_bundle_files:
        fail("""
Icon Composer .icon bundles are not supported for Messages Extensions.

Found the following: {icon_bundle_files}

""".format(icon_bundle_files = icon_bundle_files))

def _validate_tvos_icon_sets(*, brandassets_icon_files, icon_bundle_files, xcasset_appicon_files):
    """Validates that the asset files contain only tvOS brand assets."""
    message = ("tvOS apps must use tvOS brand assets (named .brandassets), " +
               "not traditional App Icon Sets")
    bundling_support.ensure_single_xcassets_type(
        extension = "brandassets",
        files = brandassets_icon_files,
        message = message,
    )

    # Check that there are no .appiconset files, which are not allowed for tvOS apps.
    bundling_support.ensure_asset_catalog_files_not_in_xcassets(
        extension = "appiconset",
        files = xcasset_appicon_files,
        message = message,
    )

    if icon_bundle_files:
        fail("""
Icon Composer .icon bundles are not supported for tvOS.

Found the following: {icon_bundle_files}

""".format(icon_bundle_files = icon_bundle_files))

def _validate_visionos_icon_sets(*, icon_bundle_files, image_stack_files, xcasset_appicon_files):
    """Validates that the asset files contain only visionOS app icon layers."""
    message = ("visionOS apps must use visionOS app icon layers grouped in " +
               ".solidimagestack bundles, not traditional App Icon Sets")
    bundling_support.ensure_single_xcassets_type(
        extension = "solidimagestack",
        files = image_stack_files,
        message = message,
    )

    # Check that there are no .appiconset files, which are not allowed for visionOS apps.
    bundling_support.ensure_asset_catalog_files_not_in_xcassets(
        extension = "appiconset",
        files = xcasset_appicon_files,
        message = message,
    )

    if icon_bundle_files:
        fail("""
Icon Composer .icon bundles are not supported for visionOS.

Found the following: {icon_bundle_files}

""".format(icon_bundle_files = icon_bundle_files))

def _validate_standard_app_icon_sets(
        *,
        icon_bundle_files,
        icon_files,
        minimum_os_version,
        xcode_config):
    """Validates that the asset files contain only standard app icon sets."""

    min_os_version_26_or_later = (
        apple_common.dotted_version(minimum_os_version) >=
        apple_common.dotted_version("26.0")
    )

    if min_os_version_26_or_later and icon_files:
        fail("""
Legacy .appiconset files should not be used on iOS/macOS/watchOS 26+.

These platforms prefer Icon Composer .icon bundles. .appiconset files are only needed for \
rendering icons in iOS/macOS/watchOS prior to 26.

Found the following legacy .appiconset files: {xcasset_appicon_files}
""".format(xcasset_appicon_files = icon_files))

    bundling_support.ensure_single_xcassets_type(
        extension = "appiconset",
        files = icon_files,
    )

    if icon_bundle_files:
        is_xcode_26_or_later = xcode_config.xcode_version() >= apple_common.dotted_version("26.0")
        if not is_xcode_26_or_later:
            fail("""
            Found Icon Composer .icon bundles among the assigned app_icons. These are only \
            supported on Xcode 26 or later.
            """)

        if icon_files:
            fail("""
            Found .appiconset files among the assigned app_icons, which are ignored when Icon \
            Composer .icon bundles are present.
            """)

        bundling_support.ensure_asset_catalog_files_not_in_xcassets(
            extension = "icon",
            files = icon_bundle_files,
        )

def _icon_info_from_asset_files(
        *,
        asset_files,
        minimum_os_version,
        platform_type,
        product_type,
        xcode_config):
    """Returns information about the icon files in the asset files."""

    # Check for legacy asset catalog .appiconset files, which used to serve as generic icons for
    # iOS, macOS and watchOS apps.
    xcasset_appicon_files = [f for f in asset_files if ".appiconset/" in f.path]
    icon_bundle_files = [f for f in asset_files if ".icon/" in f.path]

    if product_type == apple_product_type.messages_extension:
        appicon_extension = "stickersiconset"
        icon_files = [f for f in asset_files if ".stickersiconset/" in f.path]
        _validate_sticker_icon_sets(
            icon_bundle_files = icon_bundle_files,
            stickers_icon_files = icon_files,
            xcasset_appicon_files = xcasset_appicon_files,
        )
    elif platform_type == "tvos":
        appicon_extension = "brandassets"
        icon_files = [f for f in asset_files if ".brandassets/" in f.path]
        _validate_tvos_icon_sets(
            brandassets_icon_files = icon_files,
            icon_bundle_files = icon_bundle_files,
            xcasset_appicon_files = xcasset_appicon_files,
        )
    elif platform_type == "visionos":
        appicon_extension = "solidimagestack"
        icon_files = [f for f in asset_files if ".solidimagestack/" in f.path]
        _validate_visionos_icon_sets(
            icon_bundle_files = icon_bundle_files,
            image_stack_files = icon_files,
            xcasset_appicon_files = xcasset_appicon_files,
        )
    else:
        appicon_extension = "appiconset"
        icon_files = xcasset_appicon_files
        _validate_standard_app_icon_sets(
            icon_bundle_files = icon_bundle_files,
            icon_files = icon_files,
            minimum_os_version = minimum_os_version,
            xcode_config = xcode_config,
        )
    return struct(
        appicon_extension = appicon_extension,
        icon_files = icon_files,
        icon_bundle_files = icon_bundle_files,
    )

def _unique_icon_names(*, all_icon_dirs):
    """Returns the unique icon names from the given icon directories."""
    app_icon_names = set()
    for icon_dir in all_icon_dirs:
        app_icon_names.add(paths.split_extension(paths.basename(icon_dir))[0])
    return app_icon_names

def _verify_icon_dirs(
        *,
        appicon_extension,
        icon_bundle_dirs,
        icon_dirs,
        platform_type,
        primary_icon_name,
        product_type):
    """Verifies that the icon directories are valid."""

    has_exactly_one_icon_dir = False

    if len(icon_dirs + icon_bundle_dirs) == 1:
        has_exactly_one_icon_dir = True

    if not has_exactly_one_icon_dir and not primary_icon_name:
        formatted_dirs = "[\n  %s\n]" % ",\n  ".join(icon_dirs)

        # Alternate icons are only supported for UIKit applications on iOS, tvOS, visionOS and
        # iOS-on-macOS (Catalyst)
        if (platform_type in ("watchos", "macos") or
            product_type != apple_product_type.application):
            if icon_bundle_dirs:
                fail("""
The app_icons should contain exactly one directory named *.icon (the Icon Composer .icon bundle), \
but found the following:
{formatted_dirs}

""".format(
                    formatted_dirs = formatted_dirs,
                ))
            else:
                fail("""
The asset catalogs should contain exactly one directory named *.{appicon_extension} among its \
asset catalogs, but found the following:
{formatted_dirs}

""".format(
                    appicon_extension = appicon_extension,
                    formatted_dirs = formatted_dirs,
                ))
        else:
            fail("""
Found multiple app icons among the asset catalogs with no primary_app_icon assigned.

If you intend to assign multiple app icons to this target, please declare which of these is \
intended to be the primary app icon with the primary_app_icon attribute on the rule itself.

Target was assigned the following app icons:
{formatted_dirs}

""".format(formatted_dirs = formatted_dirs))

def _args_for_app_icons(
        *,
        bundle_id,
        icon_info,
        primary_icon_name,
        platform_type,
        product_type):
    """Returns arguments for app icons."""
    args = []
    if product_type == apple_product_type.messages_extension:
        args.extend([
            "--include-sticker-content",
            "--stickers-icon-role",
            "extension",
            "--sticker-pack-identifier-prefix",
            bundle_id + ".sticker-pack.",
        ])

    appicon_extension = icon_info.appicon_extension
    icon_files = icon_info.icon_files
    icon_bundle_files = icon_info.icon_bundle_files

    if icon_files or icon_bundle_files:
        icon_dirs = group_files_by_directory(
            icon_files,
            [appicon_extension],
            attr = appicon_extension,
        ).keys()
        icon_bundle_dirs = group_files_by_directory(
            icon_bundle_files,
            ["icon"],
            attr = "icon",
        ).keys()

        _verify_icon_dirs(
            appicon_extension = appicon_extension,
            icon_bundle_dirs = icon_bundle_dirs,
            icon_dirs = icon_dirs,
            platform_type = platform_type,
            primary_icon_name = primary_icon_name,
            product_type = product_type,
        )

        if primary_icon_name:
            # Check that primary_icon_name matches one of the icon sets, then add actool arguments
            # for `--alternate-app-icon` and `--app_icon` as appropriate. These do NOT overlap.
            unique_icon_names = _unique_icon_names(all_icon_dirs = icon_dirs + icon_bundle_dirs)
            found_primary = False
            for app_icon_name in unique_icon_names:
                if app_icon_name == primary_icon_name:
                    found_primary = True
                    args += ["--app-icon", primary_icon_name]
                else:
                    args += ["--alternate-app-icon", app_icon_name]
            if not found_primary:
                fail("""
Could not find the primary icon named "{primary_icon_name}" in the list of app icons provided.

Found the following icon names from those provided: {unique_icon_names}.
""".format(
                    primary_icon_name = primary_icon_name,
                    unique_icon_names = ", ".join(unique_icon_names),
                ))
        else:
            app_icon_name = _unique_icon_names(all_icon_dirs = icon_dirs + icon_bundle_dirs).pop()
            args += ["--app-icon", app_icon_name]

    return args

def _args_for_launch_images(*, launch_image_files):
    """Returns arguments for launch images."""
    launch_image_dirs = group_files_by_directory(
        launch_image_files,
        ["launchimage"],
        attr = "launchimage",
    ).keys()
    if len(launch_image_dirs) != 1:
        formatted_dirs = "[\n  %s\n]" % ",\n  ".join(launch_image_dirs)
        fail("The asset catalogs should contain exactly one directory named " +
             "*.launchimage among its asset catalogs, but found the " +
             "following: " + formatted_dirs, "launch_images")

    launch_image_name = paths.split_extension(
        paths.basename(launch_image_dirs[0]),
    )[0]
    return ["--launch-image", launch_image_name]

def _validate_asset_files_and_generate_args(
        *,
        asset_files,
        bundle_id,
        minimum_os_version,
        platform_type,
        primary_icon_name,
        product_type,
        xcode_config):
    """Validates asset files and returns extra command line arguments needed to compile assets.

    This function is called by `actool` to scan for specially recognized asset
    types, such as app icons and launch images, and determine any extra command
    line arguments that need to be passed to `actool` to handle them. It also
    checks the validity of those assets, if any (for example, by permitting only
    one app icon set or launch image set to be present).

    Args:
      asset_files: The asset catalog files.
      bundle_id: The bundle ID to configure for this target.
      minimum_os_version: The minimum OS version for the current platform.
      platform_type: The platform type identifier used to describe the current platform.
      primary_icon_name: An optional String to identify the name of the primary app icon when
        alternate app icons have been provided for the app.
      product_type: The product type identifier used to describe the current bundle type.
      xcode_config: The Xcode version config for the current build.

    Returns:
      An array of extra arguments to pass to `actool`, which may be empty.
    """
    args = []

    icon_info = _icon_info_from_asset_files(
        asset_files = asset_files,
        minimum_os_version = minimum_os_version,
        platform_type = platform_type,
        product_type = product_type,
        xcode_config = xcode_config,
    )

    args.extend(_args_for_app_icons(
        bundle_id = bundle_id,
        icon_info = icon_info,
        platform_type = platform_type,
        primary_icon_name = primary_icon_name,
        product_type = product_type,
    ))

    launch_image_files = [f for f in asset_files if ".launchimage/" in f.path]
    if launch_image_files and platform_type == "tvos":
        # Launch images are deprecated on iOS and tvOS, but tvOS apps are still allowed to ship with
        # them. iOS apps will simply fail to show any launch images, at least as of iOS 26.
        bundling_support.ensure_single_xcassets_type(
            extension = "launchimage",
            files = launch_image_files,
        )
        args.extend(_args_for_launch_images(launch_image_files = launch_image_files))
    elif launch_image_files:
        # There is no other way to issue a warning, so print is the only way to message.
        # buildifier: disable=print
        print("""
WARNING: Launch images are no longer functional on {platform_type}, but this target still contains \
launch images.

Found the following launch image files:
{launch_image_files}

Please consider removing them.
""".format(
            launch_image_files = launch_image_files,
            platform_type = platform_type,
        ))

    return args

def compile_asset_catalog(
        *,
        actions,
        asset_files,
        bundle_id,
        mac_exec_group,
        output_dir,
        output_plist,
        platform_prerequisites,
        primary_icon_name,
        product_type,
        xctoolrunner):
    """Creates an action that compiles asset catalogs.

    This action populates a directory with compiled assets that must be merged
    into the application/extension bundle. It also produces a partial Info.plist
    that must be merged info the application's main plist if an app icon or
    launch image are requested (if not, the actool plist is empty).

    Args:
      actions: The actions provider from `ctx.actions`.
      asset_files: An iterable of files in all asset catalogs that should be
          packaged as part of this catalog. This should include transitive
          dependencies (i.e., assets not just from the application target, but
          from any other library targets it depends on) as well as resources like
          app icons and launch images.
      bundle_id: The bundle ID to configure for this target.
      mac_exec_group: The exec group associated with xctoolrunner.
      output_dir: The directory where the compiled outputs should be placed.
      output_plist: The file reference for the output plist that should be merged
        into Info.plist. May be None if the output plist is not desired.
      platform_prerequisites: Struct containing information on the platform being targeted.
      primary_icon_name: An optional String to identify the name of the primary app icon when
        alternate app icons have been provided for the app.
      product_type: The product type identifier used to describe the current bundle type.
      xctoolrunner: A files_to_run for the wrapper around the "xcrun" tool.
    """
    platform = platform_prerequisites.platform
    actool_platform = platform.name_in_plist.lower()
    xcode_config = platform_prerequisites.xcode_version_config

    xcode_before_26 = (
        xcode_config.xcode_version() <
        apple_common.dotted_version("26.0")
    )

    args = actions.args()
    args.add("actool")

    # Custom xctoolrunner options.
    args.add_all([
        # Mute warnings for iPad 1x 76x76 icons.
        "--mute-warning=substring=[][ipad][76x76][][][1x][][][]: notice: (null)",
        "--mute-warning=substring=[][ipad][76x76][][][1x][][][]: notice: 76x76@1x ",
        "--mute-warning=substring=app icons only apply to iPad apps targeting releases of iOS prior to 10.0.",
        # Mute harmless CoreImage errors, referencing SDK artifacts that are not provided by Xcode.
        "--mute-error=substring=CIPortraitEffectSpillCorrection",
        "--mute-error=substring=RuntimeRoot/System/Library/CoreImage/PortraitFilters.cifilter",
        # Downgrade errors for requiring a 1024x1024 PNG for App Store distribution. (b/246165573)
        "--downgrade-error=substring=1024x1024",
        # Downgrade errors for icons referenced by multiple xcassets imagesets. (b/139094648)
        "--downgrade-error=substring=is used by multiple",
        # Downgrade errors for the use of launch images in iOS and tvOS apps.
        "--downgrade-error=substring=Launch images are deprecated in iOS 13.0",
        "--downgrade-error=substring=Launch images are deprecated in tvOS 13.0",
    ])

    if not xcode_before_26:
        # Handle the nonsense warnings and errors for Xcode 26.
        args.add_all([
            # Downgrade "Failed to generate flattened icon stack" warnings for Xcode 26. This is
            # called out in the release notes as an error that can be "safely ignored" in
            # https://developer.apple.com/documentation/xcode-release-notes/xcode-26-release-notes.
            # In our experience, these are sometimes actionable, but appear to be impossible to
            # resolve on watchOS given certain inputs.
            "--downgrade-error=substring=Failed to generate flattened icon stack for icon named ",
            # Mute spammy "Use of that symbol [...] is being set to 0xBAD4007." warnings from dyld
            # when executing the actool command to build new icons on Sequoia instead of Tahoe.
            "--mute-error=substring= is being set to 0xBAD4007.",
        ])

    # Standard actool options.
    args.add("--compile", xctoolrunner_support.prefixed_path(output_dir.path))
    args.add("--errors")
    args.add("--warnings")
    args.add("--notices")
    args.add("--output-format", "human-readable-text")
    args.add("--platform", actool_platform)
    args.add("--minimum-deployment-target", platform_prerequisites.minimum_os)
    args.add("--compress-pngs")

    platform_type = platform_prerequisites.platform_type

    extra_actool_args = _validate_asset_files_and_generate_args(
        asset_files = asset_files,
        bundle_id = bundle_id,
        minimum_os_version = platform_prerequisites.minimum_os,
        platform_type = platform_type,
        primary_icon_name = primary_icon_name,
        product_type = product_type,
        xcode_config = xcode_config,
    )
    args.add_all(extra_actool_args)

    args.add_all(platform_prerequisites.device_families, before_each = "--target-device")

    outputs = [output_dir]
    if output_plist:
        outputs.append(output_plist)
        args.add(
            "--output-partial-info-plist",
            xctoolrunner_support.prefixed_path(output_plist.path),
        )

    xcassets = group_files_by_directory(
        asset_files,
        ["icon", "xcassets"],
        attr = "asset_catalogs",
    ).keys()

    args.add_all([xctoolrunner_support.prefixed_path(xcasset) for xcasset in xcassets])

    execution_requirements = {
        "no-sandbox": "1",
    }

    apple_support.run(
        actions = actions,
        arguments = [args],
        apple_fragment = platform_prerequisites.apple_fragment,
        executable = xctoolrunner,
        execution_requirements = execution_requirements,
        exec_group = mac_exec_group,
        inputs = asset_files,
        mnemonic = "AssetCatalogCompile",
        outputs = outputs,
        xcode_config = xcode_config,
    )
