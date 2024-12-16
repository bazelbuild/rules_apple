load(
    "@build_bazel_rules_swift//swift:swift_library.bzl",
    "swift_library",
)
load(
    "//apple:watchos.bzl",
    "watchos_application",
    "watchos_extension",
)
load(
    "//test/starlark_tests:common.bzl",
    "common",
)

licenses(["notice"])

package(
    default_applicable_licenses = ["//:license"],
    default_testonly = 1,
    default_visibility = ["//test/starlark_tests:__subpackages__"],
)

# ---------------------------------------------------------------------------------------
# Targets for custom extensions - focusing on WidgetKit complications.

watchos_application(
    name = "single_target_app_with_widgetkit_extension",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example.watchkitapp",
    extensions = [":sample_widgetkit_extension"],
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        ":sample_widgetkit_app_lib",
    ],
)

watchos_extension(
    name = "sample_widgetkit_extension",
    bundle_id = "com.google.example.watchkitapp.widgetkitextension",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        ":WidgetKitExtensionInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        ":sample_widgetkit_extension_lib",
    ],
)

swift_library(
    name = "sample_widgetkit_app_lib",
    srcs = [
        "ContentView.swift",
        "SampleWidgetKitApp.swift",
    ],
    tags = common.fixture_tags,
    deps = [
    ],
)

swift_library(
    name = "sample_widgetkit_extension_lib",
    srcs = ["WidgetKitComplications.swift"],
    tags = common.fixture_tags,
    deps = [
    ],
)
