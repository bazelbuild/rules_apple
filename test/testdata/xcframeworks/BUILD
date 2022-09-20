load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

licenses(["notice"])

# TODO(b/241460068): Migrate targets to starlark_tests/
package(default_visibility = ["//test/starlark_tests:__subpackages__"])

bzl_library(
    name = "generate_xcframework_bzl",
    srcs = ["generate_xcframework.bzl"],
    visibility = ["//visibility:private"],
    deps = [
        "//test/starlark_tests/rules:test_rules",
        "@bazel_skylib//lib:dicts",
        "@bazel_skylib//lib:paths",
        "@build_bazel_apple_support//lib:apple_support",
        "@build_bazel_rules_swift//swift:providers",
    ],
)
