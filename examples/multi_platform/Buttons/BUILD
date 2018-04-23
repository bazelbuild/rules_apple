package(
    default_visibility = ["//visibility:public"],
)

licenses(["notice"])

load(
    "//apple:ios.bzl",
    "ios_application",
    "ios_extension",
    "ios_static_framework",
    "ios_unit_test",
    "ios_ui_test",
)
load(
    "//apple:watchos.bzl",
    "watchos_application",
    "watchos_extension",
)
load(
    "//apple:tvos.bzl",
    "tvos_application",
    "tvos_extension",
)
load(
    "//apple:macos.bzl",
    "macos_application",
    "macos_unit_test",
    "macos_ui_test",
)
load(
    "//apple:swift.bzl",
    "swift_library",
)

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
    name = "ButtonsTestsLib",
    srcs = [
        "ButtonsTests/ButtonsTests.swift",
    ],
    module_name = "ButtonsTests",
    deps = [":ButtonsLib"],
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
    storyboards = ["Buttons/Base.lproj/Main.storyboard"],
)

## Packaging

ios_application(
    name = "Buttons",
    bundle_id = "com.google.Buttons",
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

ios_static_framework(
    name = "ButtonsStaticFramework",
    bundle_name = "ButtonsStaticFramework",
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
    storyboards = ["ButtonsWatch/Base.lproj/Interface.storyboard"],
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
    storyboards = ["ButtonsTV/Base.lproj/Main.storyboard"],
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
    deps = [":ButtonsMacLib"],
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
    storyboards = ["ButtonsMac/Base.lproj/Main.storyboard"],
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
    deps = [":ButtonsMacTestsLib"],
)

macos_unit_test(
    name = "ButtonsMacTests",
    minimum_os_version = "10.10",
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
        ":ButtonsMacLogicTests",
        ":ButtonsMacTests",
        # ":ButtonsMacUITests",
    ],
)
