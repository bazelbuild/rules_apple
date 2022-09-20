load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

bzl_library(
    name = "test_rules",
    srcs = glob(
        include = ["*.bzl"],
    ),
    visibility = [
        "//test:__subpackages__",
    ],
    deps = [
        "//apple:providers",
        "//apple/build_settings:attrs",
        "//apple/internal:apple_product_type",
        "@bazel_skylib//lib:dicts",
        "@bazel_skylib//lib:new_sets",
        "@bazel_skylib//lib:paths",
        "@bazel_skylib//lib:unittest",
    ],
)
