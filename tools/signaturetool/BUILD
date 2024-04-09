load("@build_bazel_rules_swift//swift:swift_binary.bzl", "swift_binary")
load("@build_bazel_rules_swift//swift:swift_library.bzl", "swift_library")
load("//apple:apple.bzl", "apple_universal_binary")
load("//tools/build_rules:build_test.bzl", "build_test")

licenses(["notice"])

apple_universal_binary(
    name = "signature_tool_osx",
    binary = ":signature_tool",
    forced_cpus = [
        "x86_64",
        "arm64",
    ],
    minimum_os_version = "13.0",
    platform_type = "macos",
)

swift_binary(
    name = "signature_tool",
    srcs = [
        "CollectSignatures.swift",
        "SignatureTool.swift",
    ],
    tags = [
        "manual",
        "notap",
    ],
    target_compatible_with = ["@platforms//os:macos"],
    deps = [
        ":collect_signatures_options",
    ],
)

swift_library(
    name = "collect_signatures_options",
    srcs = ["CollectSignaturesOptions.swift"],
)

build_test(
    name = "signature_tool_build_test",
    targets = [":signature_tool_osx"],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]),
    visibility = [
        "//tools:__pkg__",
    ],
)
