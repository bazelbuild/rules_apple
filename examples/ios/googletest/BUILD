load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("//apple:ios.bzl", "ios_unit_test")

swift_library(
    name = "lib",
    testonly = True,
    srcs = ["tests.swift"],
    tags = ["manual"],
)

ios_unit_test(
    name = "tests",
    linkopts = ["-execute"],
    minimum_os_version = "15.0",
    runner = "@build_bazel_rules_apple//apple/testing/default_runner:ios_googletest_runner",
    deps = [":lib"],
)
