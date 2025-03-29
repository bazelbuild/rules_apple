licenses(["notice"])

exports_files(["LICENSE"])

# See the note in __init__.py for why this is needed.
py_library(
    name = "py_init_shim",
    testonly = True,
    srcs = ["__init__.py"],
    visibility = ["//:__subpackages__"],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = True,
    srcs = [
        "WORKSPACE",
        "BUILD",
        "//apple:for_bazel_tests",
        "//tools:for_bazel_tests",
    ],
    visibility = [
        "//test:__subpackages__",
    ],
)
