load("//tools:py2and3_test.bzl", "py2and3_test")

licenses(["notice"])

py_library(
    name = "execute",
    srcs = ["execute.py"],
    srcs_version = "PY2AND3",
    visibility = [
        "//apple/internal:__pkg__",
        "//test/testdata/fmwk:__pkg__",
        "//tools/bitcode_strip:__pkg__",
        "//tools/codesigningtool:__pkg__",
        "//tools/dossier_codesigningtool:__pkg__",
        "//tools/swift_stdlib_tool:__pkg__",
        "//tools/xctoolrunner:__pkg__",
    ],
)

py2and3_test(
    name = "execute_test",
    srcs = ["execute_test.py"],
    deps = [
        ":execute",
    ],
)

py_library(
    name = "lipo",
    srcs = ["lipo.py"],
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
