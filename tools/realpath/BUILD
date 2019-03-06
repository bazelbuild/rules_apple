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
    cmd = """
    /usr/bin/xcrun --sdk macosx clang -mmacosx-version-min=10.9 -o $@ $<
    """,
    # Used by the rule implementations, so it needs to be public; but
    # should be considered an implementation detail of the rules and
    # not used by other things.
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
