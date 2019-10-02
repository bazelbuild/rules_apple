licenses(["notice"])

package(
    default_testonly = 1,
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
    minimum_os_version = "4.0",
    tags = [
        "manual",
        "notap",
    ],
)

watchos_extension(
    name = "ext",
    bundle_id = "com.google.example.ext",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:WatchosExtensionInfo.plist",
    ],
    minimum_os_version = "4.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
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
        "//test/starlark_tests/resources:watchkit_ext_main_lib",
    ],
)

watchos_extension(
    name = "ext_multiple_infoplists",
    bundle_id = "com.google.example.ext",
    infoplists = [
        "//test/starlark_tests/resources:Another.plist",
        "//test/starlark_tests/resources:WatchosExtensionInfo.plist",
    ],
    minimum_os_version = "4.0",
    tags = [
        "manual",
        "notap",
    ],
)
