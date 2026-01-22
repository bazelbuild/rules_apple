load("@bazel_skylib//rules:build_test.bzl", "build_test")
load(
    "@build_bazel_rules_swift//swift:swift_library.bzl",
    "swift_library",
)
load(
    "//apple:ios.bzl",
    "ios_application",
    "ios_imessage_extension",
)
load(
    "//apple:versioning.bzl",
    "apple_bundle_version",
)

licenses(["notice"])

apple_bundle_version(
    name = "iMessageAppVersion",
    build_version = "1.0",
)

swift_library(
    name = "iMessageExtensionLib",
    srcs = ["Sources/Extension/MessagesViewController.swift"],
    data = ["Sources/Extension/MainInterface.storyboard"],
)

ios_imessage_extension(
    name = "iMessageExtension",
    app_icons = glob(["iMessageExtensionAssets.xcassets/**"]),
    bundle_id = "com.google.iMessageApp.MessagesExtension",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = ["iMessageExtension-Info.plist"],
    minimum_os_version = "15.0",
    version = ":iMessageAppVersion",
    deps = [":iMessageExtensionLib"],
)

swift_library(
    name = "MessagesAppHost",
    srcs = [
        "Sources/AppHost/ContentView.swift",
        "Sources/AppHost/MessagesAppHost.swift",
    ],
)

ios_application(
    name = "iMessageApp",
    app_icons = glob(["iMessageAppAssets.xcassets/**"]),
    bundle_id = "com.google.iMessageApp",
    extensions = [":iMessageExtension"],
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = ["iMessageApp-Info.plist"],
    minimum_os_version = "15.0",
    version = ":iMessageAppVersion",
    deps = [":MessagesAppHost"],
)

# Not normally needed, just done for rules_apple's examples so a
# 'bazel test examples/...' ensures all Examples still build.
build_test(
    name = "ExamplesBuildTest",
    targets = [
        ":iMessageApp",
        ":iMessageExtension",
    ],
)
