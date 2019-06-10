load("//tools:py2and3_test.bzl", "py2and3_test")

licenses(["notice"])

py_binary(
    name = "xctoolrunner",
    srcs = ["xctoolrunner.py"],
    srcs_version = "PY2AND3",
    # Used by the rule implementations, so it needs to be public; but
    # should be considered an implementation detail of the rules and
    # not used by other things.
    visibility = ["//visibility:public"],
    deps = [":xctoolrunner_lib"],
)

py_library(
    name = "xctoolrunner_lib",
    srcs = ["xctoolrunner.py"],
    srcs_version = "PY2AND3",
    deps = ["//tools/wrapper_common:execute"],
)

py2and3_test(
    name = "xctoolrunner_test",
    srcs = ["xctoolrunner_test.py"],
    deps = [
        ":xctoolrunner_lib",
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
