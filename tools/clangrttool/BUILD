licenses(["notice"])

py_binary(
    name = "clangrttool",
    srcs = ["clangrttool.py"],
    srcs_version = "PY2AND3",
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
