licenses(["notice"])

py_binary(
    name = "versiontool",
    srcs = ["versiontool.py"],
    strict_deps = False,
    visibility = [
        "//apple/internal/toolchains:__subpackages__",
    ],
    deps = [":versiontool_lib"],
)

py_library(
    name = "versiontool_lib",
    srcs = ["versiontool.py"],
    strict_deps = False,
)

py_test(
    name = "versiontool_unittest",
    srcs = ["versiontool_unittest.py"],
    strict_deps = False,
    deps = [
        ":versiontool_lib",
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
