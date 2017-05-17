package(default_visibility = ["//visibility:public"])

licenses(["notice"])

py_binary(
    name = "plisttool",
    srcs = ["plisttool.py"],
)

py_test(
    name = "plisttool_unittest",
    srcs = ["plisttool_unittest.py"],
    deps = [":plisttool"],
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
