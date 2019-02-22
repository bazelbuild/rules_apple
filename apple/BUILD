licenses(["notice"])

# Create a set of public config_settings that can be used in select()s.
[
    config_setting(
        name = arch,
        values = {"cpu": arch},
        visibility = ["//visibility:public"],
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
        "//apple/internal:for_bazel_tests",
        "//apple/testing:for_bazel_tests",
    ],
    visibility = ["//:__pkg__"],
)
