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
    name = "embeddable_info",
    srcs = ["embeddable_info.bzl"],
    visibility = [
        # Visibility set to subpackages since this provider is used both
        # by the `framework_provider_aspect` and `embedded_bundles` partial.
        "//apple/internal:__subpackages__",
    ],
)

bzl_library(
    name = "framework_import_bundle_info",
    srcs = ["framework_import_bundle_info.bzl"],
    visibility = [
        "//apple/internal:__subpackages__",
    ],
)

bzl_library(
    name = "developer_framework_import_info",
    srcs = ["developer_framework_import_info.bzl"],
    visibility = [
        # The provider is part of the public API (re-exported from apple/providers.bzl),
        # so it must be visible to the top-level apple package as well.
        "//apple:__subpackages__",
    ],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = True,
    srcs = glob(["**"]),
    visibility = [
        "//apple:__subpackages__",
    ],
)
