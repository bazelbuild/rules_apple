load("@rules_cc//cc:defs.bzl", "objc_library")
load(
    "//apple:ios.bzl",
    "ios_application",
    "ios_extension",
    "ios_framework",
    "ios_imessage_application",
    "ios_sticker_pack_extension",
    "ios_ui_test",
    "ios_unit_test",
)

licenses(["notice"])

package(
    default_testonly = 1,
    default_visibility = ["//test/starlark_tests:__subpackages__"],
)

# This is a list of iOS targets to be used for Starlark unit tests. These may not build correctly
# since most of them do not have any source dependencies, so they are all tagged as manual and
# notap to avoid them being built/tested when testing the //test/...
# package.

ios_application(
    name = "app_minimal",
    bundle_id = "com.google.example",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "11.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app",
    app_icons = ["//test/starlark_tests/resources:app_icons_ios"],
    bundle_id = "com.google.example",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    launch_storyboard = "//test/starlark_tests/resources:launch_screen_ios.storyboard",
    minimum_os_version = "8.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    resources = [
        "//test/starlark_tests/resources:example_filegroup",
        "//test/starlark_tests/resources:localization",
        "//test/starlark_tests/resources:resource_bundle",
    ],
    settings_bundle = "//test/starlark_tests/resources:settings_bundle_ios",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:basic_bundle_lib",
        "//test/starlark_tests/resources:bundle_library_ios_lib",
        "//test/starlark_tests/resources:empty_strings_file_lib",
        "//test/starlark_tests/resources:ios_localized_assets_lib",
        "//test/starlark_tests/resources:ios_non_localized_assets_lib",
        "//test/starlark_tests/resources:nested_bundle_lib",
        "//test/starlark_tests/resources:objc_main_lib",
        "//test/starlark_tests/resources:sticker_pack_ios_lib",
    ],
)

ios_application(
    name = "app_multiple_infoplists",
    bundle_id = "com.google.example",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Another.plist",
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_launch_storyboard_as_xib",
    bundle_id = "com.google.example",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    launch_storyboard = "//test/starlark_tests/resources:launch_screen_ios.xib",
    minimum_os_version = "8.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_custom_executable_name",
    bundle_id = "com.google.example",
    bundle_name = "custom_bundle_name",
    executable_name = "app.exe",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_structured_resources_in_resources_folder",
    bundle_id = "com.google.example",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:structured_resources_in_resources_lib",
    ],
)

