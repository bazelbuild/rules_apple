package(default_visibility = ["//visibility:public"])

licenses(["notice"])

exports_files([
    "ios_sample_test_runner.template.sh",
    "macos_test_runner.template.sh",
    "macos_test_runner.template.xctestrun",
])

load(
    "//apple/testing/default_runner:ios_sample_test_runner.bzl",
    "ios_sample_test_runner",
)
load(
    "//apple/testing/default_runner:macos_test_runner.bzl",
    "macos_test_runner",
)

ios_sample_test_runner(
    name = "ios_default_runner",
)

macos_test_runner(
    name = "macos_default_runner",
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
