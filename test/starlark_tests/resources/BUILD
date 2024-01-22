load(
    "@build_bazel_rules_swift//swift:swift_library.bzl",
    "swift_library",
)
load(
    "//apple:resources.bzl",
    "apple_bundle_import",
    "apple_resource_bundle",
    "apple_resource_group",
)
load(
    "//apple/hints:apple_resource_hint.bzl",
    "apple_resource_hint",
)
load(
    "//test/starlark_tests:common.bzl",
    "common",
)
load(
    "//test/starlark_tests/rules:dummy_apple_resource_info.bzl",
    "dummy_apple_resource_info",
)

licenses(["notice"])

package(
    default_visibility = ["//test/starlark_tests:__subpackages__"],
)

# Exports all files in this package as targets to make it easier to depend on them.
# Because these are for Starlark tests, we can scope the visibility to just this
# package.
exports_files(
    glob(["**"]),
    visibility = [
        "//test/starlark_tests:__subpackages__",
    ],
)

# --------------------------------------------------------------------------------
# Objective-C common.h libraries

objc_library(
    name = "objc_common_lib",
    srcs = ["common.m"],
    hdrs = ["common.h"],
    tags = common.fixture_tags,
)

objc_library(
    name = "objc_common_lib_with_structured_resources",
    srcs = ["common.m"],
    hdrs = ["common.h"],
    data = [":structured_image_resources"],
    tags = common.fixture_tags,
)

objc_library(
    name = "objc_common_lib_with_structured_images",
    srcs = [
        ":common.h",
        ":common.m",
    ],
    data = [":structured_image_resources"],
    tags = common.fixture_tags,
)

# --------------------------------------------------------------------------------
# Objective-C shared.h libraries

objc_library(
    name = "objc_shared_lib",
    srcs = ["shared.m"],
    hdrs = ["shared.h"],
    tags = common.fixture_tags,
    deps = [
        ":objc_common_lib",
    ],
)

objc_library(
    name = "objc_shared_lib_with_resources",
    srcs = [
        "shared.h",
        "shared.m",
    ],
    data = [
        ":structured_resources",
    ],
    tags = common.fixture_tags,
)

objc_library(
    name = "objc_shared_lib_with_transitive_resources",
    srcs = ["shared.m"],
    hdrs = ["shared.h"],
    tags = common.fixture_tags,
    deps = [
        ":objc_common_lib_with_structured_resources",
    ],
)

objc_library(
    name = "another_objc_shared_lib_with_transitive_resources",
    srcs = ["shared.m"],
    hdrs = ["shared.h"],
    tags = common.fixture_tags,
    deps = [
        ":objc_common_lib_with_structured_resources",
    ],
)

objc_library(
    name = "objc_shared_lib_with_transitive_structured_resources",
    srcs = [
        "shared.h",
        "shared.m",
    ],
    deps = [":objc_common_lib_with_structured_images"],
    alwayslink = 1,
)

objc_library(
    name = "objc_shared_lib_with_resource_bundles",
    srcs = [
        "shared.h",
        "shared.m",
    ],
    data = [
        "//test/testdata/resources:basic_bundle",
        "//test/testdata/resources:simple_bundle_library",
    ],
)

# --------------------------------------------------------------------------------
# Objective-C main.m libraries

objc_library(
    name = "objc_main_lib",
    srcs = ["main.m"],
    tags = common.fixture_tags,
)

objc_library(
    name = "objc_main_lib_with_common_lib",
    srcs = ["main.m"],
    tags = common.fixture_tags,
    deps = [
        ":objc_common_lib",
    ],
)

objc_library(
    name = "objc_main_lib_with_structured_images",
    srcs = ["main.m"],
    data = [":structured_image_resources"],
    tags = common.fixture_tags,
)

objc_library(
    name = "objc_main_lib_with_transitive_structured_images",
    srcs = ["main.m"],
    tags = common.fixture_tags,
    deps = [":objc_common_lib_with_structured_images"],
)

objc_library(
    name = "objc_main_lib_with_transitive_resource_bundles",
    srcs = ["main.m"],
    tags = common.fixture_tags,
    deps = [
        ":objc_shared_lib_with_resource_bundles",
    ],
)

