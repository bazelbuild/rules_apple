load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load(":cc_toolchain_forwarder.bzl", "cc_toolchain_forwarder")

package(
    default_visibility = ["//visibility:public"],
)

licenses(["notice"])

bzl_library(
    name = "apple",
    srcs = ["apple.bzl"],
    deps = [
        "//apple/internal:apple_framework_import",
        "//apple/internal:apple_universal_binary",
        "//apple/internal:apple_xcframework_import",
        "//apple/internal:xcframework_rules",
    ],
)

bzl_library(
    name = "apple_binary",
    srcs = ["apple_binary.bzl"],
    deps = [
        "//apple/internal:linking_support",
        "//apple/internal:rule_attrs",
        "//apple/internal:rule_factory",
        "//apple/internal:transition_support",
    ],
)

bzl_library(
    name = "apple_static_library",
    srcs = ["apple_static_library.bzl"],
    deps = [
        "//apple/internal:linking_support",
        "//apple/internal:providers",
        "//apple/internal:rule_attrs",
        "//apple/internal:rule_factory",
        "//apple/internal:transition_support",
    ],
)

bzl_library(
    name = "aspects",
    srcs = ["aspects.bzl"],
    deps = [
        "//apple/internal/aspects:framework_provider_aspect",
        "//apple/internal/aspects:resource_aspect",
    ],
)

bzl_library(
    name = "capabilities",
    srcs = ["capabilities.bzl"],
    deps = [
        "//apple/internal:capabilities_rules",
    ],
)

bzl_library(
    name = "cc_toolchain_forwarder",
    srcs = ["cc_toolchain_forwarder.bzl"],
    deps = [
        ":providers",
        "//apple/internal:platform_support",
        "@bazel_skylib//lib:dicts",
        "@bazel_tools//tools/cpp:toolchain_utils",
        "@build_bazel_apple_support//lib:apple_support",
    ],
)

bzl_library(
    name = "common",
    srcs = ["common.bzl"],
)

bzl_library(
    name = "ios",
    srcs = ["ios.bzl"],
    deps = [
        "//apple/internal:apple_product_type",
        "//apple/internal:ios_rules",
        "//apple/internal/testing:apple_test_assembler",
        "//apple/internal/testing:build_test_rules",
        "//apple/internal/testing:ios_rules",
    ],
)

bzl_library(
    name = "linker",
    srcs = ["linker.bzl"],
    deps = [
        "//apple/internal:order_file",
    ],
)

bzl_library(
    name = "macos",
    srcs = ["macos.bzl"],
    deps = [
        "//apple/internal:capabilities_rules",
        "//apple/internal:macos_rules",
        "//apple/internal/testing:apple_test_assembler",
        "//apple/internal/testing:build_test_rules",
        "//apple/internal/testing:macos_rules",
    ],
)

bzl_library(
    name = "providers",
    srcs = ["providers.bzl"],
    deps = [
        "//apple/internal:providers",
        "//apple/internal:resources",
    ],
)

bzl_library(
    name = "repositories",
    srcs = ["repositories.bzl"],
)

bzl_library(
    name = "resources",
    srcs = ["resources.bzl"],
    deps = [
        "//apple/internal/resource_rules:apple_bundle_import",
        "//apple/internal/resource_rules:apple_core_data_model",
        "//apple/internal/resource_rules:apple_core_ml_library",
        "//apple/internal/resource_rules:apple_resource_bundle",
        "//apple/internal/resource_rules:apple_resource_group",
        "//apple/internal/resource_rules:apple_resource_locales",
    ],
)

bzl_library(
    name = "tvos",
    srcs = ["tvos.bzl"],
    deps = [
        "//apple/internal:tvos_rules",
        "//apple/internal/testing:apple_test_assembler",
        "//apple/internal/testing:build_test_rules",
        "//apple/internal/testing:tvos_rules",
    ],
)

bzl_library(
    name = "utils",
    srcs = ["utils.bzl"],
)

bzl_library(
    name = "versioning",
    srcs = ["versioning.bzl"],
    deps = [
        "//apple/internal:providers",
        "//apple/internal/toolchains:apple_toolchains",
        "@bazel_skylib//lib:dicts",
    ],
)

bzl_library(
    name = "visionos",
    srcs = ["visionos.bzl"],
    deps = [
        "//apple/internal:visionos_rules",
        "//apple/internal/testing:apple_test_assembler",
        "//apple/internal/testing:build_test_rules",
        "//apple/internal/testing:visionos_rules",
    ],
)

bzl_library(
    name = "watchos",
    srcs = ["watchos.bzl"],
    deps = [
        "//apple/internal:watchos_rules",
        "//apple/internal/testing:apple_test_assembler",
        "//apple/internal/testing:build_test_rules",
        "//apple/internal/testing:watchos_rules",
    ],
)

cc_toolchain_forwarder(
    name = "default_cc_toolchain_forwarder",
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]) + [
        "//apple/build_settings:for_bazel_tests",
        "//apple/internal:for_bazel_tests",
        "//apple/testing:for_bazel_tests",
    ],
    visibility = ["//:__pkg__"],
)
