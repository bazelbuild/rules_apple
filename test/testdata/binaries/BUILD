load(
    "//apple:apple_binary.bzl",
    "apple_binary",
)
load(
    "//test/starlark_tests:common.bzl",
    "common",
)

package(
    default_visibility = ["//test:__subpackages__"],
)

licenses(["notice"])

apple_binary(
    name = "empty_tvos_dylib",
    binary_type = "dylib",
    minimum_os_version = common.min_os_tvos.baseline,
    platform_type = "tvos",
    deps = [":dummy_lib"],
)

cc_library(
    name = "dummy_lib",
)
