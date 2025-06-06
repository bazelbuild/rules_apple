licenses(["notice"])

py_library(
    name = "execute",
    srcs = ["execute.py"],
    visibility = [
        "//tools/xctoolrunner:__pkg__",
    ],
)

py_test(
    name = "execute_test",
    srcs = ["execute_test.py"],
    deps = [
        ":execute",
    ],
)

py_library(
    name = "lipo",
    srcs = ["lipo.py"],
    visibility = [
        "//tools:__subpackages__",
    ],
    deps = [":execute"],
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
