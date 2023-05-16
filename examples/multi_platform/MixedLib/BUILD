load("//apple:apple.bzl", "experimental_mixed_language_library")
load("//apple:ios.bzl", "ios_unit_test")
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "swift_library",
)

experimental_mixed_language_library(
    name = "MixedAnswer",
    srcs = [
        "MixedAnswer.m",
        "MixedAnswer.swift",
    ],
    hdrs = ["MixedAnswer.h"],
)

swift_library(
    name = "SwiftLibDependingOnMixedLib",
    srcs = [
        "SwiftLibDependingOnMixedLib.swift",
    ],
    deps = [":MixedAnswer"],
)

experimental_mixed_language_library(
    name = "MixedTestsLib",
    testonly = True,
    srcs = [
        "MixedTests.m",
        "MixedTests.swift",
    ],
)

ios_unit_test(
    name = "MixedTests",
    minimum_os_version = "9.0",
    deps = [":MixedTestsLib"],
)
