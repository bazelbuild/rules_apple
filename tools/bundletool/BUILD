licenses(["notice"])

py_binary(
    name = "bundletool",
    srcs = ["bundletool.py"],
    visibility = [
        "//apple/internal/toolchains:__subpackages__",
    ],
    deps = [":bundletool_lib"],
)

py_library(
    name = "bundletool_lib",
    srcs = ["bundletool.py"],
)

py_binary(
    name = "bundletool_experimental",
    srcs = ["bundletool_experimental.py"],
    visibility = [
        "//apple/internal/toolchains:__subpackages__",
    ],
)

py_test(
    name = "bundletool_test",
    srcs = ["bundletool_test.py"],
    deps = [
        ":bundletool_lib",
    ],
)

filegroup(
    name = "process_and_sign_template",
    srcs = ["process_and_sign.sh.template"],
    visibility = [
        "//apple/internal/toolchains:__subpackages__",
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
