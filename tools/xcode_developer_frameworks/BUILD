load("@rules_python//python:py_library.bzl", "py_library")
load("@rules_python//python:py_test.bzl", "py_test")

licenses(["notice"])

exports_files(
    ["scan.py"],
    visibility = ["//visibility:public"],
)

py_library(
    name = "scan_lib",
    srcs = ["scan.py"],
    srcs_version = "PY3",
)

py_test(
    name = "scan_test",
    srcs = ["scan_test.py"],
    python_version = "PY3",
    deps = [":scan_lib"],
)

filegroup(
    name = "for_bazel_tests",
    testonly = True,
    srcs = [
        "BUILD",
        "scan.py",
        "scan_test.py",
    ],
    visibility = ["//tools:__pkg__"],
)
