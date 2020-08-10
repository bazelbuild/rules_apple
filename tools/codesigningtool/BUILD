licenses(["notice"])

py_binary(
    name = "codesigningtool",
    srcs = ["codesigningtool.py"],
    srcs_version = "PY2AND3",
    # Used by the rule implementations, so it needs to be public; but
    # should be considered an implementation detail of the rules and
    # not used by other things.
    visibility = ["//visibility:public"],
    deps = [":codesigningtool_lib"],
)

py_library(
    name = "codesigningtool_lib",
    srcs = ["codesigningtool.py"],
    srcs_version = "PY2AND3",
    visibility = [
        "//tools:__subpackages__",
    ],
    deps = ["//tools/wrapper_common:execute"],
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
