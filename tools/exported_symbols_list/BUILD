load("@rules_python//python:py_binary.bzl", "py_binary")
load("@rules_python//python:py_library.bzl", "py_library")
load("@rules_python//python:py_test.bzl", "py_test")

licenses(["notice"])

py_binary(
    name = "exported_symbols_list",
    srcs = ["exported_symbols_list.py"],
    python_version = "PY3",
    srcs_version = "PY3",
    visibility = ["//apple/internal:__pkg__"],
)

py_library(
    name = "exported_symbols_list_lib",
    srcs = ["exported_symbols_list.py"],
    srcs_version = "PY3",
)

py_test(
    name = "exported_symbols_list_test",
    srcs = ["exported_symbols_list_test.py"],
    python_version = "PY3",
    deps = [":exported_symbols_list_lib"],
)

filegroup(
    name = "for_bazel_tests",
    testonly = True,
    srcs = glob(["**"]),
    visibility = ["//tools:__pkg__"],
)
