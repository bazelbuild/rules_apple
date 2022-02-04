load("//apple:ios.bzl", "ios_unit_test")

licenses(["notice"])

objc_library(
    name = "SquarerLib",
    srcs = ["Sources/Squarer.m"],
    hdrs = ["Sources/Squarer.h"],
)

objc_library(
    name = "SquarerTestsLib",
    srcs = ["Tests/SquarerTests.m"],
    deps = [":SquarerLib"],
)

ios_unit_test(
    name = "SquarerTests",
    minimum_os_version = "8.0",
    deps = [":SquarerTestsLib"],
)
