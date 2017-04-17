package(default_visibility = ["//visibility:public"])

licenses(["notice"])

exports_files([
    "launch_screen_ios.storyboard",
    "nonlocalized.strings",
    "nonlocalized_resource.txt",
    "storyboard_ios.storyboard",
    "view_ios.xib",
])

# A convenience target that can be passed into the data attribute of an Apple
# shell test to make the iOS-compatible resources available to builds under
# test.
filegroup(
    name = "resource_data_deps_ios",
    srcs = [
        "BUILD",
        "launch_screen_ios.storyboard",
        "storyboard_ios.storyboard",
        "view_ios.xib",
        ":app_icons_ios",
        ":assets_ios",
        ":launch_images_ios",
        ":localized_storyboards_ios",
        ":localized_strings_ios",
        ":localized_xibs_ios",
        ":mapping_model",
        ":settings_bundle_ios_files",
        ":sticker_pack_ios",
        ":unversioned_datamodel",
        ":versioned_datamodel",
    ],
)

filegroup(
    name = "resource_data_deps_platform_independent",
    srcs = [
        "BUILD",
        "nonlocalized.strings",
        "nonlocalized_resource.txt",
        ":basic_bundle_files",
        ":localized_generic_resources",
        ":structured",
    ],
)

filegroup(
    name = "texture_atlas_data_deps",
    srcs = [
        "BUILD",
        ":star_atlas_files",
    ],
)

filegroup(
    name = "app_icons_ios",
    srcs = glob(["app_icons_ios.xcassets/**"]),
)

filegroup(
    name = "assets_ios",
    srcs = glob(["assets_ios.xcassets/**"]),
)

filegroup(
    name = "assets_tvos",
    srcs = glob(["assets_tvos.xcassets/**"]),
)

filegroup(
    name = "assets_watchos",
    srcs = glob(["assets_watchos.xcassets/**"]),
)

objc_bundle(
    name = "basic_bundle",
    bundle_imports = [":basic_bundle_files"],
)

filegroup(
    name = "basic_bundle_files",
    srcs = glob(["basic.bundle/**"]),
)

objc_bundle_library(
    name = "bundle_library",
    asset_catalogs = [":assets_ios"],
    bundles = [":basic_bundle"],
    datamodels = [
        ":unversioned_datamodel",
        ":versioned_datamodel",
    ],
    resources = [
        "nonlocalized_resource.txt",
        ":localized_generic_resources",
        ":mapping_model",
    ],
    storyboards = [
        "storyboard_ios.storyboard",
        ":localized_storyboards_ios",
    ],
    strings = [
        "nonlocalized.strings",
        ":localized_strings_ios",
    ],
    structured_resources = [":structured"],
    xibs = [
        "view_ios.xib",
        ":localized_xibs_ios",
    ],
)

filegroup(
    name = "launch_images_ios",
    srcs = glob(["launch_images_ios.xcassets/**"]),
)

filegroup(
    name = "localized_generic_resources",
    srcs = glob(["*.lproj/*.txt"]),
)

filegroup(
    name = "localized_storyboards_ios",
    srcs = glob(["*.lproj/*.storyboard"]),
)

filegroup(
    name = "localized_strings_ios",
    srcs = glob(["*.lproj/*.strings"]),
)

filegroup(
    name = "localized_xibs_ios",
    srcs = glob(["*.lproj/*.xib"]),
)

filegroup(
    name = "mapping_model",
    srcs = glob(["mapping_model.xcmappingmodel/**"]),
)

objc_bundle(
    name = "settings_bundle_ios",
    bundle_imports = [":settings_bundle_ios_files"],
)

filegroup(
    name = "settings_bundle_ios_files",
    srcs = glob(["settings_ios.bundle/**"]),
)

filegroup(
    name = "star_atlas_files",
    srcs = glob(["star.atlas/**"]),
)

filegroup(
    name = "sticker_pack_ios",
    srcs = glob(["sticker_pack_ios.xcstickers/**"]),
)

filegroup(
    name = "structured",
    srcs = glob(["structured/**"]),
)

filegroup(
    name = "unversioned_datamodel",
    srcs = glob(["unversioned_datamodel.xcdatamodel/**"]),
)

filegroup(
    name = "versioned_datamodel",
    srcs = glob(["versioned_datamodel.xcdatamodeld/**"]),
)
