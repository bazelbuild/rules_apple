licenses(["notice"])

py_binary(
    name = "dertool",
    srcs = ["dertool.py"],
    python_version = "PY3",
    srcs_version = "PY3",
    visibility = [
        "//apple/internal:__pkg__",
    ],
    deps = [":dertool_lib"],
)

py_library(
    name = "dertool_lib",
    srcs = [
        "dertool.py",
    ],
    srcs_version = "PY3",
    deps = [
        "//tools/codesigningtool:codesigningtool_lib",
    ],
)

py_test(
    name = "dertool_unittest",
    srcs = ["dertool_unittest.py"],
    python_version = "PY3",
    tags = ["requires-darwin"],
    deps = [
        ":dertool_lib",
    ],
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
