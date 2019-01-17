load(
    "//apple:macos.bzl",
    "macos_application",
    "macos_extension",
)
load(
    "//apple:versioning.bzl",
    "apple_bundle_version",
)

package(default_visibility = ["//visibility:public"])

licenses(["notice"])

objc_library(
    name = "AppSources",
    srcs = [
        "AppSources/AppDelegate.h",
        "AppSources/AppDelegate.m",
        "AppSources/ViewController.h",
        "AppSources/ViewController.m",
        "AppSources/main.m",
    ],
    resources = [
        "AppResources/Main.storyboard",
    ],
)

objc_library(
    name = "ExtSources",
    srcs = [
        "ExtSources/TodayViewController.h",
        "ExtSources/TodayViewController.m",
    ],
    resources = [
        "ExtResources/TodayViewController.xib",
    ],
    sdk_frameworks = [
        "NotificationCenter",
    ],
)

apple_bundle_version(
    name = "HelloTodayVersion",
    build_version = "1.0",
)

macos_application(
    name = "HelloToday",
    app_icons = ["//examples/resources:MacAppIcon.xcassets"],
    bundle_id = "com.example.hello-today",
    extensions = [
        ":TodayExtension",
    ],
    infoplists = [":App-Info.plist"],
    minimum_os_version = "10.11",
    version = ":HelloTodayVersion",
    deps = [":AppSources"],
)

macos_extension(
    name = "TodayExtension",
    bundle_id = "com.example.hello-today.today-extension",
    entitlements = ":Ext-Entitlements.entitlements",
    infoplists = [":Ext-Info.plist"],
    minimum_os_version = "10.11",
    version = ":HelloTodayVersion",
    deps = [":ExtSources"],
)
