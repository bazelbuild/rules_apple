load("//tools:binary_env.bzl", "binary_env")

licenses(["notice"])

py_binary(
    name = "xctoolrunner",
    srcs = ["xctoolrunner.py"],
    env = binary_env.common_python_utf8_env(),
    visibility = [
        "//apple/internal/toolchains:__subpackages__",
    ],
    deps = [":xctoolrunner_lib"],
)

py_library(
    name = "xctoolrunner_lib",
    srcs = ["xctoolrunner.py"],
    deps = ["//tools/wrapper_common:execute"],
)

py_test(
    name = "xctoolrunner_test",
    srcs = ["xctoolrunner_test.py"],
    deps = [
        ":xctoolrunner_lib",
        "//tools/wrapper_common:execute",
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
