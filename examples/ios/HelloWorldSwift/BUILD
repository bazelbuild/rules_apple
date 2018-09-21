package(default_visibility = ["//visibility:public"])

licenses(["notice"])

load("//apple:ios.bzl", "ios_application")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "Sources",
    srcs = [
        "Sources/AppDelegate.swift",
    ],
    resources = [
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
