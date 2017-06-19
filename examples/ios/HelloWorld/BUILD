package(default_visibility = ["//visibility:public"])

licenses(["notice"])

load("//apple:ios.bzl", "ios_application")
load(
    "//apple:versioning.bzl",
    "apple_bundle_version",
)

objc_library(
    name = "Sources",
    srcs = [
        "Sources/AppDelegate.h",
        "Sources/AppDelegate.m",
        "Sources/main.m",
    ],
    resources = [
        "Resources/Main.storyboard",
    ],
)

apple_bundle_version(
    name = "HelloWorldVersion",
    build_version = "1.0",
)

ios_application(
    name = "HelloWorld",
    bundle_id = "com.example.hello-world",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [":Info.plist"],
    minimum_os_version = "8.0",
    version = ":HelloWorldVersion",
    deps = [":Sources"],
)
