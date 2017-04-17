package(default_visibility = ["//visibility:public"])

licenses(["notice"])

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]) + [
        "//tools/actoolwrapper:for_bazel_tests",
        "//tools/environment_plist:for_bazel_tests",
        "//tools/ibtoolwrapper:for_bazel_tests",
        "//tools/momcwrapper:for_bazel_tests",
        "//tools/realpath:for_bazel_tests",
        "//tools/swiftstdlibtoolwrapper:for_bazel_tests",
        "//tools/wrapper_common:for_bazel_tests",
    ],
    visibility = [
        "//:__pkg__",
    ],
)
