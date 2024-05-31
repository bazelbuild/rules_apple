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

py_binary(
    name = "xcframework_processor_tool",
    srcs = ["xcframework_processor_tool.py"],
    python_version = "PY3",
    srcs_version = "PY3",
    visibility = [
        "//apple/internal/toolchains:__pkg__",
    ],
    deps = [":xcframework_processor_tool_lib"],
)

py_library(
    name = "xcframework_processor_tool_lib",
    srcs = ["xcframework_processor_tool.py"],
    srcs_version = "PY3",
    visibility = [
        "//tools:__subpackages__",
    ],
)

py_test(
    name = "xcframework_processor_tool_test",
    srcs = ["xcframework_processor_tool_test.py"],
    python_version = "PY3",
    tags = ["requires-darwin"],
    deps = [":xcframework_processor_tool_lib"],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = [
        "BUILD",
        "xcframework_processor_tool.py",
        "xcframework_processor_tool_test.py",
    ],
    visibility = [
        "//tools:__pkg__",
    ],
)
