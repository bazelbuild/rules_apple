load(
    "//apple:ios.bzl",
    "ios_app_clip",
    "ios_application",
    "ios_dynamic_framework",
    "ios_extension",
    "ios_framework",
    "ios_imessage_application",
    "ios_static_framework",
    "ios_sticker_pack_extension",
    "ios_ui_test",
    "ios_unit_test",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "swift_library",
)
load(
    "//apple:apple.bzl",
    "apple_dynamic_framework_import",
)
load("//test/testdata/rules:substitution.bzl", "substitution")
load("//test/starlark_tests:common.bzl", "FIXTURE_TAGS")
load(
    "//test/testdata/fmwk:generate_framework.bzl",
    "generate_import_framework",
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
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_minimal_with_deployment_version",
    bundle_id = "com.google.example",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_deployment_os_version = "14.0",
    minimum_os_version = "11.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:structured_resources_in_resources_lib",
    ],
)

ios_application(
    name = "app_with_processed_resources_in_structured_resources",
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
        "//test/starlark_tests/resources:processed_resources_in_structured_resources_lib",
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:launch_images_ios_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_alternate_icons",
    alternate_icons = ["//test/starlark_tests/resources:alternate_icons_ios"],
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
    deps = [
        ":fmwk_structured_resources_lib",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

objc_library(
    name = "fmwk_structured_resources_lib",
    data = ["//test/starlark_tests/resources:structured_resources"],
    tags = FIXTURE_TAGS,
)

objc_library(
    name = "app_structured_resources_lib",
    data = ["//test/starlark_tests/resources:structured_resources_duplicate"],
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_lib_with_resources",
        "//test/testdata/fmwk:iOSImportedDynamicFramework",
    ],
)

ios_application(
    name = "app_with_imported_dynamic_fmwk_with_bitcode",
    bundle_id = "com.google.example",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
        "//test/testdata/fmwk:iOSImportedDynamicFrameworkWithBitcode",
    ],
)

ios_application(
    name = "app_with_imported_dynamic_fmwk_with_dsym",
    bundle_id = "com.google.example",
    families = [
        "iphone",
        "ipad",
    ],
    include_symbols_in_bundle = True,
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
        "//test/testdata/fmwk:iOSImportedDynamicFrameworkWithDebugInfo",
        "//test/testdata/fmwk:iOSImportedDynamicFrameworkWithDsym",
    ],
)

ios_application(
    name = "app_with_swift_dep",
    bundle_id = "com.google.example",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "9.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:swift_main_lib",
    ],
)

ios_static_framework(
    name = "swift_static_framework",
    bundle_name = "swift_framework_lib",
    minimum_os_version = "9.0",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:swift_framework_lib",
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_lib_with_resources",
        "//test/testdata/fmwk:iOSImportedStaticFramework",
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
)

objc_library(
    name = "min_version_main_lib",
    srcs = [
        "//test/starlark_tests/resources:main.m",
    ],
    tags = FIXTURE_TAGS,
    deps = [":fmwk_8_0_minimum_lib"],
)

# ---------------------------------------------------------------------------------------

