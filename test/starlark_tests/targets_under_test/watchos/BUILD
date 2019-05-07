licenses(["notice"])

package(
    default_visibility = ["//test/starlark_tests:__subpackages__"],
)

load(
    "//apple:watchos.bzl",
    "watchos_application",
    "watchos_extension",
)

watchos_application(
    name = "app",
    bundle_id = "com.google.example",
    extension = ":ext",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = "3.0",
    tags = [
        "manual",
        "notap",
    ],
)

watchos_extension(
    name = "ext",
    bundle_id = "com.google.example.ext",
    infoplists = [
        "//test/starlark_tests/resources:WatchosExtensionInfo.plist",
    ],
    minimum_os_version = "3.0",
    tags = [
        "manual",
        "notap",
    ],
)

watchos_extension(
    name = "ext_multiple_infoplists",
    bundle_id = "com.google.example.ext",
    infoplists = [
        "//test/starlark_tests/resources:Another.plist",
        "//test/starlark_tests/resources:WatchosExtensionInfo.plist",
    ],
    minimum_os_version = "3.0",
    tags = [
        "manual",
        "notap",
    ],
)
