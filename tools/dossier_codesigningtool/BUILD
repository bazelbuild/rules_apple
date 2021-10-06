licenses(["notice"])

py_binary(
    name = "dossier_codesigningtool",
    srcs = ["dossier_codesigningtool.py"],
    python_version = "PY3",
    srcs_version = "PY3",
    visibility = [
        "//apple/internal:__pkg__",
    ],
    deps = [":dossier_codesigningtool_lib"],
)

py_library(
    name = "dossier_codesigningtool_lib",
    srcs = ["dossier_codesigningtool.py"],
    srcs_version = "PY3",
    visibility = [
        "//tools:__subpackages__",
    ],
    deps = ["//tools/wrapper_common:execute"],
)

py_test(
    name = "dossier_codesigningtool_test",
    srcs = ["dossier_codesigningtool_test.py"],
    python_version = "PY3",
    deps = [
        ":dossier_codesigningtool_lib",
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
