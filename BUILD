licenses(["notice"])

exports_files(["LICENSE"])

# See the note in __init__.py for why this is needed.
py_library(
    name = "py_init_shim",
    testonly = 1,
    srcs = ["__init__.py"],
    visibility = ["//:__subpackages__"],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = [
        "WORKSPACE",
        "//apple:for_bazel_tests",
        "//tools:for_bazel_tests",
        "@build_bazel_apple_support//:for_bazel_tests",
        "@build_bazel_rules_swift//:for_bazel_tests",
        "@subpar//:subpar.bzl",
        "@xctestrunner//:for_bazel_tests",
    ],
    visibility = ["//:__subpackages__"],
)
