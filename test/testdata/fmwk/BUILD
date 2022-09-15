load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

# Public only because these are used by the integration tests from generated
# workspaces. Please no not depend on them as they can change at any time.
package(default_visibility = ["//visibility:public"])

licenses(["notice"])

bzl_library(
    name = "generate_framework_bzl",
    srcs = ["generate_framework.bzl"],
    visibility = ["//visibility:private"],
    deps = [
        ":generation_support",
        "@bazel_skylib//lib:dicts",
        "@bazel_skylib//lib:paths",
        "@build_bazel_apple_support//lib:apple_support",
        "@build_bazel_rules_swift//swift:providers",
    ],
)

bzl_library(
    name = "generation_support",
    srcs = ["generation_support.bzl"],
    visibility = ["//test:__subpackages__"],
    deps = [
        "//apple/internal:intermediates",
        "@bazel_skylib//lib:paths",
        "@build_bazel_apple_support//lib:apple_support",
    ],
)
