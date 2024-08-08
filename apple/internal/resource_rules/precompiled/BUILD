load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

licenses(["notice"])

bzl_library(
    name = "apple_precompiled_resource_bundle",
    srcs = ["apple_resource_bundle.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        "//apple/internal:providers",
    ],
)
