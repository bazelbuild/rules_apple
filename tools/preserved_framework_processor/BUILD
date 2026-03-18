load("@rules_python//python:py_binary.bzl", "py_binary")
load("@rules_python//python:py_library.bzl", "py_library")
load("@rules_python//python:py_test.bzl", "py_test")

licenses(["notice"])

py_binary(
    name = "preserved_framework_processor",
    srcs = ["preserved_framework_processor.py"],
    python_version = "PY3",
    srcs_version = "PY3",
    visibility = [
        "//apple/internal:__pkg__",
    ],
    deps = [
        "//tools/preserved_framework_processor:preserved_framework_processor_lib",
    ],
)

py_library(
    name = "preserved_framework_processor_lib",
    srcs = ["preserved_framework_processor.py"],
    srcs_version = "PY3",
    visibility = [
        "//apple/internal:__pkg__",
    ],
)

py_test(
    name = "preserved_framework_processor_test",
    srcs = ["preserved_framework_processor_test.py"],
    python_version = "PY3",
    deps = [":preserved_framework_processor_lib"],
)

filegroup(
    name = "for_bazel_tests",
    testonly = True,
    srcs = glob(["**"]),
    visibility = [
        "//tools:__pkg__",
    ],
)
