load(
    "//apple:macos.bzl",
    "macos_command_line_application",
)
load(
    "//apple:versioning.bzl",
    "apple_bundle_version",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "swift_library",
)

package(default_visibility = ["//visibility:public"])

licenses(["notice"])

swift_library(
    name = "Sources",
    srcs = ["Sources/main.swift"],
)

apple_bundle_version(
    name = "CommandLineSwiftVersion",
    build_version = "1.0",
)

macos_command_line_application(
    name = "CommandLineSwift",
    bundle_id = "com.example.command-line-swift",
    infoplists = [":Info.plist"],
    minimum_os_version = "10.11",
    version = ":CommandLineSwiftVersion",
    deps = [":Sources"],
)
