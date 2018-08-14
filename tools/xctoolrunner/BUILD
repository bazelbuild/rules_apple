package(default_visibility = ["//visibility:public"])

licenses(["notice"])

py_binary(
    name = "xctoolrunner",
    srcs = ["xctoolrunner.py"],
    deps = ["//tools/wrapper_common:execute"],
)

py_test(
    name = "xctoolrunner_test",
    srcs = ["xctoolrunner_test.py"],
    deps = [
        ":xctoolrunner",
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
