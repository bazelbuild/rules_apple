package(default_visibility = ["//visibility:public"])

licenses(["notice"])

load("//apple:ios.bzl", "ios_application")

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

ios_application(
    name = "HelloWorld",
    bundle_id = "com.example.hello-world",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [":Info.plist"],
    deps = [":Sources"],
)
