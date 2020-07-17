load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

# Resource rules.

# This file exists to create a package under which to load the testing
# rules bzl files.

licenses(["notice"])

bzl_library(
    name = "apple_bundle_import",
    srcs = ["apple_bundle_import.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        "//apple:providers",
        "//apple:utils",
        "//apple/internal:resources",
        "@bazel_skylib//lib:partial",
    ],
)

bzl_library(
    name = "apple_core_ml_library",
    srcs = ["apple_core_ml_library.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        "//apple/internal:resource_actions",
        "@bazel_skylib//lib:dicts",
        "@bazel_skylib//lib:paths",
        "@build_bazel_apple_support//lib:apple_support",
    ],
)

bzl_library(
    name = "apple_resource_bundle",
    srcs = ["apple_resource_bundle.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        "//apple:providers",
        "//apple/internal:resources",
        "@bazel_skylib//lib:dicts",
        "@bazel_skylib//lib:partial",
        "@build_bazel_apple_support//lib:apple_support",
    ],
)

bzl_library(
    name = "apple_resource_group",
    srcs = ["apple_resource_group.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        "//apple:providers",
        "//apple/internal:resources",
        "@bazel_skylib//lib:dicts",
        "@bazel_skylib//lib:partial",
        "@build_bazel_apple_support//lib:apple_support",
    ],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]),
    visibility = [
        "//apple:__subpackages__",
    ],
)
