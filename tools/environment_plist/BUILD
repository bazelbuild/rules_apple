licenses(["notice"])

sh_binary(
    name = "environment_plist",
    srcs = ["environment_plist.sh"],
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