ios_application(
    name = "app_launch_images",
    app_icons = ["//test/starlark_tests/resources:app_icons_ios"],
    bundle_id = "com.google.example",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    launch_images = ["//test/starlark_tests/resources:launch_images_ios"],
    minimum_os_version = "8.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_library_scoped_localized_assets",
    bundle_id = "com.google.example",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:ios_localized_assets_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_duplicated_library_scoped_localized_assets",
    bundle_id = "com.google.example",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:apple_localized_assets_lib",
        "//test/starlark_tests/resources:ios_localized_assets_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_top_level_and_library_scoped_localized_assets",
    bundle_id = "com.google.example",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    strings = [
        "//test/starlark_tests/resources:localized_strings",
    ],
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:ios_localized_assets_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_launch_images_from_library",
    app_icons = ["//test/starlark_tests/resources:app_icons_ios"],
    bundle_id = "com.google.example",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:launch_images_ios_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_duplicated_library_scoped_launch_images",
    app_icons = ["//test/starlark_tests/resources:app_icons_ios"],
    bundle_id = "com.google.example",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:launch_images_ios_lib",
        "//test/starlark_tests/resources:launch_images_ios_lib_duplicated_target",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_top_level_and_library_scoped_launch_images",
    app_icons = ["//test/starlark_tests/resources:app_icons_ios"],
    bundle_id = "com.google.example",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    launch_images = ["//test/starlark_tests/resources:launch_images_ios"],
    minimum_os_version = "8.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:launch_images_ios_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

# ---------------------------------------------------------------------------------------

ios_application(
    name = "app_with_same_resource_names_as_framework",
    bundle_id = "com.google.example",
    families = ["iphone"],
    frameworks = [
        ":fmwk_with_duplicate_resource_names",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "11.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        ":app_structured_resources_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_framework(
    name = "fmwk_with_duplicate_resource_names",
    bundle_id = "com.google.example.framework",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        ":fmwk_structured_resources_lib",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

objc_library(
    name = "fmwk_structured_resources_lib",
    data = ["//test/starlark_tests/resources:structured_resources"],
)

objc_library(
    name = "app_structured_resources_lib",
    data = ["//test/starlark_tests/resources:structured_resources_duplicate"],
)

# ---------------------------------------------------------------------------------------

ios_application(
    name = "app_with_inner_and_outer_fmwk",
    bundle_id = "com.google.example",
    families = ["iphone"],
    frameworks = [
        ":fmwk_with_imported_fmwk",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "11.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_framework(
    name = "fmwk_with_imported_fmwk",
    bundle_id = "com.google.example.framework",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_lib_with_resources",
        "//test/testdata/frameworks:iOSImportedDynamicFramework",
    ],
)

ios_application(
    name = "app_with_inner_and_outer_static_fmwk",
    bundle_id = "com.google.example",
    families = ["iphone"],
    frameworks = [
        ":fmwk_with_imported_static_fmwk",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "11.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_framework(
    name = "fmwk_with_imported_static_fmwk",
    bundle_id = "com.google.example.framework",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_lib_with_resources",
        "//test/testdata/frameworks:iOSImportedStaticFramework",
    ],
)

# ---------------------------------------------------------------------------------------

ios_application(
    name = "app_with_8_0_min_version",
    bundle_id = "com.google.example",
    extensions = [":ext_with_9_0_min_version"],
    families = ["iphone"],
    frameworks = [":fmwk_8_0_minimum"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        ":fmwk_8_0_minimum_lib",
        ":min_version_main_lib",
    ],
)

ios_extension(
    name = "ext_with_9_0_min_version",
    bundle_id = "com.google.example.ext",
    families = [
        "iphone",
        "ipad",
    ],
    frameworks = [":fmwk_8_0_minimum"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        ":fmwk_8_0_minimum_lib",
        ":min_version_main_lib",
    ],
)

ios_framework(
    name = "fmwk_8_0_minimum",
    hdrs = ["//test/starlark_tests/resources:common.h"],
    bundle_id = "com.google.example.framework",
    extension_safe = 1,
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        ":fmwk_8_0_minimum_lib",
    ],
)

objc_library(
    name = "fmwk_8_0_minimum_lib",
    srcs = [
        "//test/starlark_tests/resources:shared.h",
        "//test/starlark_tests/resources:shared.m",
    ],
)

objc_library(
    name = "min_version_main_lib",
    srcs = [
        "//test/starlark_tests/resources:main.m",
    ],
    deps = [":fmwk_8_0_minimum_lib"],
)

# ---------------------------------------------------------------------------------------

ios_application(
    name = "app_with_ext_with_fmwk_provisioned",
    bundle_id = "com.google.example",
    extensions = [":ext_with_fmwk_provisioned"],
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

# ---------------------------------------------------------------------------------------

ios_application(
    name = "app_with_framework_and_resources",
    bundle_id = "com.google.example",
    families = ["iphone"],
    frameworks = [
        ":fmwk_with_resources",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "11.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_lib_with_resources",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_framework(
    name = "fmwk_with_resources",
    bundle_id = "com.google.example.framework",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    linkopts = ["-application_extension"],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_lib_with_resources",
    ],
)

ios_application(
    name = "app_with_framework_and_shared_resources",
    bundle_id = "com.google.example",
    families = ["iphone"],
    frameworks = [
        ":fmwk_with_resources",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "11.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        ":lib_with_structured_resources",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_multiple_refs_to_same_structured_resources",
    bundle_id = "com.google.example",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "11.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        ":app_structured_resources_lib",
        ":fmwk_structured_resources_lib",
        ":lib_with_structured_resources",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_multiple_resource_bundles_with_shared_resources",
    bundle_id = "com.google.example",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "11.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:bundle_library_apple_lib",
        "//test/starlark_tests/resources:bundle_library_ios_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

objc_library(
    name = "lib_with_structured_resources",
    data = [
        "//test/starlark_tests/resources:structured_resources",
    ],
)

# ---------------------------------------------------------------------------------------

ios_application(
    name = "app_with_9_0_minimum_and_8_0_fmwk",
    bundle_id = "com.google.example",
    families = [
        "iphone",
        "ipad",
    ],
    frameworks = [":fmwk_min_os_8_0"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:basic_bundle_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_8_0_minimum_and_9_0_fmwk",
    bundle_id = "com.google.example",
    families = [
        "iphone",
        "ipad",
    ],
    frameworks = [":fmwk_min_os_9_0"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:basic_bundle_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_fmwk_with_bundle_resources",
    bundle_id = "com.google.example",
    families = [
        "iphone",
        "ipad",
    ],
    frameworks = [":fmwk_min_os_9_0"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_framework(
    name = "fmwk_min_os_9_0",
    hdrs = ["//test/starlark_tests/resources:common.h"],
    bundle_id = "com.google.example.framework",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:basic_bundle_lib",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

ios_framework(
    name = "fmwk_min_os_8_0",
    hdrs = ["//test/starlark_tests/resources:common.h"],
    bundle_id = "com.google.example.framework",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:basic_bundle_lib",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

# ---------------------------------------------------------------------------------------

ios_application(
    name = "app_with_ext",
    bundle_id = "com.google.example",
    extensions = [":ext"],
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_ext_and_fmwk_provisioned",
    bundle_id = "com.google.example",
    extensions = [":ext_with_fmwk_provisioned"],
    families = [
        "iphone",
        "ipad",
    ],
    frameworks = [
        ":fmwk_with_provisioning",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_extension(
    name = "ext",
    bundle_id = "com.google.example.ext",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_extension(
    name = "ext_with_main",
    bundle_id = "com.google.example.ext",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    provides_main = True,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_extension(
    name = "ext_multiple_infoplists",
    bundle_id = "com.google.example.ext",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
        "//test/starlark_tests/resources:Another.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_extension(
    name = "ext_with_fmwk_provisioned",
    bundle_id = "com.google.example.ext",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    families = [
        "iphone",
        "ipad",
    ],
    frameworks = [
        ":fmwk_with_provisioning",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

# ---------------------------------------------------------------------------------------

ios_application(
    name = "app_with_fmwk",
    bundle_id = "com.google.example",
    families = [
        "iphone",
        "ipad",
    ],
    frameworks = [":fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:ios_non_localized_assets_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_two_fmwk_provisioned",
    bundle_id = "com.google.example",
    families = [
        "iphone",
        "ipad",
    ],
    frameworks = [
        ":fmwk_with_provisioning",
        ":second_fmwk_with_provisioning",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:ios_non_localized_assets_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_imported_fmwk",
    bundle_id = "com.google.example",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        ":dynamic_fmwk_depending_lib",
        "//test/starlark_tests/resources:ios_non_localized_assets_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_fmwk_with_fmwk_provisioned",
    bundle_id = "com.google.example",
    families = [
        "iphone",
        "ipad",
    ],
    frameworks = [":fmwk_with_fmwk_with_provisioning"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:ios_non_localized_assets_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_fmwk_importing_fmwk",
    bundle_id = "com.google.example",
    families = [
        "iphone",
        "ipad",
    ],
    frameworks = [":fmwk_with_provisioning_importing_fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:ios_non_localized_assets_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_fmwk_with_fmwk",
    bundle_id = "com.google.example",
    families = [
        "iphone",
        "ipad",
    ],
    frameworks = [":fmwk_with_fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:ios_non_localized_assets_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_framework(
    name = "fmwk_no_version",
    hdrs = ["//test/starlark_tests/resources:common.h"],
    bundle_id = "com.google.example.framework",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info-noversion.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:framework_resources_lib",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

ios_framework(
    name = "fmwk",
    hdrs = ["//test/starlark_tests/resources:common.h"],
    bundle_id = "com.google.example.framework",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:framework_resources_lib",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

ios_framework(
    name = "fmwk_dead_stripped",
    bundle_id = "com.google.example.framework",
    exported_symbols_lists = [
        "//test/starlark_tests/resources:ExportAnotherFunctionShared.exp",
    ],
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    linkopts = ["-dead_strip"],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:framework_resources_lib",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

ios_framework(
    name = "fmwk_dead_stripped_two_exported_symbol_lists",
    bundle_id = "com.google.example.framework",
    exported_symbols_lists = [
        "//test/starlark_tests/resources:ExportAnotherFunctionShared.exp",
        "//test/starlark_tests/resources:ExportDontCallMeShared.exp",
    ],
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    linkopts = ["-dead_strip"],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:framework_resources_lib",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

ios_framework(
    name = "fmwk_stripped",
    bundle_id = "com.google.example.framework",
    exported_symbols_lists = [
        "//test/starlark_tests/resources:ExportAnotherFunctionShared.exp",
    ],
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    linkopts = ["-x"],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:framework_resources_lib",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

ios_framework(
    name = "fmwk_stripped_two_exported_symbol_lists",
    bundle_id = "com.google.example.framework",
    exported_symbols_lists = [
        "//test/starlark_tests/resources:ExportAnotherFunctionShared.exp",
        "//test/starlark_tests/resources:ExportDontCallMeShared.exp",
    ],
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    linkopts = ["-x"],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:framework_resources_lib",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

ios_framework(
    name = "fmwk_with_provisioning",
    bundle_id = "com.google.example.framework",
    extension_safe = 1,
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:framework_resources_lib",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

ios_framework(
    name = "fmwk_with_provisioning_importing_fmwk",
    bundle_id = "com.google.example.framework",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        ":dynamic_fmwk_depending_lib",
        "//test/starlark_tests/resources:framework_resources_lib",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

ios_framework(
    name = "second_fmwk_with_provisioning",
    bundle_id = "com.google.example.frameworktoo",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:framework_resources_lib",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

ios_framework(
    name = "fmwk_with_fmwk",
    bundle_id = "com.google.example.frameworkception",
    families = [
        "iphone",
        "ipad",
    ],
    frameworks = [":fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
)

ios_framework(
    name = "fmwk_with_fmwk_with_provisioning",
    bundle_id = "com.google.example.frameworkception",
    families = [
        "iphone",
        "ipad",
    ],
    frameworks = [":fmwk_with_provisioning"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:framework_resources_lib",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

ios_framework(
    name = "fmwk_multiple_infoplists",
    bundle_id = "com.google.example.framework",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
        "//test/starlark_tests/resources:Another.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

# ---------------------------------------------------------------------------------------

objc_library(
    name = "dynamic_fmwk_depending_lib",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    deps = ["//test/testdata/frameworks:iOSImportedDynamicFramework"],
)

# ---------------------------------------------------------------------------------------

ios_imessage_application(
    name = "imessage_app",
    bundle_id = "com.google.example",
    extension = ":sticker_ext",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.0",
    tags = [
        "manual",
        "notap",
    ],
)

ios_sticker_pack_extension(
    name = "sticker_ext",
    bundle_id = "com.google.example.stickerext",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:StickerPackInfo.plist",
    ],
    minimum_os_version = "10.0",
    sticker_assets = [],
    tags = [
        "manual",
        "notap",
    ],
)

# ---------------------------------------------------------------------------------------

ios_ui_test(
    name = "ui_test",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

ios_ui_test(
    name = "ui_test_custom_bundle_id",
    bundle_id = "com.google.example.ui_test",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

ios_ui_test(
    name = "ui_test_multiple_infoplists",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
        "//test/starlark_tests/resources:Another.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

ios_ui_test(
    name = "ui_test_with_fmwk",
    families = [
        "iphone",
        "ipad",
    ],
    frameworks = [
        ":fmwk",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

# ---------------------------------------------------------------------------------------

ios_unit_test(
    name = "unit_test",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    resources = [
        "//test/starlark_tests/resources:example_filegroup",
        "//test/starlark_tests/resources:resource_bundle",
    ],
    tags = [
        "manual",
        "notap",
    ],
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

ios_unit_test(
    name = "unit_test_custom_bundle_id",
    bundle_id = "com.google.example.unit_test",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

ios_unit_test(
    name = "unit_test_multiple_infoplists",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
        "//test/starlark_tests/resources:Another.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

ios_unit_test(
    name = "unit_test_no_host",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

ios_unit_test(
    name = "unit_test_with_fmwk",
    families = [
        "iphone",
        "ipad",
    ],
    frameworks = [
        ":fmwk",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

ios_unit_test(
    name = "unit_test_with_imported_fmwk",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        ":dynamic_fmwk_depending_lib",
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

ios_unit_test(
    name = "unit_test_with_host_importing_same_fmwk",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    test_host = ":app_with_imported_fmwk",
    deps = [
        ":dynamic_fmwk_depending_lib",
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

# ---------------------------------------------------------------------------------------
# Targets for the app/test resource deduping test.

objc_library(
    name = "shared_lib",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    data = [
        "//test/starlark_tests/resources:basic_bundle",
    ],
    tags = [
        "manual",
        "notap",
    ],
)

objc_library(
    name = "app_lib",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    data = [
        "//test/starlark_tests/resources:empty.strings",
    ],
    tags = [
        "manual",
        "notap",
    ],
    deps = [":shared_lib"],
)

objc_library(
    name = "test_lib",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    data = [
        "//test/starlark_tests/resources:nonlocalized.strings",
    ],
    tags = [
        "manual",
        "notap",
    ],
    deps = [":app_lib"],
)

objc_library(
    name = "main_lib",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        ":app_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_framework(
    name = "dedupe_test_fmwk",
    bundle_id = "com.fmwk",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        ":shared_lib",
    ],
)

ios_application(
    name = "dedupe_test_app",
    bundle_id = "com.app",
    families = [
        "iphone",
        "ipad",
    ],
    frameworks = [
        ":dedupe_test_fmwk",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        ":main_lib",
    ],
)

ios_unit_test(
    name = "dedupe_test_test",
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
    test_host = ":dedupe_test_app",
    deps = [
        ":test_lib",
    ],
)
