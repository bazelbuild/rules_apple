package(default_visibility = ["//visibility:public"])

licenses(["notice"])

load(
    "//apple:macos.bzl",
    "macos_application",
)
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

macos_application(
    name = "HelloWorld",
    bundle_id = "com.example.hello-world",
    infoplists = [":Info.plist"],
    minimum_os_version = "10.11",
    version = ":HelloWorldVersion",
    deps = [":Sources"],
)
