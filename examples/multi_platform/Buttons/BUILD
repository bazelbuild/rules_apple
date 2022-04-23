load("@bazel_skylib//rules:build_test.bzl", "build_test")
load(
    "//apple:ios.bzl",
    "ios_application",
    "ios_extension",
    "ios_static_framework",
    "ios_ui_test",
    "ios_unit_test",
)
load(
    "//apple:macos.bzl",
    "macos_application",
    # Enable when macos_test_runner supports macOS UI Tests.
    # "macos_ui_test",
    "macos_unit_test",
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
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "swift_library",
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

swift_library(
    name = "ButtonsTestsLib",
    srcs = [
        "ButtonsTests/ButtonsTests.swift",
    ],
    module_name = "ButtonsTests",
    deps = [
        ":ButtonsLib",
    ],
)

swift_library(
    name = "ButtonsUITestsLib",
    srcs = [
        "ButtonsUITests/ButtonsUITests.swift",
    ],
    module_name = "ButtonsUITests",
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
    infoplists = ["Buttons/Info.plist"],
    minimum_os_version = "8.0",
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
    minimum_os_version = "9.0",
    deps = [":ButtonsExtensionLib"],
)

ios_static_framework(
    name = "ButtonsStaticFramework",
    bundle_name = "Buttons",
    minimum_os_version = "8.0",
    deps = [":ButtonsLib"],
)

## Tests

ios_unit_test(
    name = "ButtonsTests",
    minimum_os_version = "9.0",
    test_host = ":Buttons",
    deps = [":ButtonsTestsLib"],
)

ios_unit_test(
    name = "ButtonsLogicTests",
    minimum_os_version = "9.0",
    deps = [":ButtonsTestsLib"],
)

ios_ui_test(
    name = "ButtonsUITests",
    minimum_os_version = "9.0",
    test_host = ":Buttons",
    deps = [":ButtonsUITestsLib"],
)

test_suite(
    name = "iOSButtonsTestSuite",
    tests = [
        ":ButtonsLogicTests",
        ":ButtonsTests",
        ":ButtonsUITests",
    ],
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

## Resources

objc_library(
    name = "ButtonsWatchResources",
    data = ["ButtonsWatch/Base.lproj/Interface.storyboard"],
)

## Packaging

watchos_application(
    name = "ButtonsWatch",
    bundle_id = "com.google.Buttons.watchkitapp",
    extension = ":ButtonsWatchExtension",
    infoplists = ["ButtonsWatch/Info.plist"],
    minimum_os_version = "3.0",
    deps = [
        ":ButtonsWatchResources",
    ],
)

watchos_extension(
    name = "ButtonsWatchExtension",
    bundle_id = "com.google.Buttons.watchkitapp.watchkitextension",
    infoplists = ["ButtonsWatchExtension/Info.plist"],
    minimum_os_version = "3.0",
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

swift_library(
    name = "ButtonsTVTestsLib",
    srcs = [
        "ButtonsTVTests/ButtonsTVTests.swift",
    ],
)

swift_library(
    name = "ButtonsTVUITestsLib",
    srcs = [
        "ButtonsTVUITests/ButtonsTVUITests.swift",
    ],
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
    minimum_os_version = "10.2",
    deps = [
        ":ButtonsTVLib",
        ":ButtonsTVResources",
    ],
)

tvos_extension(
    name = "ButtonsTVExtension",
    bundle_id = "com.google.ButtonsTV.ButtonsTVExtension",
    infoplists = ["ButtonsTVExtension/Info.plist"],
    minimum_os_version = "10.2",
    deps = [":ButtonsTVExtensionLib"],
)

tvos_static_framework(
    name = "ButtonsTVStaticFramework",
    bundle_name = "ButtonsTV",
    minimum_os_version = "10.0",
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

swift_library(
    name = "ButtonsMacTestsLib",
    srcs = [
        "ButtonsMacTests/ButtonsMacTests.swift",
    ],
    module_name = "ButtonsMacTests",
    deps = [
        ":ButtonsMacLib",
    ],
)

swift_library(
    name = "ButtonsMacUITestsLib",
    srcs = [
        "ButtonsMacUITests/ButtonsMacUITests.swift",
    ],
    module_name = "ButtonsMacUITests",
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
    infoplists = ["ButtonsMac/Info.plist"],
    minimum_os_version = "10.10",
    deps = [
        ":ButtonsMacLib",
        ":ButtonsMacResources",
    ],
)

## Tests

macos_unit_test(
    name = "ButtonsMacLogicTests",
    bundle_id = "com.google.logic",
    minimum_os_version = "10.10",
    tags = ["manual"],  # https://github.com/bazelbuild/continuous-integration/issues/1273
    deps = [":ButtonsMacTestsLib"],
)

macos_unit_test(
    name = "ButtonsMacTests",
    minimum_os_version = "10.10",
    tags = ["manual"],
    test_host = ":ButtonsMac",
    deps = [":ButtonsMacTestsLib"],
)

# Enable when macos_test_runner supports macOS UI Tests.
# macos_ui_test(
#     name = "ButtonsMacUITests",
#     minimum_os_version = "10.11",
#     test_host = ":ButtonsMac",
#     deps = [":ButtonsMacUITestsLib"],
# )

test_suite(
    name = "macOSButtonsTestSuite",
    tests = [
        # ":ButtonsMacLogicTests",
        # ":ButtonsMacTests",
        # ":ButtonsMacUITests",
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
        ":ButtonsStaticFramework",
        ":ButtonsExtension",
        ":ButtonsMac",
        ":ButtonsTV",
        ":ButtonsTVExtension",
        ":ButtonsTVStaticFramework",
        ":ButtonsWatch",
        ":ButtonsWatchExtension",
    ],
)
