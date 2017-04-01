package(default_visibility = ["//visibility:public"])

filegroup(
    name = "rules",
    srcs = glob(["*.bzl"]),
)

[
    config_setting(
        name = "ios_cpu_" + arch,
        values = {"ios_cpu": arch},
    )
    for arch in [
        "i386",
        "x86_64",
        "armv7",
        "arm64",
    ]
]

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]) + [
        "//apple/bundling:for_bazel_tests",
    ],
    visibility = ["//test:__subpackages__"],
)
