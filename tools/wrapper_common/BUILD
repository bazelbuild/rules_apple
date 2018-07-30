package(default_visibility = ["//visibility:public"])

licenses(["notice"])

sh_library(
    name = "wrapper_common",
    srcs = ["wrapper_common.sh"],
    data = [
        "//tools/realpath",
        "@bazel_tools//tools/objc:xcrunwrapper",
    ],
)

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
