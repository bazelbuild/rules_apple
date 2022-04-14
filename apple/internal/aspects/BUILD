load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

# Aspects.

# This file exists to create a package under which to load the aspect
# bzl files.

licenses(["notice"])

bzl_library(
    name = "framework_provider_aspect",
    srcs = ["framework_provider_aspect.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        "//apple:providers",
        "//apple/internal/providers:embeddable_info",
    ],
)

bzl_library(
    name = "resource_aspect",
    srcs = ["resource_aspect.bzl"],
    visibility = [
        "//apple/internal:__pkg__",
        "//apple/internal/resource_rules:__pkg__",
    ],
    deps = [
        "//apple:providers",
        "//apple/internal:apple_toolchains",
        "//apple/internal:platform_support",
        "//apple/internal:resources",
        "//apple/internal:swift_support",
        "@bazel_skylib//lib:dicts",
        "@bazel_skylib//lib:partial",
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
        "//apple/internal:swift_info_support",
        "@build_bazel_rules_swift//swift",
    ],
)

bzl_library(
    name = "swift_usage_aspect",
    srcs = ["swift_usage_aspect.bzl"],
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
