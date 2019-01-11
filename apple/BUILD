package(default_visibility = ["//visibility:public"])

licenses(["notice"])

[
    config_setting(
        name = arch,
        values = {"cpu": arch},
    )
    for arch in [
        "darwin_x86_64",
        "ios_i386",
        "ios_x86_64",
        "ios_armv7",
        "ios_arm64",
        "tvos_x86_64",
        "tvos_arm64",
        "watchos_i386",
        "watchos_armv7k",
    ]
]

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]) + [
        "//apple/bundling:for_bazel_tests",
        "//apple/internal:for_bazel_tests",
        "//apple/testing:for_bazel_tests",
    ],
    visibility = ["//:__pkg__"],
)
