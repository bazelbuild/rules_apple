# Experimental resource propagation logic.

# This file exists to create a package under which to load the experimental
# resource propagation logic bzl files.

licenses(["notice"])

load(
    "@build_bazel_rules_apple//apple/internal:environment_plist.bzl",
    "environment_plist",
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]) + [
        "//apple/internal/aspects:for_bazel_tests",
        "//apple/internal/partials:for_bazel_tests",
        "//apple/internal/resource_actions:for_bazel_tests",
        "//apple/internal/resource_rules:for_bazel_tests",
        "//apple/internal/templates:for_bazel_tests",
        "//apple/internal/testing:for_bazel_tests",
        "//apple/internal/utils:for_bazel_tests",
    ],
    visibility = [
        "//apple:__subpackages__",
    ],
)

environment_plist(
    name = "environment_plist_ios",
    platform_type = "ios",
    visibility = [
        "//visibility:public",
    ],
)

environment_plist(
    name = "environment_plist_macos",
    platform_type = "macos",
    visibility = [
        "//visibility:public",
    ],
)

environment_plist(
    name = "environment_plist_watchos",
    platform_type = "watchos",
    visibility = [
        "//visibility:public",
    ],
)

environment_plist(
    name = "environment_plist_tvos",
    platform_type = "tvos",
    visibility = [
        "//visibility:public",
    ],
)
