load("//tools:py2and3_test.bzl", "py2and3_test")

licenses(["notice"])

py_binary(
    name = "symbols_tool",
    srcs = ["symbols_tool.py"],
    srcs_version = "PY2AND3",
    # Used by the rule implementations, so it needs to be public; but
    # should be considered an implementation detail of the rules and
    # not used by other things.
    visibility = ["//visibility:public"],
    deps = [":symbols_tool_lib"],
)

py_library(
    name = "symbols_tool_lib",
    srcs = ["symbols_tool.py"],
    srcs_version = "PY2AND3",
    deps = ["//tools/wrapper_common:execute"],
)

py2and3_test(
    name = "symbols_tool_test",
    srcs = ["symbols_tool_test.py"],
    deps = [
        ":symbols_tool_lib",
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
