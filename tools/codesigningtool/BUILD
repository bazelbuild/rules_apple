package(default_visibility = ["//visibility:public"])

licenses(["notice"])

py_binary(
    name = "codesigningtool",
    srcs = ["codesigningtool.py"],
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
