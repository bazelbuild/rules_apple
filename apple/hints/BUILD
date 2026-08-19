load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("//apple/hints:app_extension_point_hint.bzl", "app_extension_point_hint")
load("//apple/hints:app_intents_hint.bzl", "app_intents_hint")
load("//apple/hints:extension_foundation_hint.bzl", "extension_foundation_hint")

package(
    default_visibility = ["//visibility:public"],
)

licenses(["notice"])

bzl_library(
    name = "app_intents_hint_bzl",
    srcs = ["app_intents_hint.bzl"],
    deps = [
        "//apple/internal/providers:app_intents_info",
    ],
)

bzl_library(
    name = "extension_foundation_hint_bzl",
    srcs = ["extension_foundation_hint.bzl"],
    visibility = ["//apple/internal:__subpackages__"],
)

bzl_library(
    name = "app_extension_point_hint_bzl",
    srcs = ["app_extension_point_hint.bzl"],
    visibility = ["//apple/internal:__subpackages__"],
)

app_intents_hint(
    name = "app_intents_hint",
)

app_intents_hint(
    name = "shared_library_app_intents_hint",
    static_metadata = True,
)

extension_foundation_hint(
    name = "extension_foundation_hint",
)

app_extension_point_hint(
    name = "app_extension_point_hint",
)
