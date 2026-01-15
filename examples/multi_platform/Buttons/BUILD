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
    "//apple:macos.bzl",
    "macos_application",
)
load(
    "//apple:tvos.bzl",
    "tvos_application",
)
load(
    "//apple:watchos.bzl",
    "watchos_application",
)

licenses(["notice"])

# Shared

## Code

swift_library(
    name = "Buttons",
    srcs = [
        "Buttons/Buttons.swift",
        "Buttons/ContentView.swift",
    ],
)

# iOS

## Packaging

ios_application(
    name = "ButtonsIOS",
    bundle_id = "com.google.Buttons",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = ["Buttons/Info.plist"],
    minimum_os_version = "15.0",
    watch_application = ":ButtonsWatch",
    deps = [
        ":Buttons",
    ],
)

# watchOS

## Packaging

watchos_application(
    name = "ButtonsWatch",
    bundle_id = "com.google.Buttons.watchkitapp",
    infoplists = ["ButtonsWatch/Info.plist"],
    minimum_os_version = "9.0",
    deps = [
        ":Buttons",
    ],
)

# tvOS

## Packaging

tvos_application(
    name = "ButtonsTV",
    bundle_id = "com.google.ButtonsTV",
    infoplists = ["ButtonsTV/Info.plist"],
    minimum_os_version = "15.0",
    deps = [
        ":Buttons",
    ],
)

# macOS

## Packaging

macos_application(
    name = "ButtonsMac",
    bundle_id = "com.google.ButtonsMac",
    infoplists = ["ButtonsMac/Info.plist"],
    minimum_os_version = "12.0",
    deps = [
        ":Buttons",
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
        ":ButtonsIOS",
        ":ButtonsMac",
        ":ButtonsTV",
        ":ButtonsWatch",
    ],
)
