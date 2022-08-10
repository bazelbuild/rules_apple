load(
    "//apple:apple_static_library.bzl",
    "apple_static_library",
)
load(
    "//test/starlark_tests:common.bzl",
    "FIXTURE_TAGS",
)

licenses(["notice"])

package(
    default_testonly = 1,
    default_visibility = ["//test/starlark_tests:__subpackages__"],
)

objc_library(
    name = "main_lib",
    srcs = ["@bazel_tools//tools/objc:objc_dummy.mm"],
    tags = FIXTURE_TAGS,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

apple_static_library(
    name = "example_library_os8",
    minimum_os_version = "8.0",
    platform_type = "ios",
    tags = FIXTURE_TAGS,
    deps = [":main_lib"],
)

apple_static_library(
    name = "example_library_os14",
    minimum_os_version = "14.0",
    platform_type = "ios",
    tags = FIXTURE_TAGS,
    deps = [":main_lib"],
)

apple_static_library(
    name = "example_watch_library_os8",
    minimum_os_version = "8.0",
    platform_type = "watchos",
    tags = FIXTURE_TAGS,
    deps = [":main_lib"],
)

apple_static_library(
    name = "example_library_with_avoid_deps",
    avoid_deps = ["//test/starlark_tests/targets_under_test/apple:StaticFmwkLowerLib"],
    minimum_os_version = "12.0",
    platform_type = "ios",
    tags = FIXTURE_TAGS,
    deps = ["//test/starlark_tests/targets_under_test/apple:StaticFmwkUpperLib"],
)

apple_static_library(
    name = "example_library_with_cc_avoid_deps",
    avoid_deps = ["//test/starlark_tests/targets_under_test/apple:StaticFmwkCcLowerLib"],
    minimum_os_version = "12.0",
    platform_type = "ios",
    tags = FIXTURE_TAGS,
    deps = ["//test/starlark_tests/targets_under_test/apple:StaticFmwkCcUpperLib"],
)
