load("@rules_python//python:py_binary.bzl", "py_binary")
load("@rules_python//python:py_library.bzl", "py_library")
load("@rules_python//python:py_test.bzl", "py_test")
load("//tools:binary_env.bzl", "binary_env")

licenses(["notice"])

py_binary(
    name = "generate_test_xml",
    srcs = ["generate_test_xml.py"],
    env = binary_env.common_python_utf8_env(),
    python_version = "PY3",
    srcs_version = "PY3",
    visibility = ["//visibility:public"],
)

py_library(
    name = "generate_test_xml_lib",
    srcs = [
        "generate_test_xml.py",
    ],
    srcs_version = "PY3",
    visibility = ["//visibility:public"],
)

