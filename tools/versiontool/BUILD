licenses(["notice"])

py_binary(
    name = "versiontool",
    srcs = ["versiontool.py"],
    python_version = "PY3",
    srcs_version = "PY3",
    # Used by the rule implementations, so it needs to be public; but
    # should be considered an implementation detail of the rules and
    # not used by other things.
    visibility = ["//visibility:public"],
    deps = [":versiontool_lib"],
)

py_library(
    name = "versiontool_lib",
    srcs = ["versiontool.py"],
    srcs_version = "PY3",
)

py_test(
    name = "versiontool_unittest",
    srcs = ["versiontool_unittest.py"],
    python_version = "PY3",
    deps = [
        ":versiontool_lib",
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
