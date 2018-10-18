package(default_visibility = ["//visibility:public"])

licenses(["notice"])

py_library(
    name = "execute",
    srcs = ["execute.py"],
)

py_test(
    name = "execute_test",
    srcs = ["execute_test.py"],
    deps = [
        ":execute",
        "//:py_init_shim",
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
