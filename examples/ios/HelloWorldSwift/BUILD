load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@build_bazel_rules_swift//swift:swift_library.bzl", "swift_library")
load("//apple:ios.bzl", "ios_application")

licenses(["notice"])

swift_library(
    name = "Sources",
    srcs = [
        "Sources/ContentView.swift",
        "Sources/HelloWorldApp.swift",
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
    minimum_os_version = "15.0",
    deps = [":Sources"],
)

# Not normally needed, just done for rules_apple's examples so a
# 'bazel test examples/...' ensures all Examples still build.
build_test(
    name = "ExamplesBuildTest",
    targets = [":HelloWorldSwift"],
)
