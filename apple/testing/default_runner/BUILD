load(
    "//apple/testing/default_runner:ios_test_runner.bzl",
    "ios_test_runner",
)
load(
    "//apple/testing/default_runner:macos_test_runner.bzl",
    "macos_test_runner",
)
load(
    "//apple/testing/default_runner:tvos_test_runner.bzl",
    "tvos_test_runner",
)
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

licenses(["notice"])

bzl_library(
    name = "ios_test_runner",
    srcs = ["ios_test_runner.bzl"],
    deps = [
        "//apple/testing:apple_test_rules",
    ],
)

bzl_library(
    name = "macos_test_runner",
    srcs = ["macos_test_runner.bzl"],
    deps = [
        "//apple/testing:apple_test_rules",
        "@build_bazel_apple_support//lib:xcode_support",
    ],
)

bzl_library(
    name = "tvos_test_runner",
    srcs = ["tvos_test_runner.bzl"],
    deps = [
        "//apple/testing:apple_test_rules",
    ],
)

exports_files([
    "ios_test_runner.template.sh",
    "macos_test_runner.template.sh",
    "macos_test_runner.template.xctestrun",
    "tvos_test_runner.template.sh",
])

ios_test_runner(
    name = "ios_default_runner",
    # Used by the rule implementations, so it needs to be public; but
    # should be considered an implementation detail of the rules and
    # not used by other things.
    visibility = ["//visibility:public"],
)

macos_test_runner(
    name = "macos_default_runner",
    # Used by the rule implementations, so it needs to be public; but
    # should be considered an implementation detail of the rules and
    # not used by other things.
    visibility = ["//visibility:public"],
)

tvos_test_runner(
    name = "tvos_default_runner",
    # Used by the rule implementations, so it needs to be public; but
    # should be considered an implementation detail of the rules and
    # not used by other things.
    visibility = ["//visibility:public"],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]),
    visibility = [
        "//:__subpackages__",
    ],
)
