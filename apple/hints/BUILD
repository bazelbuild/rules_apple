load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("//apple/hints:app_intents_hint.bzl", "app_intents_hint")
load("//apple/hints:apple_resource_hint.bzl", "apple_resource_hint")

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
    name = "apple_resource_hint",
    srcs = ["apple_resource_hint.bzl"],
    deps = [
        "//apple/internal/providers:apple_resource_hint_info",
    ],
)

app_intents_hint(
    name = "app_intents_hint",
)

app_intents_hint(
    name = "shared_library_app_intents_hint",
    static_metadata = True,
)

apple_resource_hint(
    name = "realitykit_library_hint",
    needs_swift_srcs = True,
    needs_transitive_swift_srcs = True,
)
