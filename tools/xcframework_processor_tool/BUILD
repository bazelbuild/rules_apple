load("@build_bazel_rules_swift//swift:swift_binary.bzl", "swift_binary")
load("@build_bazel_rules_swift//swift:swift_library.bzl", "swift_library")
load("//apple:apple.bzl", "apple_universal_binary")

licenses(["notice"])

apple_universal_binary(
    name = "xcframework_processor_tool_osx",
    binary = ":xcframework_processor_tool_swift",
    forced_cpus = [
        "x86_64",
        "arm64",
    ],
    minimum_os_version = "13.0",
    platform_type = "macos",
    visibility = [
        "//apple/internal/toolchains:__pkg__",
    ],
)

swift_binary(
    name = "xcframework_processor_tool_swift",
    srcs = [
        "ValidateRootInfoPlist.swift",
        "XCFrameworkProcessorTool.swift",
    ],
    tags = [
        "manual",
        "notap",
    ],
    target_compatible_with = ["@platforms//os:macos"],
    deps = [
        ":validate_library_identifier",
        ":validate_root_info_plist_options",
    ],
)

swift_library(
    name = "validate_library_identifier",
    srcs = [
        "ValidateLibraryIdentifier.swift",
    ],
)

swift_library(
    name = "validate_root_info_plist_options",
    srcs = [
        "ValidateRootInfoPlistOptions.swift",
    ],
)
