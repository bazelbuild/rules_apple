licenses(["notice"])

package(
    default_testonly = 1,
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
    additional_contents = {
        "//test/starlark_tests/resources:additional.txt": "Additional",
        "//test/starlark_tests/resources:all_nested": "Nested",
    },
    bundle_id = "com.google.example",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    resources = [
        "//test/starlark_tests/resources:example_filegroup",
        "//test/starlark_tests/resources:localization",
        "//test/starlark_tests/resources:resource_bundle",
    ],
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
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
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
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
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_extension(
    name = "ext",
    additional_contents = {
        "//test/starlark_tests/resources:additional.txt": "Additional",
        "//test/starlark_tests/resources:all_nested": "Nested",
    },
    bundle_id = "com.google.example.ext",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

# ---------------------------------------------------------------------------------------

macos_bundle(
    name = "bundle",
    additional_contents = {
        "//test/starlark_tests/resources:additional.txt": "Additional",
        "//test/starlark_tests/resources:all_nested": "Nested",
    },
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

# ---------------------------------------------------------------------------------------

macos_quick_look_plugin(
    name = "ql_plugin",
    additional_contents = {
        "//test/starlark_tests/resources:additional.txt": "Additional",
        "//test/starlark_tests/resources:all_nested": "Nested",
    },
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

# ---------------------------------------------------------------------------------------

macos_ui_test(
    name = "ui_test",
    additional_contents = {
        "//test/starlark_tests/resources:additional.txt": "Additional",
        "//test/starlark_tests/resources:all_nested": "Nested",
    },
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
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

macos_unit_test(
    name = "unit_test",
    additional_contents = {
        "//test/starlark_tests/resources:additional.txt": "Additional",
        "//test/starlark_tests/resources:all_nested": "Nested",
    },
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "10.10",
    tags = [
        "manual",
        "notap",
    ],
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)
