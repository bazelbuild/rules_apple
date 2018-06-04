package(default_visibility = ["//visibility:public"])

licenses(["notice"])

py_binary(
    name = "bundletool",
    srcs = ["bundletool.py"],
)

py_binary(
    name = "bundletool_experimental",
    srcs = ["bundletool_experimental.py"],
)

py_test(
    name = "bundletool_unittest",
    srcs = ["bundletool_unittest.py"],
    deps = [
        ":bundletool",
        "//:py_init_shim",
    ],
)

filegroup(
    name = "process_and_sign_template",
    srcs = ["process_and_sign.sh.template"],
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
