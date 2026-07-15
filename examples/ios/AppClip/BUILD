load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@rules_swift//swift:swift.bzl", "swift_library")
load(
    "//apple:ios.bzl",
    "ios_app_clip",
    "ios_application",
)
load("//apple:versioning.bzl", "apple_bundle_version")

licenses(["notice"])

apple_bundle_version(
    name = "Version",
    build_version = "1.0",
)

swift_library(
    name = "HostAppSources",
    srcs = ["Sources/HostApp.swift"],
    tags = ["manual"],
)

swift_library(
    name = "AppClipSources",
    srcs = ["Sources/AppClip.swift"],
    tags = ["manual"],
)

ios_app_clip(
    name = "ExampleAppClip",
    app_icons = ["//examples/resources:PhoneAppIcon.xcassets"],
    bundle_id = "com.example.app-clip-example.Clip",
    families = ["iphone"],
    infoplists = [":AppClip-Info.plist"],
    minimum_os_version = "14.0",
    version = ":Version",
    deps = [":AppClipSources"],
)

ios_application(
    name = "HostApp",
    app_clips = [":ExampleAppClip"],
    app_icons = ["//examples/resources:PhoneAppIcon.xcassets"],
    bundle_id = "com.example.app-clip-example",
    families = ["iphone"],
    infoplists = [":HostApp-Info.plist"],
    minimum_os_version = "14.0",
    version = ":Version",
    deps = [":HostAppSources"],
)

build_test(
    name = "ExamplesBuildTest",
    targets = [
        ":ExampleAppClip",
        ":HostApp",
    ],
)
