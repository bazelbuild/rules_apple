load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("//apple:ios.bzl", "ios_application", "ios_ui_test")
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
    minimum_os_version = "8.0",
    deps = [":Sources"],
)

swift_library(
    name = "TestLib",
    srcs = ["UITests/Test.swift"],
    module_name = "HelloWorldSwiftUITests",
)

ios_ui_test(
    name = "HelloWorldSwiftUITests",
    minimum_os_version = "8.0",
    test_host = ":HelloWorldSwift",
    deps = [":TestLib"],
)

# Not normally needed, just done for rules_apple's examples so a
# 'bazel test examples/...' ensures all Examples still build.
build_test(
    name = "ExamplesBuildTest",
    targets = [":HelloWorldSwift"],
)
