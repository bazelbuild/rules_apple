load(
    "//apple:apple_binary.bzl",
    "apple_binary",
)

package(
    default_visibility = ["//test:__subpackages__"],
)

licenses(["notice"])

apple_binary(
    name = "empty_tvos_dylib",
    binary_type = "dylib",
    minimum_os_version = "11.0",
    platform_type = "tvos",
    deps = [":dummy_lib"],
)

cc_library(
    name = "dummy_lib",
)
