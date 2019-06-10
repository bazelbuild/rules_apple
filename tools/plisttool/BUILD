load("//tools:py2and3_test.bzl", "py2and3_test")

licenses(["notice"])

py_binary(
    name = "plisttool",
    srcs = ["plisttool.py"],
    srcs_version = "PY2AND3",
    # Used by the rule implementations, so it needs to be public; but
    # should be considered an implementation detail of the rules and
    # not used by other things.
    visibility = ["//visibility:public"],
    deps = [":plisttool_lib"],
)

py_library(
    name = "plisttool_lib",
    srcs = [
        "plisttool.py",
    ],
    srcs_version = "PY2AND3",
)

py2and3_test(
    name = "plisttool_unittest",
    srcs = ["plisttool_unittest.py"],
    deps = [
        ":plisttool_lib",
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
