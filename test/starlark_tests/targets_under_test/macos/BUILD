licenses(["notice"])

package(
    default_visibility = ["//test/starlark_tests:__subpackages__"],
)

load(
    "//apple:macos.bzl",
    "macos_application",
    "macos_bundle",
    "macos_extension",
    "macos_quick_look_plugin",
    "macos_ui_test",
    "macos_unit_test",
)

macos_application(
    name = "app",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    tags = [
        "manual",
        "notap",
    ],
)

macos_application(
    name = "app_multiple_infoplists",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Another.plist",
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    tags = [
        "manual",
        "notap",
    ],
)

# ---------------------------------------------------------------------------------------

macos_application(
    name = "app_with_ext",
    bundle_id = "com.google.example",
    extensions = [":ext"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    tags = [
        "manual",
        "notap",
    ],
)

macos_extension(
    name = "ext",
    bundle_id = "com.google.example.ext",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    tags = [
        "manual",
        "notap",
    ],
)

# ---------------------------------------------------------------------------------------

macos_bundle(
    name = "bundle",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    tags = [
        "manual",
        "notap",
    ],
)

# ---------------------------------------------------------------------------------------

macos_quick_look_plugin(
    name = "ql_plugin",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    tags = [
        "manual",
        "notap",
    ],
)

# ---------------------------------------------------------------------------------------

macos_ui_test(
    name = "ui_test",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    tags = [
        "manual",
        "notap",
    ],
    test_host = ":app",
)

# ---------------------------------------------------------------------------------------

macos_unit_test(
    name = "unit_test",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    tags = [
        "manual",
        "notap",
    ],
    test_host = ":app",
)
