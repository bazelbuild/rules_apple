package(default_visibility = [
    "//:__subpackages__",
])

licenses(["notice"])

filegroup(
    name = "common",
    srcs = glob(["*.bzl"]),
    visibility = ["//:__subpackages__"],
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
