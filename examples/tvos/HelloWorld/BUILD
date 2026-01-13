load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@build_bazel_rules_swift//swift:swift_library.bzl", "swift_library")
load(
    "//apple:tvos.bzl",
    "tvos_application",
)
load(
    "//apple:versioning.bzl",
    "apple_bundle_version",
)

licenses(["notice"])

swift_library(
    name = "Sources",
    srcs = [
        "Sources/ContentView.swift",
        "Sources/HelloWorld.swift",
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
    minimum_os_version = "15.0",
    version = ":HelloWorldVersion",
    deps = [":Sources"],
)

# Not normally needed, just done for rules_apple's examples so a
# 'bazel test examples/...' ensures all Examples still build.
build_test(
    name = "ExamplesBuildTest",
    targets = [":HelloWorld"],
)
