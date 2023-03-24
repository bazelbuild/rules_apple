load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("//apple:ios.bzl", "ios_application")
load(
    "//apple:versioning.bzl",
    "apple_bundle_version",
)

licenses(["notice"])

objc_library(
    name = "Sources",
    srcs = [
        "Sources/AppDelegate.h",
        "Sources/AppDelegate.m",
        "Sources/main.m",
    ],
    data = [
        "Resources/Main.storyboard",
    ],
)

apple_bundle_version(
    name = "HelloWorldVersion",
    build_version = "1.0",
)

ios_application(
    name = "HelloWorld",
    app_icons = ["//examples/resources:PhoneAppIcon.xcassets"],
    bundle_id = "com.example.hello-world",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [":Info.plist"],
    launch_storyboard = "//examples/resources:Launch.storyboard",
    minimum_os_version = "8.0",
    version = ":HelloWorldVersion",
    deps = [":Sources"],
)

# Not normally needed, just done for rules_apple's examples so a
# 'bazel test examples/...' ensures all Examples still build.
build_test(
    name = "ExamplesBuildTest",
    targets = [":HelloWorld"],
)

# Example of using a custom linker

cc_library(
    name = "lld_linkopt",
    linkopts = ["--ld-path=external/com_github_keith_ld64.lld/ld64.lld"],
)

ios_application(
    name = "HelloWorld_with_lld",
    additional_linker_inputs = ["@com_github_keith_ld64.lld//:lld_bin"],
    app_icons = ["//examples/resources:PhoneAppIcon.xcassets"],
    bundle_id = "com.example.hello-world",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [":Info.plist"],
    launch_storyboard = "//examples/resources:Launch.storyboard",
    minimum_os_version = "8.0",
    version = ":HelloWorldVersion",
    deps = [
        ":Sources",
        ":lld_linkopt",
    ],
)
