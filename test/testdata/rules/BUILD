load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package()

licenses(["notice"])

exports_files(
    [
        "dummy_test_runner.template",
    ],
    visibility = ["//test:__subpackages__"],
)

bzl_library(
    name = "dummy_test_runner",
    srcs = ["dummy_test_runner.bzl"],
    visibility = ["//visibility:private"],
    deps = [
        "//apple:providers",
    ],
)
