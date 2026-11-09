load("@rules_python//python:py_binary.bzl", "py_binary")
load("@rules_python//python:py_library.bzl", "py_library")
load("@rules_python//python:py_test.bzl", "py_test")

licenses(["notice"])

py_binary(
    name = "deferred_test_linker",
    srcs = ["deferred_test_linker.py"],
    python_version = "PY3",
    srcs_version = "PY3",
    # Test runners that advertise `supports_deferred_test_linking`, including
    # ones outside of this repository, run it from their templates (see
    # `AppleTestRunnerInfo`), so it needs to be public.
    visibility = ["//visibility:public"],
    deps = [":deferred_test_linker_lib"],
)

py_library(
    name = "deferred_test_linker_lib",
    srcs = [
        "__init__.py",
        "deferred_test_linker.py",
    ],
    data = ["//tools/main_thread_checker_tool:main_thread_checker_tool.sh"],
    srcs_version = "PY3",
    deps = [
        "//tools/clangrttool:clangrttool_lib",
        "//tools/swift_stdlib_tool:swift_stdlib_tool_lib",
    ],
)

py_test(
    name = "deferred_test_linker_unittest",
    srcs = ["deferred_test_linker_unittest.py"],
    python_version = "PY3",
    deps = [":deferred_test_linker_lib"],
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
