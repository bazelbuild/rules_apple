load(
    "@build_bazel_apple_support//rules:apple_genrule.bzl",
    "apple_genrule",
)

licenses(["notice"])

# This target will only build on a Mac.
apple_genrule(
    name = "realpath_genrule",
    srcs = ["realpath.c"],
    outs = ["realpath"],
    cmd = "/usr/bin/xcrun clang -o $@ $<",
    # Used by the rule implementations, so it needs to be public.
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
