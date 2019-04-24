licenses(["notice"])

py_library(
    name = "execute",
    srcs = ["execute.py"],
    # Used by the rule implementations, so it needs to be public; but
    # should be considered an implementation detail of the rules and
    # not used by other things.
    visibility = ["//visibility:public"],
)

py_test(
    name = "execute_test",
    srcs = ["execute_test.py"],
    python_version = "PY2",
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
