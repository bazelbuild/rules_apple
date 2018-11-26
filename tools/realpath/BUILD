load(
    "//apple:apple_genrule.bzl",
    "apple_genrule",
)

package(default_visibility = ["//visibility:public"])

licenses(["notice"])

# This target will only build on a Mac.
apple_genrule(
    name = "realpath_genrule",
    srcs = ["realpath.c"],
    outs = ["realpath"],
    cmd = "/usr/bin/xcrun clang -o $@ $<",
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
