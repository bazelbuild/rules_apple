load("@rules_python//python:py_binary.bzl", "py_binary")
load("@rules_python//python:py_test.bzl", "py_test")

licenses(["notice"])

py_binary(
    name = "deferred_test_linker",
    srcs = [
        "__init__.py",
        "deferred_test_linker.py",
    ],
    python_version = "PY3",
    srcs_version = "PY3",
    # Used by the test rule implementations, so it needs to be public; but
    # should be considered an implementation detail of the rules and not used
    # by other things.
    visibility = ["//visibility:public"],
)

py_test(
    name = "deferred_test_linker_unittest",
    srcs = ["deferred_test_linker_unittest.py"],
    python_version = "PY3",
    deps = [":deferred_test_linker"],
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
