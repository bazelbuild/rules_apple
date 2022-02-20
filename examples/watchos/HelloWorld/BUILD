load("@bazel_skylib//rules:build_test.bzl", "build_test")
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
    "watchos_extension",
)

licenses(["notice"])

objc_library(
    name = "PhoneSources",
    srcs = [
        "PhoneSources/AppDelegate.h",
        "PhoneSources/AppDelegate.m",
        "PhoneSources/ViewController.h",
        "PhoneSources/ViewController.m",
        "PhoneSources/main.m",
    ],
    data = [
        "PhoneResources/Main.storyboard",
    ],
    sdk_frameworks = [
        "WatchConnectivity",
    ],
)

objc_library(
    name = "WatchSources",
    srcs = [
        "WatchSources/ExtensionDelegate.h",
        "WatchSources/ExtensionDelegate.m",
        "WatchSources/InterfaceController.h",
        "WatchSources/InterfaceController.m",
    ],
    sdk_frameworks = [
        "WatchConnectivity",
        "WatchKit",
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
    infoplists = [":Phone-Info.plist"],
    launch_storyboard = "//examples/resources:Launch.storyboard",
    minimum_os_version = "9.0",
    version = ":HelloWorldVersion",
    watch_application = ":HelloWorld-WatchApplication",
    deps = [":PhoneSources"],
)

watchos_application(
    name = "HelloWorld-WatchApplication",
    app_icons = ["//examples/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.example.hello-world.watch",
    extension = ":HelloWorld-WatchExtension",
    infoplists = [":WatchApp-Info.plist"],
    minimum_os_version = "2.0",
    storyboards = [
        "WatchResources/Interface.storyboard",
    ],
    version = ":HelloWorldVersion",
)

watchos_extension(
    name = "HelloWorld-WatchExtension",
    bundle_id = "com.example.hello-world.watch.extension",
    infoplists = [":WatchExt-Info.plist"],
    minimum_os_version = "2.0",
    version = ":HelloWorldVersion",
    deps = [":WatchSources"],
)

# Not normally needed, just done for rules_apple's examples so a
# 'bazel test examples/...' ensures all Examples still build.
build_test(
    name = "ExamplesBuildTest",
    targets = [
        ":HelloWorld",
        ":HelloWorld-WatchApplication",
        ":HelloWorld-WatchExtension",
    ],
)
