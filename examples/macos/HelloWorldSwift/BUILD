load(
    "//apple:macos.bzl",
    "macos_application",
)
load(
    "//apple:versioning.bzl",
    "apple_bundle_version",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "swift_library",
)

package(default_visibility = ["//visibility:public"])

licenses(["notice"])

swift_library(
    name = "Sources",
    srcs = ["Sources/AppDelegate.swift"],
    resources = [
        "Resources/Main.storyboard",
    ],
)

apple_bundle_version(
    name = "HelloWorldSwiftVersion",
    build_version = "1.0",
)

macos_application(
    name = "HelloWorldSwift",
    app_icons = ["//examples/resources:MacAppIcon.xcassets"],
    bundle_id = "com.example.hello-world-swift",
    infoplists = [":Info.plist"],
    minimum_os_version = "10.11",
    version = ":HelloWorldSwiftVersion",
    deps = [":Sources"],
)
