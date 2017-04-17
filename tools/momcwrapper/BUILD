package(default_visibility = ["//visibility:public"])

licenses(["notice"])

sh_binary(
    name = "momcwrapper",
    srcs = ["momcwrapper.sh"],
    deps = ["//tools/wrapper_common"],
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
