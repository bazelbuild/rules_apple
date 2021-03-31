load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

# Utils.

# This file exists to create a package under which to load the utility
# bzl files.

licenses(["notice"])

bzl_library(
    name = "bundle_paths",
    srcs = ["bundle_paths.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        "@bazel_skylib//lib:paths",
    ],
)

bzl_library(
    name = "defines",
    srcs = ["defines.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
)

bzl_library(
    name = "xctoolrunner",
    srcs = ["xctoolrunner.bzl"],
    visibility = [
        "//apple:__subpackages__",
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
