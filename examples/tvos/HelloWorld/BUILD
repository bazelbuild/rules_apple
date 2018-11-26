load(
    "//apple:tvos.bzl",
    "tvos_application",
)
load(
    "//apple:versioning.bzl",
    "apple_bundle_version",
)

package(default_visibility = ["//visibility:public"])

licenses(["notice"])

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

tvos_application(
    name = "HelloWorld",
    app_icons = ["//examples/resources:TVBrandAssets.xcassets"],
    bundle_id = "com.example.hello-world",
    infoplists = [":Info.plist"],
    minimum_os_version = "9.0",
    version = ":HelloWorldVersion",
    deps = [":Sources"],
)
