package(default_visibility = ["//apple:__subpackages__"])

licenses(["notice"])

filegroup(
    name = "bundler_py",
    srcs = ["bundler.py"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "bundling",
    srcs = glob(["*.bzl"]),
)

filegroup(
    name = "dsym_info_plist_template",
    srcs = ["dSYM-Info.plist.template"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "plisttool",
    srcs = ["plisttool.py"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "process_and_sign_template",
    srcs = ["process_and_sign.sh.template"],
    visibility = ["//visibility:public"],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]),
    visibility = [
        "//apple:__subpackages__",
        "//test:__subpackages__",
    ],
)
