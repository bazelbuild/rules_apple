load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("//apple/hints:apple_resource_hint.bzl", "apple_resource_hint")

package(
    default_visibility = ["//visibility:public"],
)

licenses(["notice"])

bzl_library(
    name = "apple_resource_hint",
    srcs = ["apple_resource_hint.bzl"],
    deps = [
        "//apple/internal/providers:apple_resource_hint_info",
    ],
)

apple_resource_hint(
    name = "realitykit_library_hint",
    needs_swift_srcs = True,
)
