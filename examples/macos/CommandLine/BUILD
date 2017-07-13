package(default_visibility = ["//visibility:public"])

licenses(["notice"])

load(
    "//apple:macos.bzl",
    "macos_command_line_application",
)
load(
    "//apple:versioning.bzl",
    "apple_bundle_version",
)

objc_library(
    name = "Sources",
    srcs = ["Sources/main.m"],
)

apple_bundle_version(
    name = "CommandLineVersion",
    build_version = "1.0",
)

macos_command_line_application(
    name = "CommandLine",
    bundle_id = "com.example.command-line",
    infoplists = [":Info.plist"],
    minimum_os_version = "10.11",
    version = ":CommandLineVersion",
    deps = [":Sources"],
)
