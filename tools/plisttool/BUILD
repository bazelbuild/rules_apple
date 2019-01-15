licenses(["notice"])

py_binary(
    name = "plisttool",
    srcs = ["plisttool.py"],
    # Used by the rule implementations, so it needs to be public.
    visibility = ["//visibility:public"],
)

py_test(
    name = "plisttool_unittest",
    srcs = ["plisttool_unittest.py"],
    deps = [
        ":plisttool",
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
