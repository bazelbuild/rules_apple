load("//tools:py2and3_test.bzl", "py2and3_test")

licenses(["notice"])

py_library(
    name = "execute",
    srcs = ["execute.py"],
    srcs_version = "PY2AND3",
    # Used by the rule implementations, so it needs to be public; but
    # should be considered an implementation detail of the rules and
    # not used by other things.
    visibility = ["//visibility:public"],
)

py2and3_test(
    name = "execute_test",
    srcs = ["execute_test.py"],
    deps = [
        ":execute",
        "//:py_init_shim",
    ],
)

py_library(
    name = "lipo",
    srcs = ["lipo.py"],
    srcs_version = "PY2AND3",
    visibility = [
        "//tools:__subpackages__",
    ],
    deps = ["//tools/wrapper_common:execute"],
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
