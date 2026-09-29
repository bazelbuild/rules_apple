load("@rules_python//python:py_binary.bzl", "py_binary")
load("@rules_python//python:py_test.bzl", "py_test")
load("//tools:binary_env.bzl", "binary_env")

licenses(["notice"])

py_binary(
    name = "app_intents_nl_training_tool",
    srcs = ["app_intents_nl_training_tool.py"],
    env = binary_env.common_python_utf8_env(),
    python_version = "PY3",
    srcs_version = "PY3",
    visibility = [
        "//apple/internal:__pkg__",
    ],
    deps = ["//tools/wrapper_common:execute"],
)

py_test(
    name = "app_intents_nl_training_tool_test",
    srcs = [
        "app_intents_nl_training_tool.py",
        "app_intents_nl_training_tool_test.py",
    ],
    deps = ["//tools/wrapper_common:execute"],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = True,
    srcs = glob(["**"]),
    visibility = [
        "//tools:__pkg__",
    ],
)
