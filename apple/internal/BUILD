# Experimental resource propagation logic.

# This file exists to create a package under which to load the experimental
# resource propagation logic bzl files.

package(default_visibility = [
    "//apple:__subpackages__",
])

licenses(["notice"])

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]) + [
        "//apple/internal/aspects:for_bazel_tests",
        "//apple/internal/partials:for_bazel_tests",
        "//apple/internal/resource_actions:for_bazel_tests",
        "//apple/internal/testing:for_bazel_tests",
    ],
    visibility = [
        "//apple:__subpackages__",
    ],
)
