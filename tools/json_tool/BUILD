load("@rules_python//python:py_binary.bzl", "py_binary")

licenses(["notice"])

py_binary(
    name = "json_tool",
    srcs = ["json_tool.py"],
    python_version = "PY3",
    srcs_version = "PY3",
    visibility = [
        "//apple/internal:__pkg__",
        "//tools:__pkg__",
    ],
)

filegroup(
    name = "for_bazel_tests",
    testonly = True,
    srcs = glob(["**"]),
    visibility = ["//tools:__pkg__"],
)
