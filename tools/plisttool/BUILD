licenses(["notice"])

py_binary(
    name = "plisttool",
    srcs = ["plisttool.py"],
    visibility = [
        "//apple/internal/toolchains:__subpackages__",
    ],
    deps = [":plisttool_lib"],
)

py_library(
    name = "plisttool_lib",
    srcs = [
        "plisttool.py",
    ],
)

py_test(
    name = "plisttool_unittest",
    srcs = ["plisttool_unittest.py"],
    deps = [
        ":plisttool_lib",
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
