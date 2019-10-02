licenses(["notice"])

package(
    default_visibility = ["//test/starlark_tests:__subpackages__"],
)

load(
    "//apple:resources.bzl",
    "apple_bundle_import",
    "apple_resource_bundle",
    "apple_resource_group",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "swift_library",
)
load(
    "//test/starlark_tests:rules/dummy_apple_resource_info.bzl",
    "dummy_apple_resource_info",
)

# Exports all files in this package as targets to make it easier to depend on them.
# Because these are for Starlark tests, we can scope the visibility to just this
# package.
exports_files(
    glob(["**"]),
    visibility = ["//test/starlark_tests:__subpackages__"],
)

objc_library(
    name = "objc_shared_lib",
    srcs = ["shared.m"],
    hdrs = ["shared.h"],
)

objc_library(
    name = "objc_main_lib",
    srcs = ["main.m"],
)

swift_library(
    name = "watchkit_ext_main_lib",
    srcs = ["WatchKitExtMain.swift"],
    tags = [
        "manual",
    ],
)

objc_library(
    name = "objc_test_lib",
    srcs = ["test.m"],
)

apple_bundle_import(
    name = "settings_bundle_ios",
    bundle_imports = [":settings_bundle_ios_files"],
)

filegroup(
    name = "settings_bundle_ios_files",
    srcs = glob(["settings_ios.bundle/**"]),
)

genrule(
    name = "generate_strings",
    outs = ["generated.strings"],
    cmd = "echo '\"generated_string\" = \"I like turtles!\";' > $@",
)

genrule(
    name = "generate_structured_strings",
    outs = ["structured/generated.strings"],
    cmd = "echo '\"generated_structured_string\" = \"I like turtles too!\";' > $@",
)

dummy_apple_resource_info(
    name = "custom_apple_resource_info",
)

apple_resource_bundle(
    name = "resource_bundle",
    infoplists = ["Another.plist"],
    resources = [":custom_apple_resource_info"],
)

apple_resource_bundle(
    name = "localization",
    resources = [
        "en.lproj/files.stringsdict",
        "en.lproj/greetings.strings",
    ],
)

filegroup(
    name = "example_filegroup",
    srcs = [
        ":Another.plist",
    ],
)

filegroup(
    name = "all_nested",
    srcs = [
        "nested/nested.txt",
        "non_nested.txt",
    ],
)

apple_resource_group(
    name = "structured_resources_in_resources",
    structured_resources = [
        "Resources/some.file",
    ],
)

objc_library(
    name = "structured_resources_in_resources_lib",
    srcs = ["main.m"],
    data = [
        ":structured_resources_in_resources",
    ],
)

filegroup(
    name = "localized_plists",
    srcs = glob(["*.lproj/*.plist"]),
)

filegroup(
    name = "assets_ios",
    srcs = glob(["assets_ios.xcassets/**"]),
)

filegroup(
    name = "app_icons_ios",
    srcs = glob(["app_icons_ios.xcassets/**"]),
)

filegroup(
    name = "launch_images_ios",
    srcs = glob(["launch_images_ios.xcassets/**"]),
)

filegroup(
    name = "basic_bundle_files",
    srcs = glob(["basic.bundle/**"]),
)

filegroup(
    name = "localized_storyboards_ios",
    srcs = glob(["*.lproj/*.storyboard"]),
)

filegroup(
    name = "localized_strings",
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

filegroup(
    name = "localized_generic_resources",
    srcs = glob(["*.lproj/*.txt"]),
)

filegroup(
    name = "sticker_pack_ios",
    srcs = glob(["sticker_pack_ios.xcstickers/**"]),
)

objc_library(
    name = "sticker_pack_ios_lib",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    data = [
        ":sticker_pack_ios",
    ],
)

apple_bundle_import(
    name = "basic_bundle",
    bundle_imports = [":basic_bundle_files"],
)

objc_library(
    name = "basic_bundle_lib",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    data = [
        ":basic_bundle",
    ],
)

apple_bundle_import(
    name = "nested_bundle",
    bundle_imports = glob(["nested_bundle/nested.bundle/**"]),
)

objc_library(
    name = "nested_bundle_lib",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    data = [
        ":nested_bundle",
    ],
)

objc_library(
    name = "ios_non_localized_assets_lib",
    srcs = ["main.m"],
    data = [
        ":assets_ios",
        ":mapping_model",
        ":nonlocalized.plist",
        ":nonlocalized.strings",
        ":sample.png",
        ":storyboard_ios.storyboard",
        ":unversioned_datamodel",
        ":versioned_datamodel",
        ":view_ios.xib",
    ],
)

objc_library(
    name = "ios_localized_assets_lib",
    srcs = ["main.m"],
    data = [
        ":localized_generic_resources",
        ":localized_plists",
        ":localized_storyboards_ios",
        ":localized_strings",
        ":localized_xibs_ios",
    ],
)

objc_library(
    name = "empty_strings_file_lib",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    data = [
        "empty.strings",
    ],
)

apple_resource_bundle(
    name = "bundle_library_ios",
    infoplists = [
        "Info-template.plist",
    ],
    resources = [
        "generated.strings",
        "nonlocalized.plist",
        "nonlocalized.strings",
        "nonlocalized_resource.txt",
        "sample.png",
        "storyboard_ios.storyboard",
        "view_ios.xib",
        ":assets_ios",
        ":basic_bundle",
        ":localized_generic_resources",
        ":localized_plists",
        ":localized_storyboards_ios",
        ":localized_strings",
        ":localized_xibs_ios",
        ":mapping_model",
        ":unversioned_datamodel",
        ":versioned_datamodel",
    ],
    structured_resources = [
        ":generate_structured_strings",
        ":structured",
    ],
)

objc_library(
    name = "bundle_library_ios_lib",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    data = [
        ":bundle_library_ios",
    ],
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

objc_library(
    name = "framework_resources_lib",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    data = [
        "framework_resources/nonlocalized.plist",
    ],
)
