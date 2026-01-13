load("@bazel_skylib//rules:build_test.bzl", "build_test")
load(
    "@build_bazel_rules_swift//swift:swift_library.bzl",
    "swift_library",
)
load(
    "//apple:ios.bzl",
    "ios_application",
)
load(
    "//apple:versioning.bzl",
    "apple_bundle_version",
)
load(
    "//apple:watchos.bzl",
    "watchos_application",
)

licenses(["notice"])

swift_library(
    name = "PhoneSources",
    srcs = [
        "PhoneSources/ContentView.swift",
        "PhoneSources/HelloWorld.swift",
    ],
)

swift_library(
    name = "WatchSources",
    srcs = [
        "WatchSources/ContentView.swift",
        "WatchSources/HelloWorld.swift",
    ],
)

apple_bundle_version(
    name = "HelloWorldVersion",
    build_version = "1.0",
)

ios_application(
    name = "HelloWorld-WatchHost",
    app_icons = ["//examples/resources:PhoneAppIcon.xcassets"],
    bundle_id = "com.example.hello-world",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [":Phone-Info.plist"],
    launch_storyboard = "//examples/resources:Launch.storyboard",
    minimum_os_version = "15.0",
    version = ":HelloWorldVersion",
    watch_application = ":HelloWorld-WatchApplication",
    deps = [":PhoneSources"],
)

watchos_application(
    name = "HelloWorld-WatchApplication",
    app_icons = ["//examples/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.example.hello-world.watch",
    infoplists = [":WatchApp-Info.plist"],
    minimum_os_version = "9.0",
    version = ":HelloWorldVersion",
    deps = [":WatchSources"],
)

# Not normally needed, just done for rules_apple's examples so a
# 'bazel test examples/...' ensures all Examples still build.
build_test(
    name = "ExamplesBuildTest",
    targets = [
        ":HelloWorld-WatchHost",
        ":HelloWorld-WatchApplication",
    ],
)
