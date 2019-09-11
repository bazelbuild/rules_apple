licenses(["notice"])

package(
    default_testonly = 1,
    default_visibility = ["//test/starlark_tests:__subpackages__"],
)

# This is a list of iOS targets to be used for Starlark unit tests. These may not build correctly
# since most of them do not have any source dependencies, so they are all tagged as manual and
# notap to avoid them being built/tested when testing the //test/...
# package.

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

ios_framework(
    name = "fmwk",
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
