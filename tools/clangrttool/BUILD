package(default_visibility = ["//visibility:public"])

licenses(["notice"])

py_binary(
    name = "clangrttool",
    srcs = ["clangrttool.py"],
)

py_test(
    name = "clangrttool_unittest",
    srcs = ["clangrttool_unittest.py"],
    deps = [":clangrttool"],
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
