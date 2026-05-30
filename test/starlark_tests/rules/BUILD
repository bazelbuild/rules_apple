load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

exports_files(["apple_coverage_test_runner.sh"])

bzl_library(
    name = "test_rules",
    srcs = glob(
        include = ["*.bzl"],
    ),
    visibility = [
        "//test:__subpackages__",
    ],
    deps = [
        "//apple:providers",
        "//apple/build_settings",
        "//apple/internal:apple_product_type",
        "//apple/internal:intermediates",
        "//apple/internal:providers",
        "//apple/internal:shared_environment",
        "@apple_support//lib:apple_support",
        "@bazel_skylib//lib:dicts",
        "@bazel_skylib//lib:new_sets",
        "@bazel_skylib//lib:paths",
        "@bazel_skylib//lib:shell",
        "@bazel_skylib//lib:unittest",
        "@rules_swift//swift",
    ],
)

sh_binary(
    name = "generate_xcframework_xcodebuild_tool",
    srcs = ["generate_xcframework_xcodebuild_tool.sh"],
    tags = ["requires-darwin"],
)
