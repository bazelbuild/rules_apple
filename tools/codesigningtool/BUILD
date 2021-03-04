licenses(["notice"])

py_binary(
    name = "codesigningtool",
    srcs = ["codesigningtool.py"],
    python_version = "PY3",
    srcs_version = "PY3",
    visibility = [
        "//apple/internal:__pkg__",
    ],
    deps = [":codesigningtool_lib"],
)

py_library(
    name = "codesigningtool_lib",
    srcs = ["codesigningtool.py"],
    srcs_version = "PY3",
    visibility = [
        "//tools:__subpackages__",
    ],
    deps = ["//tools/wrapper_common:execute"],
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
