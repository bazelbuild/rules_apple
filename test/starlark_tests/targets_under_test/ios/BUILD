licenses(["notice"])

package(
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
    bundle_id = "com.google.example",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
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
)

ios_extension(
    name = "ext",
    bundle_id = "com.google.example.ext",
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
    tags = [
        "manual",
        "notap",
    ],
    test_host = ":app",
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
)
