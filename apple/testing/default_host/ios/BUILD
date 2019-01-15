load("//apple:ios.bzl", "ios_application")

# TODO(thomasvl): Remove this whole subpackage.

package(default_visibility = ["//visibility:public"])

licenses(["notice"])

objc_library(
    name = "Main",
    testonly = 1,
    srcs = ["main.m"],
)

# Default test host for unit tests.
ios_application(
    name = "ios",
    testonly = 1,
    bundle_id = "com.google.skylark.testing.DefaultTestHost",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = ["TestHost.plist"],
    launch_storyboard = "LaunchScreen.storyboard",
    minimum_os_version = "8.0",
    visibility = ["//visibility:public"],
    deps = [":Main"],
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
