load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])

# TODO(b/180572694): Remove ios_sim_arm64 after platforms based toolchain resolution supported.
# Create a set of public config_settings that can be used in select()s.
[
    config_setting(
        name = arch,
        values = {"cpu": arch},
    )
    for arch in [
        "darwin_x86_64",
        "darwin_arm64",
        "darwin_arm64e",
        "ios_i386",
        "ios_x86_64",
        "ios_armv7",
        "ios_arm64",
        "ios_sim_arm64",
        "tvos_x86_64",
        "tvos_arm64",
        "tvos_sim_arm64",
        "watchos_i386",
        "watchos_arm64",
        "watchos_armv7k",
        "watchos_arm64_32",
        "watchos_x86_64",
    ]
]

bzl_library(
    name = "apple",
    srcs = ["apple.bzl"],
    deps = [
        "//apple/internal:apple_framework_import",
        "//apple/internal:apple_universal_binary",
        "//apple/internal:xcframework_rules",
    ],
)

bzl_library(
    name = "apple_binary",
    srcs = ["apple_binary.bzl"],
    deps = [
        "//apple/internal:linking_support",
        "//apple/internal:rule_factory",
    ],
)

bzl_library(
    name = "aspects",
    srcs = ["aspects.bzl"],
    deps = [
        "//apple/internal/aspects:framework_provider_aspect",
    ],
)

bzl_library(
    name = "common",
    srcs = ["common.bzl"],
)

bzl_library(
    name = "dtrace",
    srcs = ["dtrace.bzl"],
    deps = [
        "//apple/internal/utils:bundle_paths",
        "@bazel_skylib//lib:dicts",
        "@bazel_skylib//lib:paths",
        "@build_bazel_apple_support//lib:apple_support",
    ],
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
    name = "ios.doc",
    srcs = ["ios.doc.bzl"],
    deps = ["ios"],
)

bzl_library(
    name = "macos",
    srcs = ["macos.bzl"],
    deps = [
        "//apple/internal:macos_binary_support",
        "//apple/internal:macos_rules",
        "//apple/internal/testing:apple_test_assembler",
        "//apple/internal/testing:build_test_rules",
        "//apple/internal/testing:macos_rules",
    ],
)

bzl_library(
    name = "macos.doc",
    srcs = ["macos.doc.bzl"],
    deps = ["macos"],
)

bzl_library(
    name = "providers",
    srcs = ["providers.bzl"],
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
    name = "tvos.doc",
    srcs = ["tvos.doc.bzl"],
    deps = ["tvos"],
)

bzl_library(
    name = "utils",
    srcs = ["utils.bzl"],
)

bzl_library(
    name = "versioning",
    srcs = ["versioning.bzl"],
    deps = [
        ":providers",
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

bzl_library(
    name = "watchos.doc",
    srcs = ["watchos.doc.bzl"],
    deps = ["watchos"],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]) + [
        "//apple/internal:for_bazel_tests",
        "//apple/testing:for_bazel_tests",
    ],
    visibility = ["//:__pkg__"],
)
