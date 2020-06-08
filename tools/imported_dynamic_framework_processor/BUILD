licenses(["notice"])

py_binary(
    name = "imported_dynamic_framework_processor",
    srcs = ["imported_dynamic_framework_processor.py"],
    srcs_version = "PY2AND3",
    # Used by the rule implementations, so it needs to be public; but
    # should be considered an implementation detail of the rules and
    # not used by other things.
    visibility = ["//visibility:public"],
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
