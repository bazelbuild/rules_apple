licenses(["notice"])

filegroup(
    name = "apple_simulator_template",
    srcs = ["apple_simulator.template.py"],
    visibility = ["//apple/internal:__pkg__"],
)

filegroup(
    name = "macos_template",
    srcs = ["macos.template.sh"],
    visibility = ["//apple/internal:__pkg__"],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]),
    visibility = [
        "//apple:__subpackages__",
    ],
)
