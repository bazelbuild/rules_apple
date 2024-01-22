load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

# Internal providers.
#
# This file creates a package for internal providers meant to be used
# by aspects, or partials. And not to be exposed to end users.
#
# These providers are meant to be used only by rules_apple internal
# implementations and implementation details may change at any time.
# Please do not depend on these providers.

licenses(["notice"])

bzl_library(
    name = "app_intents_info",
    srcs = ["app_intents_info.bzl"],
    visibility = [
        # Visibility set to subpackages since this provider is used both
        # by the `app_intents_aspect` and `app_intents_metadata_bundle` partial.
        "//apple/internal:__subpackages__",
    ],
)

bzl_library(
    name = "apple_debug_info",
    srcs = ["apple_debug_info.bzl"],
    visibility = [
        # Visibility set to subpackages since this provider is used both
        # by the `resource_aspect` and `debug_symbols` partial.
        "//apple/internal:__subpackages__",
    ],
)

bzl_library(
    name = "apple_resource_hint_info",
    srcs = ["apple_resource_hint_info.bzl"],
    visibility = [
        # This provider is used both by the `resource_aspect` and the `apple_resource_hint` rule.
        "//apple/hints:__subpackages__",
        "//apple/internal/aspects:__subpackages__",
    ],
)

bzl_library(
    name = "apple_resource_validation_info",
    srcs = ["apple_resource_validation_info.bzl"],
    visibility = [
        # Visibility set to subpackages since this provider is used both
        # by the `resource_aspect` and `child_bundle_info_validation` partial.
        "//apple/internal:__subpackages__",
    ],
)

bzl_library(
    name = "embeddable_info",
    srcs = ["embeddable_info.bzl"],
    visibility = [
        # Visibility set to subpackages since this provider is used both
        # by the `framework_provider_aspect` and `embedded_bundles` partial.
        "//apple/internal:__subpackages__",
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
