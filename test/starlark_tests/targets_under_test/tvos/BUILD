licenses(["notice"])

package(
    default_visibility = ["//test/starlark_tests:__subpackages__"],
)

load(
    "//apple:tvos.bzl",
    "tvos_application",
    "tvos_extension",
    "tvos_framework",
    "tvos_ui_test",
    "tvos_unit_test",
)

tvos_application(
    name = "app",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
)

tvos_application(
    name = "app_multiple_infoplists",
    bundle_id = "com.google.example",
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

tvos_application(
    name = "app_with_ext",
    bundle_id = "com.google.example",
    extensions = [":ext"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
)

tvos_extension(
    name = "ext",
    bundle_id = "com.google.example.ext",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
)

# ---------------------------------------------------------------------------------------

tvos_application(
    name = "app_with_fmwk",
    bundle_id = "com.google.example",
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

tvos_framework(
    name = "fmwk",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "8.0",
    tags = [
        "manual",
        "notap",
    ],
)

# ---------------------------------------------------------------------------------------

tvos_ui_test(
    name = "ui_test",
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

# ---------------------------------------------------------------------------------------

tvos_ui_test(
    name = "unit_test",
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

tvos_unit_test(
    name = "unit_test_no_host",
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
