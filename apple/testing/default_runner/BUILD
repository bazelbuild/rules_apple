load(
    "//apple/testing/default_runner:ios_test_runner.bzl",
    "ios_test_runner",
)
load(
    "//apple/testing/default_runner:macos_test_runner.bzl",
    "macos_test_runner",
)

licenses(["notice"])

exports_files([
    "ios_test_runner.template.sh",
    "macos_test_runner.template.sh",
    "macos_test_runner.template.xctestrun",
])

ios_test_runner(
    name = "ios_default_runner",
    # Used by the rule implementations, so it needs to be public.
    visibility = ["//visibility:public"],
)

macos_test_runner(
    name = "macos_default_runner",
    # Used by the rule implementations, so it needs to be public.
    visibility = ["//visibility:public"],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]) + [
    ],
    visibility = [
        "//:__subpackages__",
    ],
)
