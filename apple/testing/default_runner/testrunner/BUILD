load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library", "swift_test")
load("//apple:macos.bzl", "macos_command_line_application")
load("@rules_xcodeproj//xcodeproj:defs.bzl", "xcodeproj")

xcodeproj(
    name = "xcodeproj",
    install_directory = package_name() + "/.ignored",
    project_name = "testrunner",
    tags = ["manual"],
    top_level_targets = [
        ":testrunner",
        ":TestRunnerKitTests",
    ],
)

macos_command_line_application(
    name = "testrunner",
    minimum_deployment_os_version = "13",
    minimum_os_version = "13",
    visibility = ["//visibility:public"],
    deps = [":TestRunnerMain"],
)

swift_library(
    name = "TestRunnerMain",
    srcs = glob(["TestRunnerMain/**/*.swift"]),
    module_name = "TestRunnerMain",
    deps = [
        ":TestRunnerCLI",
    ],
)

swift_library(
    name = "TestRunnerCLI",
    srcs = glob(["TestRunnerCLI/**/*.swift"]),
    module_name = "TestRunnerCLI",
    deps = [
        ":TestRunnerKit",
        "@com_github_apple_swift-argument-parser//:ArgumentParser",
    ],
)

swift_library(
    name = "TestRunnerKit",
    srcs = glob(["TestRunnerKit/**/*.swift"]),
    module_name = "TestRunnerKit",
    deps = [
        "@com_github_jakeheis_SwiftCLI//:SwiftCLI",  # Used only for executing shell commands from Swift code
        "@com_github_mtynior_ColorizeSwift//:ColorizeSwift",
    ],
)

swift_test(
    name = "TestRunnerKitTests",
    srcs = glob(["TestRunnerKitTests/**/*.swift"]),
    deps = [
        ":TestRunnerKit",
    ],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]),
    visibility = [
        "//:__subpackages__",
    ],
)
