load("@rules_python//python:py_binary.bzl", "py_binary")
load("@rules_python//python:py_test.bzl", "py_test")
load("//tools:binary_env.bzl", "binary_env")

licenses(["notice"])

py_binary(
    name = "skills_bundle_validator",
    srcs = ["skills_bundle_validator.py"],
    env = binary_env.common_python_utf8_env(),
    python_version = "PY3",
    srcs_version = "PY3",
    visibility = [
        "//apple:__subpackages__",
    ],
)

py_test(
    name = "skills_bundle_validator_test",
    srcs = [
        "skills_bundle_validator.py",
        "skills_bundle_validator_test.py",
    ],
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
