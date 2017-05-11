package(default_visibility = ["//visibility:public"])

licenses(["notice"])

load("//apple:ios.bzl", "ios_application")
load("//apple:swift.bzl", "swift_library")

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
    bundle_id = "com.example.hello-world-swift",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [":Info.plist"],
    minimum_os_version = "8.0",
    deps = [":Sources"],
)
