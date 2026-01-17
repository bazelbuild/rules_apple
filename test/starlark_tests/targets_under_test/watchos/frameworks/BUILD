load("//apple:watchos.bzl", "watchos_framework")
load(
    "//test/starlark_tests:common.bzl",
    "common",
)

licenses(["notice"])

package(
    default_testonly = True,
    default_visibility = ["//test/starlark_tests:__subpackages__"],
)

watchos_framework(
    name = "fmwk",
    bundle_id = "com.google.example.framework",
    extension_safe = True,
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
        "//test/starlark_tests/resources:Another.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib_with_transitive_resources",
    ],
)

watchos_framework(
    name = "fmwk_with_no_version",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Info-noversion.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)
