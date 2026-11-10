load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

licenses(["notice"])

sh_binary(
    name = "environment_plist",
    srcs = ["environment_plist.sh"],
    data = ["//apple:sdk_tool_files"],
    visibility = [
        "//apple/internal:__pkg__",
    ],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = True,
    srcs = glob(["**"]),
    visibility = [
        "//tools:__pkg__",
    ],
)
