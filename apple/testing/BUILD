load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

licenses(["notice"])

bzl_library(
    name = "apple_test_rules",
    srcs = ["apple_test_rules.bzl"],
    visibility = [
        "//apple/testing:__subpackages__",
        "//test:__subpackages__",
    ],
    deps = [
        "//apple:providers",
        "//apple/internal/testing:apple_test_rule_support",
    ],
)

filegroup(
    name = "DefaultTestBundlePlist",
    srcs = [
        "DefaultTestBundle.plist",
    ],
    # Used by the rule implementations, so it needs to be public; but
    # should be considered an implementation detail of the rules and
    # not used by other things.
    visibility = ["//visibility:public"],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]) + [
        "//apple/testing/default_runner:for_bazel_tests",
    ],
    visibility = ["//:__subpackages__"],
)