ios_application(
    name = "app_with_app_clip",
    app_clips = [":app_clip"],
    bundle_id = "com.google.example",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "14.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_app_clip(
    name = "app_clip",
    bundle_id = "com.google.example.clip",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "14.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:bundle_library_apple_lib",
        "//test/starlark_tests/resources:bundle_library_ios_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_resource_bundle_with_structured_resource_group",
    bundle_id = "com.google.example",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "11.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    resources = ["//test/starlark_tests/resources:resource_bundle_with_structured_resource_group"],
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_resource_bundle_with_bundle_id",
    bundle_id = "com.google.example",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "11.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    resources = ["//test/starlark_tests/resources:resource_bundle_with_bundle_id"],
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_resource_group_with_resource_bundle",
    bundle_id = "com.google.example",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "11.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    resources = ["//test/starlark_tests/resources:resources_with_resource_bundle"],
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

objc_library(
    name = "lib_with_structured_resources",
    data = [
        "//test/starlark_tests/resources:structured_resources",
    ],
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_ext_and_fmwk_and_symbols_in_bundle",
    bundle_id = "com.google.example",
    extensions = [":ext_with_fmwk_provisioned"],
    families = [
        "iphone",
        "ipad",
    ],
    frameworks = [
        ":fmwk_with_provisioning",
    ],
    include_symbols_in_bundle = True,
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = "8.0",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
        "//test/testdata/fmwk:iOSImportedDynamicFrameworkWithDebugInfo",
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

# ---------------------------------------------------------------------------------------

substitution(
    name = "resource_rules",
    src = "//test/starlark_tests/resources:ResourceRules.plist",
    tags = FIXTURE_TAGS,
    var_name = "RULES",
)

ios_application(
    name = "app_with_codesignopts",
    bundle_id = "com.google.example",
    codesign_inputs = [":resource_rules"],
    codesignopts = [
        "--digest-algorithm=sha1",
        "--digest-algorithm=sha384",
        "--resource-rules=$(RULES)",
    ],
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = FIXTURE_TAGS,
    toolchains = [":resource_rules"],
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

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
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:ios_non_localized_assets_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_bundle_only_fmwks",
    bundle_id = "com.google.example",
    families = [
        "iphone",
        "ipad",
    ],
    frameworks = [":bundle_only_fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = FIXTURE_TAGS,
    deps = [
        ":bundle_only_imported_fmwk",
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:ios_non_localized_assets_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_fmwk_with_multiple_objc_library_and_swift_library_deps",
    bundle_id = "com.google.example",
    families = [
        "iphone",
        "ipad",
    ],
    frameworks = [":fmwk_with_multiple_objc_library_and_swift_library_deps"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = FIXTURE_TAGS,
    deps = [
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
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:framework_resources_lib",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

ios_framework(
    name = "fmwk_with_multiple_objc_library_and_swift_library_deps",
    bundle_id = "com.google.example.framework",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
        "//test/starlark_tests/resources:swift_shared_lib",
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
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:framework_resources_lib",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

ios_framework(
    name = "bundle_only_fmwk",
    hdrs = ["//test/starlark_tests/resources:common.h"],
    bundle_id = "com.google.example.framework",
    bundle_only = True,
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

# ---------------------------------------------------------------------------------------

objc_library(
    name = "dynamic_fmwk_depending_lib",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    tags = FIXTURE_TAGS,
    deps = ["//test/testdata/fmwk:iOSImportedDynamicFramework"],
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
)

objc_library(
    name = "app_lib",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    data = [
        "//test/starlark_tests/resources:empty.strings",
    ],
    tags = FIXTURE_TAGS,
    deps = [":shared_lib"],
)

objc_library(
    name = "test_lib",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    data = [
        "//test/starlark_tests/resources:nonlocalized.strings",
    ],
    tags = FIXTURE_TAGS,
    deps = [":app_lib"],
)

objc_library(
    name = "main_lib",
    srcs = ["@bazel_tools//tools/objc:dummy.c"],
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
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
    tags = FIXTURE_TAGS,
    deps = [
        ":main_lib",
    ],
)

ios_unit_test(
    name = "dedupe_test_test",
    minimum_os_version = "8.0",
    tags = FIXTURE_TAGS,
    test_host = ":dedupe_test_app",
    deps = [
        ":test_lib",
    ],
)

# ---------------------------------------------------------------------------------------
# Targets for iOS dynamic framework tests.

swift_library(
    name = "basic_framework_lib",
    srcs = [
        "//test/starlark_tests/resources:BasicFramework.swift",
    ],
    features = ["swift.no_generated_module_map"],
    generates_header = True,
    module_name = "BasicFramework",
    tags = FIXTURE_TAGS,
    visibility = ["//visibility:public"],
)

ios_dynamic_framework(
    name = "basic_framework",
    bundle_id = "com.google.example.framework",
    bundle_name = "BasicFramework",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = FIXTURE_TAGS,
    deps = [
        ":basic_framework_lib",
    ],
)

swift_library(
    name = "basic_framework_with_direct_dependency_lib",
    srcs = [
        "//test/starlark_tests/resources:DirectDependencyTest.swift",
    ],
    features = ["swift.no_generated_module_map"],
    generates_header = True,
    module_name = "DirectDependencyTest",
    tags = FIXTURE_TAGS,
    visibility = ["//visibility:public"],
    deps = [
        ":basic_framework_lib",
    ],
)

ios_dynamic_framework(
    name = "basic_framework_with_direct_dependency",
    bundle_id = "com.google.example.framework",
    bundle_name = "DirectDependencyTest",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = FIXTURE_TAGS,
    deps = [
        ":basic_framework_with_direct_dependency_lib",
    ],
)

swift_library(
    name = "basic_framework_with_transitive_dependency_lib",
    srcs = [
        "//test/starlark_tests/resources:TransitiveDependencyTest.swift",
    ],
    features = ["swift.no_generated_module_map"],
    generates_header = True,
    module_name = "TransitiveDependencyTest",
    tags = FIXTURE_TAGS,
    visibility = ["//visibility:public"],
    deps = [
        ":basic_framework_lib",
        ":basic_framework_with_direct_dependency_lib",
    ],
)

ios_dynamic_framework(
    name = "basic_framework_with_transitive_dependency",
    bundle_id = "com.google.example.framework",
    bundle_name = "TransitiveDependencyTest",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = FIXTURE_TAGS,
    deps = [
        ":basic_framework_with_transitive_dependency_lib",
    ],
)

swift_library(
    name = "basic_framework_with_dynamic_framework_dependency_lib",
    srcs = [
        "//test/starlark_tests/resources:DirectDependencyTest.swift",
    ],
    features = ["swift.no_generated_module_map"],
    module_name = "DirectDependencyWithDynamicFrameworkTest",
    tags = FIXTURE_TAGS,
    visibility = ["//visibility:public"],
    deps = [
        ":basic_framework",
    ],
)

ios_dynamic_framework(
    name = "basic_framework_with_dynamic_framework_dependency",
    bundle_id = "com.google.example.framework",
    bundle_name = "DirectDependencyWithDynamicFrameworkTest",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = FIXTURE_TAGS,
    deps = [
        ":basic_framework_with_dynamic_framework_dependency_lib",
    ],
)

swift_library(
    name = "basic_framework_with_transitive_dependency_with_dynamic_frameworks_lib",
    srcs = [
        "//test/starlark_tests/resources:TransitiveDependencyTest.swift",
    ],
    features = ["swift.no_generated_module_map"],
    module_name = "TransitiveDependencyWithDynamicFrameworksTest",
    tags = FIXTURE_TAGS,
    visibility = ["//visibility:public"],
    deps = [
        ":basic_framework",
        ":basic_framework_with_direct_dependency",
    ],
)

ios_dynamic_framework(
    name = "basic_framework_with_transitive_dependency_with_dynamic_frameworks",
    bundle_id = "com.google.example.framework",
    bundle_name = "TransitiveDependencyWithDynamicFrameworksTest",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = FIXTURE_TAGS,
    deps = [
        ":basic_framework_with_transitive_dependency_with_dynamic_frameworks_lib",
    ],
)

ios_dynamic_framework(
    name = "dynamic_framework_with_resources",
    bundle_id = "com.google.example.framework",
    bundle_name = "swift_lib_with_resources",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    linkopts = ["-application_extension"],
    minimum_os_version = "8.0",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:swift_lib_with_resources",
    ],
)

ios_application(
    name = "app_with_dynamic_framework_and_resources",
    bundle_id = "com.google.example",
    families = ["iphone"],
    frameworks = [
        ":dynamic_framework_with_resources",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "11.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
        "//test/starlark_tests/resources:swift_lib_with_resources",
    ],
)

ios_dynamic_framework(
    name = "swift_common_lib_framework",
    bundle_id = "com.google.example.framework",
    bundle_name = "swift_common_lib",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = FIXTURE_TAGS,
    deps = ["//test/starlark_tests/resources:swift_common_lib"],
)

ios_dynamic_framework(
    name = "swift_shared_lib_framework",
    bundle_id = "com.google.example.framework",
    bundle_name = "swift_shared_lib",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:swift_shared_lib",
    ],
)

ios_dynamic_framework(
    name = "swift_transitive_lib_framework",
    bundle_id = "com.google.example.framework",
    bundle_name = "swift_transitive_lib",
    families = [
        "iphone",
        "ipad",
    ],
    frameworks = [":swift_shared_lib_framework"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = FIXTURE_TAGS,
    deps = ["//test/starlark_tests/resources:swift_transitive_lib"],
)

ios_application(
    name = "app_with_dynamic_framework_with_dynamic_framework",
    bundle_id = "com.google.example",
    families = [
        "iphone",
        "ipad",
    ],
    frameworks = [":swift_transitive_lib_framework"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:ios_non_localized_assets_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_dynamic_framework(
    name = "dynamic_fmwk_with_multiple_dependencies",
    bundle_id = "com.google.example.framework",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = FIXTURE_TAGS,
    deps = [
        ":basic_framework_lib",
        ":basic_framework_with_direct_dependency_lib",
    ],
)

ios_dynamic_framework(
    name = "dynamic_fmwk_with_objc_library",
    bundle_id = "com.google.example.framework",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_lib_with_resources",
    ],
)

ios_static_framework(
    name = "objc_static_framework",
    hdrs = [
        "//test/starlark_tests/resources:common.h",
    ],
    bundle_name = "objc_static_framework",
    minimum_os_version = "9.0",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_common_lib",
    ],
)

ios_static_framework(
    name = "objc_static_framework_without_modulemap",
    bundle_name = "objc_static_framework_without_modulemap",
    minimum_os_version = "9.0",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_common_lib",
    ],
)

ios_static_framework(
    name = "objc_static_framework_with_sdk_dylibs_dep",
    bundle_name = "objc_static_framework_with_sdk_dylibs_dep",
    minimum_os_version = "9.0",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_lib_with_sdk_dylibs",
    ],
)

ios_static_framework(
    name = "objc_static_framework_with_sdk_fmwks_dep",
    bundle_name = "objc_static_framework_with_sdk_fmwks_dep",
    minimum_os_version = "9.0",
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_lib_with_sdk_fmwks",
    ],
)

swift_library(
    name = "basic_framework_with_dynamic_framework_import_lib",
    srcs = [
        "//test/starlark_tests/resources:BasicFramework.swift",
    ],
    features = ["swift.no_generated_module_map"],
    module_name = "DynamicFrameworkImportTest",
    tags = FIXTURE_TAGS,
    visibility = ["//visibility:public"],
    deps = [
        "//test/testdata/fmwk:iOSImportedDynamicFramework",
    ],
)

ios_dynamic_framework(
    name = "basic_framework_with_dynamic_framework_import",
    bundle_id = "com.google.example.framework",
    bundle_name = "DynamicFrameworkImportTest",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = FIXTURE_TAGS,
    deps = [
        ":basic_framework_with_dynamic_framework_import_lib",
    ],
)

swift_library(
    name = "basic_framework_with_static_framework_import_lib",
    srcs = [
        "//test/starlark_tests/resources:BasicFramework.swift",
    ],
    features = ["swift.no_generated_module_map"],
    module_name = "StaticFrameworkImportTest",
    tags = FIXTURE_TAGS,
    visibility = ["//visibility:public"],
    deps = [
        "//test/testdata/fmwk:iOSImportedStaticFramework",
    ],
)

ios_dynamic_framework(
    name = "basic_framework_with_static_framework_import",
    bundle_id = "com.google.example.framework",
    bundle_name = "StaticFrameworkImportTest",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = FIXTURE_TAGS,
    deps = [
        ":basic_framework_with_static_framework_import_lib",
    ],
)

# ---------------------------------------------------------------------------------------
# Targets for iOS static framework tests.

ios_static_framework(
    name = "static_fmwk_with_swift_and_avoid_deps",
    avoid_deps = [":SwiftFmwkLowerLib"],
    bundle_name = "SwiftFmwkUpperLib",
    minimum_os_version = "8.0",
    tags = FIXTURE_TAGS,
    deps = [":SwiftFmwkUpperLib"],
)

ios_static_framework(
    name = "static_framework_with_generated_header",
    bundle_name = "SwiftFmwkWithGenHeader",
    minimum_os_version = "8.0",
    tags = FIXTURE_TAGS,
    deps = [":SwiftFmwkWithGenHeader"],
)

genrule(
    name = "dummy_swift_src",
    outs = ["Dummy.swift"],
    cmd = "echo 'public struct Dummy {}' > $@",
)

swift_library(
    name = "SwiftFmwkUpperLib",
    srcs = ["Dummy.swift"],
    module_name = "SwiftFmwkUpperLib",
    tags = FIXTURE_TAGS,
    deps = [":SwiftFmwkLowerLib"],
)

swift_library(
    name = "SwiftFmwkLowerLib",
    srcs = ["Dummy.swift"],
    module_name = "SwiftFmwkLowerLib",
    tags = FIXTURE_TAGS,
    deps = [":SwiftFmwkLowestLib"],
)

swift_library(
    name = "SwiftFmwkLowestLib",
    srcs = ["Dummy.swift"],
    module_name = "SwiftFmwkLowestLib",
    tags = FIXTURE_TAGS,
)

swift_library(
    name = "SwiftFmwkWithGenHeader",
    srcs = ["Dummy.swift"],
    generates_header = True,
    module_name = "SwiftFmwkWithGenHeader",
    tags = FIXTURE_TAGS,
)

apple_dynamic_framework_import(
    name = "bundle_only_imported_fmwk",
    bundle_only = True,
    framework_imports = [":generated_ios_dynamic_fmwk"],
    tags = FIXTURE_TAGS,
)

generate_import_framework(
    name = "generated_ios_dynamic_fmwk",
    archs = ["x86_64"],
    libtype = "dynamic",
    minimum_os_version = "8.0",
    sdk = "iphonesimulator",
    tags = FIXTURE_TAGS,
)

# ---------------------------------------------------------------------------------------

ios_application(
    name = "app_with_objc_library_dep_with_ios_framework_runtime_dep",
    bundle_id = "com.google.example",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "11.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = FIXTURE_TAGS,
    deps = [
        ":objc_lib_with_runtime_dep_fmwk",
    ],
)

ios_application(
    name = "app_with_objc_lib_dep_with_inner_lib_with_runtime_dep_fmwk",
    bundle_id = "com.google.example",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "11.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = FIXTURE_TAGS,
    deps = [
        ":objc_lib_with_inner_lib_with_runtime_dep_fmwk",
    ],
)

ios_application(
    name = "app_with_load_and_runtime_framework_dep",
    bundle_id = "com.google.example",
    families = ["iphone"],
    frameworks = [":fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "11.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = FIXTURE_TAGS,
    deps = [
        ":objc_lib_with_runtime_dep_fmwk",
    ],
)

objc_library(
    name = "objc_lib_with_inner_lib_with_runtime_dep_fmwk",
    srcs = ["//test/starlark_tests/resources:main.m"],
    runtime_deps = [":fmwk_with_fmwk"],
    deps = [":objc_lib_with_runtime_dep_fmwk"],
)

objc_library(
    name = "objc_lib_with_runtime_dep_fmwk",
    srcs = ["//test/starlark_tests/resources:main.m"],
    runtime_deps = [":fmwk_8_0_minimum"],
)

# ---------------------------------------------------------------------------------------
# Targets for importing XCFramework tests.

ios_application(
    name = "app_with_imported_dynamic_xcfmwk",
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
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
        "//test/starlark_tests/resources:swift_lib_importing_imported_dynamic_xcfw",
    ],
)

ios_application(
    name = "app_with_imported_dynamic_xcfmwk_with_lib_ids",
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
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
        "//test/starlark_tests/resources:swift_lib_importing_imported_dynamic_xcfw",
    ],
)

ios_application(
    name = "app_with_imported_static_xcfmwk",
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
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_lib_importing_imported_static_xcfw",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_imported_static_xcfmwk_with_lib_ids",
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
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_lib_importing_imported_static_xcfw",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_with_imported_xcfmwk_bundling_static_fmwks",
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
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
        "//test/starlark_tests/resources:swift_lib_importing_imported_xcfw_bundling_static_fmwks",
    ],
)

ios_application(
    name = "app_with_imported_static_xcfmwk_with_module_map",
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
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
        "//test/starlark_tests/resources:swift_lib_importing_imported_static_xcfw",
    ],
)
