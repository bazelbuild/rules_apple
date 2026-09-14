load("@rules_cc//cc:objc_library.bzl", "objc_library")
load("//apple:ios.bzl", "ios_unit_test")

platform(
    name = "linux",
    constraint_values = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
    ],
)

platform(
    name = "macos",
    constraint_values = [
        "@platforms//cpu:aarch64",
        "@platforms//os:macos",
    ],
)

objc_library(
    name = "test_lib",
    testonly = True,
    srcs = ["test.m"],
    sdk_frameworks = ["XCTest"],
    tags = ["manual"],
)

ios_unit_test(
    name = "unit_test",
    families = ["iphone"],
    minimum_os_version = "15.5",
    tags = ["manual"],
    deps = [":test_lib"],
)