swift_library(
    name = "swift_main_lib",
    srcs = ["//test/testdata/sources:main.swift"],
    tags = common.fixture_tags,
)

swift_library(
    name = "watchkit_ext_main_lib",
    srcs = ["WatchKitExtMain.swift"],
    tags = common.fixture_tags,
)

swift_library(
    name = "watchkit_single_target_app_main_lib",
    srcs = ["WatchKitAppMain.swift"],
    tags = common.fixture_tags,
)

objc_library(
    name = "objc_test_lib",
    testonly = True,
    srcs = ["test.m"],
    tags = common.fixture_tags,
    deps = [
    ],
)

objc_library(
    name = "objc_swift_depending_test_lib",
    testonly = True,
    srcs = ["test.m"],
    tags = common.fixture_tags,
    deps = [
        ":swift_uikit_appdelegate",
    ],
)

swift_library(
    name = "swift_uikit_appdelegate",
    srcs = ["AppDelegate.swift"],
    tags = common.fixture_tags,
)

apple_bundle_import(
    name = "settings_bundle_ios",
    bundle_imports = [":settings_bundle_ios_files"],
    tags = common.fixture_tags,
)

filegroup(
    name = "settings_bundle_ios_files",
    srcs = glob(["settings_ios.bundle/**"]),
)

genrule(
    name = "generate_strings",
    outs = ["generated.strings"],
    cmd = "echo '\"generated_string\" = \"I like turtles!\";' > $@",
    tags = common.fixture_tags,
)

genrule(
    name = "generate_structured_strings",
    outs = ["structured/generated.strings"],
    cmd = "echo '\"generated_structured_string\" = \"I like turtles too!\";' > $@",
    tags = common.fixture_tags,
)

dummy_apple_resource_info(
    name = "custom_apple_resource_info",
    tags = common.fixture_tags,
)

apple_resource_bundle(
    name = "resource_bundle",
    infoplists = ["Another.plist"],
    resources = [":custom_apple_resource_info"],
    tags = common.fixture_tags,
)

apple_resource_bundle(
    name = "resource_bundle_with_structured_resource_group",
    resources = [":structured_resources"],
    tags = common.fixture_tags,
)

apple_resource_bundle(
    name = "localization",
    resources = [
        "en.lproj/files.stringsdict",
        "en.lproj/greetings.strings",
    ],
    tags = common.fixture_tags,
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
    name = "resources_with_resource_bundle",
    resources = [":resource_bundle"],
    tags = common.fixture_tags,
)

apple_resource_group(
    name = "structured_resources",
    structured_resources = [
        "Another.plist",
    ],
    tags = common.fixture_tags,
)

apple_resource_group(
    name = "structured_resources_duplicate",
    structured_resources = [
        "Another.plist",
    ],
    tags = common.fixture_tags,
)

apple_resource_group(
    name = "structured_resources_in_resources",
    structured_resources = [
        "Resources/some.file",
    ],
    tags = common.fixture_tags,
)

objc_library(
    name = "objc_lib_with_resources",
    srcs = ["@bazel_tools//tools/objc:objc_dummy.mm"],
    data = [
        ":structured_resources",
    ],
    tags = common.fixture_tags,
)

objc_library(
    name = "structured_resources_in_resources_lib",
    data = [
        ":structured_resources_in_resources",
    ],
    tags = common.fixture_tags,
)

apple_resource_group(
    name = "processed_resources_in_structured_resources",
    structured_resources = [
        ":localization",
    ],
)

