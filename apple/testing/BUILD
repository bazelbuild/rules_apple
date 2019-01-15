licenses(["notice"])

# TODO(thomasvl): Remove this.
filegroup(
    name = "DefaultTestBundlePlist",
    srcs = [
        "DefaultTestBundle.plist",
    ],
    visibility = ["//visibility:public"],
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
