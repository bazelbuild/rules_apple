licenses(["notice"])

py_binary(
    name = "bundletool",
    srcs = ["bundletool.py"],
    # Used by the rule implementations, so it needs to be public; but
    # should be considered an implementation detail of the rules and
    # not used by other things.
    visibility = ["//visibility:public"],
    deps = [":bundletool_lib"],
)

py_library(
    name = "bundletool_lib",
    srcs = ["bundletool.py"],
)

py_binary(
    name = "bundletool_experimental",
    srcs = ["bundletool_experimental.py"],
    # Used by the rule implementations, so it needs to be public; but
    # should be considered an implementation detail of the rules and
    # not used by other things.
    visibility = ["//visibility:public"],
)

py_test(
    name = "bundletool_unittest",
    srcs = ["bundletool_unittest.py"],
    deps = [
        ":bundletool_lib",
        "//:py_init_shim",
    ],
)

filegroup(
    name = "process_and_sign_template",
    srcs = ["process_and_sign.sh.template"],
    # Used by the rule implementations, so it needs to be public; but
    # should be considered an implementation detail of the rules and
    # not used by other things.
    visibility = ["//visibility:public"],
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
