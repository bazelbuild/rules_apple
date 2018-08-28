# Partials.

# This file exists to create a package under which to load the processor
# partials bzl files.

package(default_visibility = [
    "//apple/internal:__pkg__",
])

licenses(["notice"])

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]) + [
        "//apple/internal/partials/support:for_bazel_tests",
    ],
    visibility = [
        "//apple:__subpackages__",
    ],
)
