load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("//apple:ios.bzl", "ios_application", "ios_ui_test", "ios_unit_test")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

licenses(["notice"])

swift_library(
    name = "Sources",
    srcs = [
        "Sources/AppDelegate.swift",
    ],
    data = [
        "Resources/Main.storyboard",
    ],
    module_name = "Sources",
    tags = ["manual"],
)

swift_library(
    name = "Tests",
    testonly = True,
    srcs = [
        "Tests/Tests.swift",
    ],
    tags = ["manual"],
    deps = [
        ":Sources",
    ],
)

# Pass the depending UI test's name as module_name to support test_filter
swift_library(
    name = "UITests",
    testonly = True,
    srcs = [
        "Tests/UITests.swift",
    ],
    module_name = "HelloWorldSwiftUITests",
    tags = ["manual"],
)

ios_unit_test(
    name = "UnitTests",
    minimum_os_version = "15.0",
    deps = [":Tests"],
)

genrule(
    name = "CreateTestCoverageManifest",
    srcs = ["Sources/AppDelegate.swift"],
    outs = [
        "CoverageManifest.instrumented_files",
    ],
    cmd = "echo $(SRCS) > $@",
)

ios_unit_test(
    name = "UnitTestsWithCoverageManifest",
    minimum_os_version = "15.0",
    test_coverage_manifest = "CoverageManifest.instrumented_files",
    deps = [":Tests"],
)

ios_application(
    name = "HelloWorldSwift",
    app_icons = ["//examples/resources:PhoneAppIcon.xcassets"],
    bundle_id = "com.example.hello-world-swift",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [":Info.plist"],
    launch_storyboard = "//examples/resources:Launch.storyboard",
    minimum_os_version = "15.0",
    deps = [":Sources"],
)

# Not normally needed, just done for rules_apple's examples so a
# 'bazel test examples/...' ensures all Examples still build.
build_test(
    name = "ExamplesBuildTest",
    targets = [":HelloWorldSwift"],
)

ios_ui_test(
    name = "HelloWorldSwiftUITests",
    minimum_os_version = "15.0",
    runner = "@build_bazel_rules_apple//apple/testing/default_runner:ios_xctestrun_ordered_runner",
    test_host = ":HelloWorldSwift",
    deps = [":UITests"],
)
