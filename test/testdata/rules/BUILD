load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(default_visibility = ["//test:__subpackages__"])

licenses(["notice"])

filegroup(
    name = "dummy_runner",
    srcs = [
        "BUILD",
        "dummy_test_runner.bzl",
        "dummy_test_runner.template",
    ],
)

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
