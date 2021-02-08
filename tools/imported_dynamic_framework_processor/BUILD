licenses(["notice"])

py_binary(
    name = "imported_dynamic_framework_processor",
    srcs = ["imported_dynamic_framework_processor.py"],
    python_version = "PY3",
    srcs_version = "PY2AND3",
    visibility = [
        "//apple/internal:__pkg__",
    ],
    deps = [
        "//tools/codesigningtool:codesigningtool_lib",
        "//tools/wrapper_common:lipo",
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
