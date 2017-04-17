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

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]),
    visibility = [
        "//tools:__pkg__",
    ],
)
