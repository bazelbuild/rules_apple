load(
    "//apple:resources.bzl",
    "apple_bundle_import",
    "apple_resource_bundle",
)

package(
    default_visibility = ["//test:__subpackages__"],
)

licenses(["notice"])

exports_files(
    [
        "nonlocalized.plist",
        "nonlocalized.strings",
        "nonlocalized_resource.txt",
        "sample.png",
        "storyboard_ios.storyboard",
        "view_ios.xib",
    ],
    visibility = ["//test:__subpackages__"],
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
    name = "assets2_ios",
    srcs = glob(["assets2_ios.xcassets/**"]),
)

apple_bundle_import(
    name = "basic_bundle",
    bundle_imports = [":basic_bundle_files"],
)

filegroup(
    name = "basic_bundle_files",
    srcs = glob(["basic.bundle/**"]),
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

genrule(
    name = "generate_storyboard_copy",
    srcs = ["storyboard_ios.storyboard"],
    outs = ["storyboard_ios_copy.storyboard"],
    cmd = "cp $< $@",
)

# A resource bundle containing only resources that don't require Apple's
# processing tools (actool, ibtool, etc.), which can occasionally flake. This
# provides a bundle that still undergoes basic resource processing for tests
# checking resource deduplication, etc.
apple_resource_bundle(
    name = "simple_bundle_library",
    bundle_name = "simple_bundle_library",
    infoplists = [
        "Info-template.plist",
    ],
    resources = [
        "generated.strings",
        "nonlocalized.plist",
        "nonlocalized.strings",
        "nonlocalized_resource.txt",
        "sample.png",
        ":basic_bundle",
        ":localized_generic_resources",
        ":localized_plists",
        ":localized_strings",
    ],
    structured_resources = [
        ":generate_structured_strings",
        ":structured",
    ],
)

filegroup(
    name = "localized_generic_resources",
    srcs = glob(["*.lproj/*.txt"]),
)

filegroup(
    name = "localized_plists",
    srcs = glob(["*.lproj/*.plist"]),
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
    name = "message_ext_app_icon_ios",
    srcs = glob(["message_ext_app_icon_ios.xcassets/**"]),
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
