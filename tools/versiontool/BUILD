package(default_visibility = ["//visibility:public"])

licenses(["notice"])

py_binary(
    name = "versiontool",
    srcs = ["versiontool.py"],
)

py_test(
    name = "versiontool_unittest",
    srcs = ["versiontool_unittest.py"],
    deps = [
        ":versiontool",
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
