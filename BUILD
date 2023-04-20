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
        "@com_github_apple_swift-argument-parser//:for_bazel_tests",
        "@com_github_jakeheis_SwiftCLI//:for_bazel_tests",
        "@com_github_mtynior_ColorizeSwift//:for_bazel_tests",
        "@rules_xcodeproj//:for_bazel_tests",
        "@xctestrunner//:for_bazel_tests",
    ],
    visibility = [
        "//:__subpackages__",
    ],
)
