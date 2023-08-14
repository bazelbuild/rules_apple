load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

# Public only because these are used by the integration tests from generated
# workspaces. Please no not depend on them as they can change at any time.
package(default_visibility = ["//visibility:public"])

licenses(["notice"])

filegroup(
    name = "swift_source",
    srcs = [
        "SharedClass.swift",
    ],
)

filegroup(
    name = "objc_source",
    srcs = [
        "SharedClass.m",
    ],
)

filegroup(
    name = "objc_headers",
    srcs = [
        "SharedClass.h",
    ],
)

# ------------------------------- iOS Framework ------------------------------------------

swift_library(
    name = "swift_framework_lib",
    srcs = ["SharedClass.swift"],
    features = [
        "swift.emit_swiftinterface",
        "swift.enable_library_evolution",
    ],
    generates_header = True,
    module_name = "iOSSwiftStaticFramework",
)

# ------------------------------- macOS Framework ------------------------------------------

bzl_library(
    name = "generate_framework_bzl",
    srcs = ["generate_framework.bzl"],
    visibility = ["//visibility:private"],
    deps = [
        ":generation_support",
        "@bazel_skylib//lib:dicts",
        "@bazel_skylib//lib:paths",
        "@build_bazel_apple_support//lib:apple_support",
        "@build_bazel_rules_swift//swift",
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
