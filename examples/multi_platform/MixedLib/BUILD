load("//apple:apple.bzl", "experimental_mixed_language_library")
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
