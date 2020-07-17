load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

# Aspects.

# This file exists to create a package under which to load the aspect
# bzl files.

licenses(["notice"])

bzl_library(
    name = "framework_import_aspect",
    srcs = ["framework_import_aspect.bzl"],
    visibility = [
        "//apple/internal:__pkg__",
    ],
    deps = [
        "//apple/internal:apple_framework_import",
    ],
)

bzl_library(
    name = "resource_aspect",
    srcs = ["resource_aspect.bzl"],
    visibility = [
        "//apple/internal:__pkg__",
    ],
    deps = [
        "//apple:providers",
        "//apple/internal:resources",
        "@build_bazel_apple_support//lib:apple_support",
        "@build_bazel_rules_swift//swift",
    ],
)

bzl_library(
    name = "swift_static_framework_aspect",
    srcs = ["swift_static_framework_aspect.bzl"],
    visibility = [
        "//apple/internal:__pkg__",
    ],
    deps = [
        "@build_bazel_rules_swift//swift",
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
