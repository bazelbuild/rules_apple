package(default_visibility = ["//visibility:public"])

licenses(["notice"])

filegroup(
    name = "testing",
    srcs = [
        "ios.bzl",
    ],
)

filegroup(
    name = "DefaultTestBundlePlist",
    srcs = [
        "DefaultTestBundle.plist",
    ],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]) + [
        "//apple/testing/default_host/ios:for_bazel_tests",
        "//apple/testing/default_runner:for_bazel_tests",
    ],
    visibility = ["//:__subpackages__"],
)
