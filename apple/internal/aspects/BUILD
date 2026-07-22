load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("//apple/internal/aspects:apple_swift_const_values_json.bzl", "apple_swift_const_values_json")

package(
    default_visibility = [
        "//apple:__subpackages__",
    ],
)

# Aspects.

# This file exists to create a package under which to load the aspect bzl files.

licenses(["notice"])

bzl_library(
    name = "app_intents_aspect",
    srcs = ["app_intents_aspect.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        "//apple/internal:cc_info_support",
        "//apple/internal/providers:app_intents_info",
        "//apple/internal/toolchains:apple_toolchains",
        "@build_bazel_rules_swift//swift:providers",
    ],
)

filegroup(
    name = "app_intents_fallback_json",
    srcs = ["AppIntents.json"],
)

# TODO(b/527923227): Remove the need for this by sourcing the Swift const values from the module
# directly via arguments, possibly even JSON in the action arguments, instead of through a file.
apple_swift_const_values_json(
    name = "app_intents_sdk_json",
)

bzl_library(
    name = "apple_swift_const_values_json",
    srcs = ["apple_swift_const_values_json.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        "@build_bazel_rules_swift//swift:providers",
    ],
)

bzl_library(
    name = "framework_provider_aspect",
    srcs = ["framework_provider_aspect.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        "//apple:providers",
        "//apple/internal:providers",
    ],
)

bzl_library(
    name = "resource_aspect",
    srcs = ["resource_aspect.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        "//apple/internal:platform_support",
        "//apple/internal:providers",
        "//apple/internal:resources",
        "//apple/internal:swift_support",
        "//apple/internal/providers:app_intents_info",
        "//apple/internal/providers:apple_resource_explicit_files_info",
        "//apple/internal/providers:apple_resource_validation_info",
        "//apple/internal/toolchains:apple_toolchains",
        "@build_bazel_apple_support//lib:apple_support",
        "@build_bazel_apple_support//xcode:providers",
        "@build_bazel_rules_swift//swift:providers",
    ],
)

bzl_library(
    name = "swift_generated_header_aspect",
    srcs = ["swift_generated_header_aspect.bzl"],
    visibility = [
        "//apple/internal:__pkg__",
    ],
    deps = [
        "//apple/internal/providers:swift_generated_header_info",
    ],
)

bzl_library(
    name = "swift_usage_aspect",
    srcs = ["swift_usage_aspect.bzl"],
    visibility = [
        "//apple/internal:__pkg__",
    ],
    deps = [
        "@build_bazel_rules_swift//swift:providers",
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
