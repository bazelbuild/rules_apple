package(default_visibility = ["//apple:__subpackages__"])

licenses(["notice"])

filegroup(
    name = "bundling",
    srcs = glob(["*.bzl"]),
)

filegroup(
    name = "dsym_info_plist_template",
    srcs = ["dSYM-Info.plist.template"],
    visibility = ["//visibility:public"],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]) + [
        "//apple/bundling/runners:for_bazel_tests",
    ],
    visibility = [
        "//apple:__subpackages__",
    ],
)
