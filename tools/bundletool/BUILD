load("//tools:py2and3_test.bzl", "py2and3_test")

licenses(["notice"])

py_binary(
    name = "bundletool",
    srcs = ["bundletool.py"],
    python_version = "PY3",
    visibility = [
        "//apple/internal:__pkg__",
    ],
    deps = [":bundletool_lib"],
)

py_library(
    name = "bundletool_lib",
    srcs = ["bundletool.py"],
    srcs_version = "PY2AND3",
)

py_binary(
    name = "bundletool_experimental",
    srcs = ["bundletool_experimental.py"],
    python_version = "PY3",
    visibility = [
        "//apple/internal:__pkg__",
    ],
)

py2and3_test(
    name = "bundletool_unittest",
    srcs = ["bundletool_unittest.py"],
    deps = [
        ":bundletool_lib",
    ],
)

filegroup(
    name = "process_and_sign_template",
    srcs = ["process_and_sign.sh.template"],
    visibility = [
        "//apple/internal:__pkg__",
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
