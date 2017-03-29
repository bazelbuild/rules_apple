filegroup(
    name = "rules",
    srcs = glob(["*.bzl"]),
    visibility = ["//visibility:public"],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]) + [
        "//apple/bundling:for_bazel_tests",
    ],
    visibility = [
        "//test:__subpackages__",
    ],
)

[
    config_setting(
        name = "ios_cpu_" + arch,
        values = {"ios_cpu": arch},
        visibility = ["//visibility:public"],
    )
    for arch in [
        "i386",
        "x86_64",
        "armv7",
        "arm64",
    ]
]