objc_library(
    name = "processed_resources_in_structured_resources_lib",
    data = [
        ":processed_resources_in_structured_resources",
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
    name = "app_icons_with_alts_ios",
    srcs = glob(["app_icons_with_alts_ios.xcassets/**"]),
)

filegroup(
    name = "launch_images_ios",
    srcs = glob(["launch_images_ios.xcassets/**"]),
)

objc_library(
    name = "launch_images_ios_lib",
    data = [
        ":launch_images_ios",
    ],
    tags = common.fixture_tags,
)

objc_library(
    name = "launch_images_ios_lib_duplicated_target",
    data = [
        ":launch_images_ios",
    ],
    tags = common.fixture_tags,
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

apple_bundle_import(
    name = "basic_bundle",
    bundle_imports = [":basic_bundle_files"],
    tags = common.fixture_tags,
)

objc_library(
    name = "basic_bundle_lib",
    srcs = ["@bazel_tools//tools/objc:objc_dummy.mm"],
    data = [
        ":basic_bundle",
    ],
    tags = common.fixture_tags,
)

objc_library(
    name = "another_basic_bundle_lib",
    srcs = ["@bazel_tools//tools/objc:objc_dummy.mm"],
    data = [
        ":basic_bundle",
    ],
    tags = common.fixture_tags,
)

apple_bundle_import(
    name = "nested_bundle",
    bundle_imports = glob(["nested_bundle/nested.bundle/**"]),
    tags = common.fixture_tags,
)

objc_library(
    name = "nested_bundle_lib",
    data = [
        ":nested_bundle",
    ],
    tags = common.fixture_tags,
)

objc_library(
    name = "ios_non_localized_assets_lib",
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
    tags = common.fixture_tags,
)

objc_library(
    name = "ios_localized_assets_lib",
    data = [
        ":localized_generic_resources",
        ":localized_plists",
        ":localized_storyboards_ios",
        ":localized_strings",
        ":localized_xibs_ios",
    ],
    tags = common.fixture_tags,
)

objc_library(
    name = "apple_non_localized_assets_lib",
    data = [
        ":mapping_model",
        ":nonlocalized.plist",
        ":nonlocalized.strings",
        ":sample.png",
        ":unversioned_datamodel",
        ":versioned_datamodel",
    ],
    tags = common.fixture_tags,
)

objc_library(
    name = "apple_localized_assets_lib",
    data = [
        ":localized_generic_resources",
        ":localized_plists",
        ":localized_strings",
    ],
    tags = common.fixture_tags,
)

objc_library(
    name = "empty_strings_file_lib",
    data = [
        "empty.strings",
    ],
    tags = common.fixture_tags,
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
    tags = common.fixture_tags,
)

objc_library(
    name = "bundle_library_ios_lib",
    data = [
        ":bundle_library_ios",
    ],
    tags = common.fixture_tags,
)

apple_resource_bundle(
    name = "bundle_library_apple",
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
        ":mapping_model",
        ":unversioned_datamodel",
        ":versioned_datamodel",
    ],
    structured_resources = [
        ":generate_structured_strings",
        ":structured",
    ],
    tags = common.fixture_tags,
)

objc_library(
    name = "bundle_library_apple_lib",
    data = [
        ":bundle_library_apple",
    ],
    tags = common.fixture_tags,
)

apple_resource_group(
    name = "swift_structured_resources",
    structured_resources = [
        "//test/testdata/resources:structured",
    ],
    tags = common.fixture_tags,
)

swift_library(
    name = "swift_lib_with_resources",
    srcs = ["AppDelegate.swift"],
    data = [
        ":swift_structured_resources",
        "//test/testdata/resources:assets_ios",
        "//test/testdata/resources:localized_generic_resources",
        "//test/testdata/resources:localized_storyboards_ios",
        "//test/testdata/resources:localized_strings",
        "//test/testdata/resources:localized_xibs_ios",
        "//test/testdata/resources:nonlocalized.strings",
        "//test/testdata/resources:nonlocalized_resource.txt",
        "//test/testdata/resources:storyboard_ios.storyboard",
        "//test/testdata/resources:unversioned_datamodel",
        "//test/testdata/resources:versioned_datamodel",
        "//test/testdata/resources:view_ios.xib",
    ],
    module_name = "EasyToSearchForModuleName",
    tags = common.fixture_tags,
)

swift_library(
    name = "swift_lib_with_transitive_resources",
    srcs = ["Dummy.swift"],
    tags = common.fixture_tags,
    deps = [
        ":swift_lib_with_resources",
    ],
)

swift_library(
    name = "swift_lib_with_storyboard_a",
    srcs = ["AppDelegate.swift"],
    data = [
        "//test/testdata/resources:localized_storyboards_ios",
    ],
    tags = common.fixture_tags,
    deps = [
        ":swift_lib_with_storyboard_b",
    ],
)

swift_library(
    name = "swift_lib_with_storyboard_b",
    srcs = ["Dummy.swift"],
    data = [
        "//test/testdata/resources:storyboard_ios.storyboard",
    ],
    tags = common.fixture_tags,
)

swift_library(
    name = "swift_lib_with_asset_catalog_a",
    srcs = ["AppDelegate.swift"],
    data = [
        "//test/testdata/resources:assets_ios",
    ],
    tags = common.fixture_tags,
    deps = [
        ":swift_lib_with_asset_catalog_b",
    ],
)

swift_library(
    name = "swift_lib_with_asset_catalog_b",
    srcs = ["Dummy.swift"],
    data = [
        "//test/testdata/resources:assets2_ios",
    ],
    tags = common.fixture_tags,
)

swift_library(
    name = "swift_lib_with_storyboard_copy",
    srcs = ["Dummy.swift"],
    data = [
        "//test/testdata/resources:generate_storyboard_copy",
    ],
    tags = common.fixture_tags,
    deps = [":swift_lib_with_resources"],
)

genrule(
    name = "DummySwiftFile",
    outs = ["Dummy.swift"],
    cmd = "echo 'struct Dummy {}' > $@",
    tags = common.fixture_tags,
)

filegroup(
    name = "structured",
    srcs = glob(["structured/**"]),
)

filegroup(
    name = "swift_datamodel",
    srcs = glob(["core_data_models/swift_datamodel.xcdatamodeld/**"]),
)

filegroup(
    name = "objc_datamodel",
    srcs = glob(["core_data_models/objc_datamodel.xcdatamodeld/**"]),
)

filegroup(
    name = "no_code_generation_datamodel",
    srcs = glob(["core_data_models/no_code_generation_datamodel.xcdatamodeld/**"]),
)

filegroup(
    name = "unversioned_datamodel",
    srcs = glob(["unversioned_datamodel.xcdatamodel/**"]),
)

filegroup(
    name = "versioned_datamodel",
    srcs = glob(["versioned_datamodel.xcdatamodeld/**"]),
)

filegroup(
    name = "realitykit_assets",
    srcs = glob(["RealityKitContent.rkassets/**"]),
)

objc_library(
    name = "framework_resources_lib",
    data = [
        "framework_resources/nonlocalized.plist",
    ],
    tags = common.fixture_tags,
)

genrule(
    name = "generate_structured_image",
    srcs = [":sample.png"],
    outs = ["Images/foo.png"],
    cmd = "cp $(location :sample.png) $@",
    tags = common.fixture_tags,
)

apple_resource_group(
    name = "structured_image_resources",
    structured_resources = [":generate_structured_image"],
)

filegroup(
    name = "MacAppIcon.xcassets",
    srcs = glob(["MacAppIcon.xcassets/**"]),
)

filegroup(
    name = "TVBrandAssets.xcassets",
    srcs = glob(["TVBrandAssets.xcassets/**"]),
)

filegroup(
    name = "VisionAppIcon.xcassets",
    srcs = glob(["VisionAppIcon.xcassets/**"]),
)

filegroup(
    name = "WatchAppIcon.xcassets",
    srcs = glob(["WatchAppIcon.xcassets/**"]),
)

cc_binary(
    name = "cc_test_binary",
    srcs = ["main.cc"],
    tags = common.fixture_tags,
)

swift_library(
    name = "app_intent",
    srcs = ["app_intent.swift"],
    tags = common.fixture_tags,
)

swift_library(
    name = "widget_configuration_intent",
    srcs = ["widget_configuration_intent.swift"],
    module_name = "WidgetConfigurationIntent",
    tags = common.fixture_tags,
)

objc_library(
    name = "realitykit_codeless_content",
    data = [":realitykit_assets"],
    tags = common.fixture_tags,
)

swift_library(
    name = "realitykit_standalone_content",
    srcs = [
        "realitykit_content.swift",
        "realitykit_standalone_component.swift",
    ],
    aspect_hints = ["//apple/hints:realitykit_library_hint"],
    data = [":realitykit_assets"],
    module_name = "RealityKitContent",
    tags = common.fixture_tags,
)

apple_resource_hint(
    name = "dummy_library_hint",
    tags = common.fixture_tags,
)

objc_library(
    name = "library_with_two_apple_resource_hints",
    aspect_hints = [
        ":dummy_library_hint",
        "//apple/hints:realitykit_library_hint",
    ],
    tags = common.fixture_tags,
)
