load("@bazel_skylib//rules:build_test.bzl", "build_test")
load(
    "@build_bazel_rules_swift//swift:swift_library.bzl",
    "swift_library",
)
load("@rules_cc//cc:objc_library.bzl", "objc_library")
load(
    "//apple:ios.bzl",
    "ios_application",
    "ios_extension",
)
load(
    "//apple:macos.bzl",
    "macos_application",
)
load(
    "//apple:tvos.bzl",
    "tvos_application",
    "tvos_extension",
    "tvos_static_framework",
)
load(
    "//apple:watchos.bzl",
    "watchos_application",
    "watchos_extension",
)

licenses(["notice"])

# iOS

## Code

swift_library(
    name = "ButtonsLib",
    srcs = [
        "Buttons/AppDelegate.swift",
        "Buttons/ViewController.swift",
    ],
    module_name = "Buttons",
)

swift_library(
    name = "ButtonsExtensionLib",
    srcs = [
        "ButtonsExtension/ActionRequestHandler.swift",
    ],
    module_name = "ButtonsExtension",
)

## Resources

objc_library(
    name = "ButtonsResources",
    data = ["Buttons/Base.lproj/Main.storyboard"],
)

## Packaging

ios_application(
    name = "Buttons",
    bundle_id = "com.google.Buttons",
    extensions = [":ButtonsExtension"],
    families = [
        "iphone",
        "ipad",
    ],
    features = ["exported_symbols"],
    infoplists = ["Buttons/Info.plist"],
    minimum_os_version = "12.0",
    watch_application = ":ButtonsWatch",
    deps = [
        ":ButtonsLib",
        ":ButtonsResources",
    ],
)

ios_extension(
    name = "ButtonsExtension",
    bundle_id = "com.google.Buttons.ButtonsExtension",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = ["ButtonsExtension/Info.plist"],
    minimum_os_version = "12.0",
    deps = [":ButtonsExtensionLib"],
)

# watchOS

## Code

swift_library(
    name = "ButtonsWatchExtensionLib",
    srcs = [
        "ButtonsWatchExtension/ComplicationController.swift",
        "ButtonsWatchExtension/ExtensionDelegate.swift",
        "ButtonsWatchExtension/InterfaceController.swift",
        "ButtonsWatchExtension/NotificationController.swift",
    ],
    module_name = "ButtonsWatchExtension",
)

## Packaging

watchos_application(
    name = "ButtonsWatch",
    bundle_id = "com.google.Buttons.watchkitapp",
    extension = ":ButtonsWatchExtension",
    infoplists = ["ButtonsWatch/Info.plist"],
    minimum_os_version = "4.0",
    resources = ["ButtonsWatch/Base.lproj/Interface.storyboard"],
)

watchos_extension(
    name = "ButtonsWatchExtension",
    bundle_id = "com.google.Buttons.watchkitapp.watchkitextension",
    infoplists = ["ButtonsWatchExtension/Info.plist"],
    minimum_os_version = "4.0",
    deps = [
        ":ButtonsWatchExtensionLib",
    ],
)

# tvOS

## Code

swift_library(
    name = "ButtonsTVLib",
    srcs = [
        "ButtonsTV/AppDelegate.swift",
        "ButtonsTV/ViewController.swift",
    ],
    module_name = "ButtonsTV",
)

swift_library(
    name = "ButtonsTVExtensionLib",
    srcs = [
        "ButtonsTVExtension/ServiceProvider.swift",
    ],
    module_name = "ButtonsTVExtension",
)

## Resources

objc_library(
    name = "ButtonsTVResources",
    data = ["ButtonsTV/Base.lproj/Main.storyboard"],
)

## Packaging

tvos_application(
    name = "ButtonsTV",
    bundle_id = "com.google.ButtonsTV",
    extensions = [":ButtonsTVExtension"],
    infoplists = ["ButtonsTV/Info.plist"],
    minimum_os_version = "12.0",
    deps = [
        ":ButtonsTVLib",
        ":ButtonsTVResources",
    ],
)

tvos_extension(
    name = "ButtonsTVExtension",
    bundle_id = "com.google.ButtonsTV.ButtonsTVExtension",
    infoplists = ["ButtonsTVExtension/Info.plist"],
    minimum_os_version = "12.0",
    deps = [":ButtonsTVExtensionLib"],
)

tvos_static_framework(
    name = "ButtonsTVStaticFramework",
    bundle_name = "ButtonsTV",
    minimum_os_version = "12.0",
    deps = [":ButtonsTVLib"],
)

# macOS

## Code

swift_library(
    name = "ButtonsMacLib",
    srcs = [
        "ButtonsMac/AppDelegate.swift",
        "ButtonsMac/ViewController.swift",
    ],
    module_name = "ButtonsMac",
)

## Resources

objc_library(
    name = "ButtonsMacResources",
    data = ["ButtonsMac/Base.lproj/Main.storyboard"],
)

## Packaging

macos_application(
    name = "ButtonsMac",
    bundle_id = "com.google.ButtonsMac",
    features = ["exported_symbols"],
    infoplists = ["ButtonsMac/Info.plist"],
    minimum_os_version = "10.13",
    deps = [
        ":ButtonsMacLib",
        ":ButtonsMacResources",
    ],
)

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
)

# Not normally needed, just done for rules_apple's examples so a
# 'bazel test examples/...' ensures all Examples still build.
build_test(
    name = "ExamplesBuildTest",
    targets = [
        ":Buttons",
        ":ButtonsExtension",
        ":ButtonsMac",
        ":ButtonsTV",
        ":ButtonsTVExtension",
        ":ButtonsWatch",
        ":ButtonsWatchExtension",
    ],
)
