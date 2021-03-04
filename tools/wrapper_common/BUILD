licenses(["notice"])

py_library(
    name = "execute",
    srcs = ["execute.py"],
    srcs_version = "PY3",
    visibility = [
<<<<<<< HEAD
        "//apple/internal:__pkg__",
        "//test/testdata/fmwk:__pkg__",
        "//tools/bitcode_strip:__pkg__",
=======
>>>>>>> 5798d77... Move to Python3 only.
        "//tools/codesigningtool:__pkg__",
        "//tools/dossier_codesigningtool:__pkg__",
        "//tools/swift_stdlib_tool:__pkg__",
        "//tools/xctoolrunner:__pkg__",
    ],
)

py_test(
    name = "execute_test",
    srcs = ["execute_test.py"],
    python_version = "PY3",
    deps = [
        ":execute",
        "//:py_init_shim",
    ],
)

py_library(
    name = "lipo",
    srcs = ["lipo.py"],
    srcs_version = "PY3",
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
