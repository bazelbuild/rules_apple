load("@bazel_skylib//rules:build_test.bzl", "build_test")
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
load(
    "@build_bazel_rules_apple//apple:macos.bzl",
    "macos_unit_test",
)

licenses(["notice"])

swift_library(
    name = "Sources",
    module_name = "Sources",
    srcs = [
        "Sources/main.swift",
        "Sources/Logger.swift"
    ],
)

swift_library(
    name = "SourcesTests",
    srcs = [
        "Tests/LoggerTests.swift",
        "Tests/MockLog.swift"
    ],
    deps = [
        ":Sources"
    ]
)

macos_unit_test(
    name = "SourcesUnitTests",
    deps = [":SourcesTests"],
    minimum_os_version = "12.0"
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

# Not normally needed, just done for rules_apple's examples so a
# 'bazel test examples/...' ensures all Examples still build.
build_test(
    name = "ExamplesBuildTest",
    targets = [":CommandLineSwift"],
)
