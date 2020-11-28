licenses(["notice"])

py_binary(
    name = "dossier_codesigningtool",
    srcs = ["dossier_codesigningtool.py"],
    srcs_version = "PY2AND3",
    # Used by the rule implementations, so it needs to be public; but
    # should be considered an implementation detail of the rules and
    # not used by other things.
    visibility = ["//visibility:public"],
    deps = [":dossier_codesigningtool_lib"],
)

py_library(
    name = "dossier_codesigningtool_lib",
    srcs = ["dossier_codesigningtool.py"],
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
