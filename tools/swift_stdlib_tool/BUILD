licenses(["notice"])

cc_binary(
    name = "swift_stdlib_tool_bin",
    srcs = ["@swift_stdlib_tool//file"],
)

py_binary(
    name = "swift_stdlib_tool",
    srcs = ["swift_stdlib_tool.py"],
    data = [":swift_stdlib_tool_bin"],
    python_version = "PY3",
    srcs_version = "PY3",
    visibility = [
        "//apple/internal:__pkg__",
    ],
    deps = [
        "//tools/bitcode_strip",
        "//tools/wrapper_common:execute",
        "//tools/wrapper_common:lipo",
        "@bazel_tools//tools/python/runfiles",
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
