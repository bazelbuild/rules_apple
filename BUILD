licenses(["notice"])

exports_files(["LICENSE"])

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = [
        "WORKSPACE",
        "//apple:for_bazel_tests",
        "//tools:for_bazel_tests",
    ],
    visibility = [
        "//test:__subpackages__",
    ],
)
