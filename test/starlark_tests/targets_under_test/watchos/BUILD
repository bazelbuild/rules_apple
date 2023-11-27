load(
    "@build_bazel_rules_swift//swift:swift_library.bzl",
    "swift_library",
)
load(
    "//apple:apple.bzl",
    "apple_dynamic_framework_import",
    "apple_dynamic_xcframework_import",
    "apple_static_xcframework_import",
)
load(
    "//apple:ios.bzl",
    "ios_application",
)
load(
    "//apple:watchos.bzl",
    "watchos_application",
    "watchos_extension",
    "watchos_ui_test",
    "watchos_unit_test",
)
load(
    "//test/starlark_tests:common.bzl",
    "common",
)
load(
    "//test/starlark_tests/rules:generate_framework.bzl",
    "generate_import_framework",
)
load(
    "//test/starlark_tests/rules:generate_xcframework.bzl",
    "generate_dynamic_xcframework",
    "generate_static_xcframework",
)

licenses(["notice"])

package(
    default_testonly = 1,
    default_visibility = ["//test/starlark_tests:__subpackages__"],
)

watchos_application(
    name = "app",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example",
    extension = ":ext",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
)

watchos_application(
    name = "app_with_ext_with_invalid_watchos_version",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example",
    extension = ":ext",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
)

watchos_application(
    name = "single_target_app",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.single_target_app,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    resources = [
        "//test/starlark_tests/resources:example_filegroup",
        "//test/starlark_tests/resources:localization",
        "//test/starlark_tests/resources:resource_bundle",
    ],
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:watchkit_single_target_app_main_lib",
    ],
)

watchos_application(
    name = "app_with_ext_with_imported_fmwk",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example",
    extension = ":ext_with_imported_fmwk",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.baseline,
    tags = common.fixture_tags,
)

watchos_application(
    name = "single_target_app_with_imported_fmwk",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = common.min_os_watchos.single_target_app,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        ":dynamic_fmwk_depending_lib",
        "//test/starlark_tests/resources:watchkit_single_target_app_main_lib",
    ],
)

watchos_application(
    name = "app_arm64_support",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.arm64_support,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:watchkit_single_target_app_main_lib",
    ],
)

watchos_extension(
    name = "ext",
    bundle_id = "com.google.example.ext",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:WatchosExtensionInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    resources = [
        "//test/starlark_tests/resources:example_filegroup",
        "//test/starlark_tests/resources:localization",
        "//test/starlark_tests/resources:resource_bundle",
    ],
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:watchkit_ext_main_lib",
    ],
)

watchos_extension(
    name = "ext_with_imported_fmwk",
    bundle_id = "com.google.example.ext",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:WatchosExtensionInfo.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = common.min_os_watchos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        ":dynamic_fmwk_depending_lib",
        "//test/starlark_tests/resources:watchkit_ext_main_lib",
    ],
)

watchos_extension(
    name = "ext_multiple_infoplists",
    bundle_id = "com.google.example.ext",
    infoplists = [
        "//test/starlark_tests/resources:Another.plist",
        "//test/starlark_tests/resources:WatchosExtensionInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.baseline,
    tags = common.fixture_tags,
)

ios_application(
    name = "app_companion",
    bundle_id = "com.google",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_ios.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    visibility = [
        "//test/starlark_tests:__subpackages__",
        "//tools/dossier_codesigningtool:__pkg__",
    ],
    watch_application = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "app_companion_arm64_support",
    bundle_id = "com.google",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_ios.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    visibility = [
        "//test/starlark_tests:__subpackages__",
        "//tools/dossier_codesigningtool:__pkg__",
    ],
    watch_application = ":app_arm64_support",
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

# ---------------------------------------------------------------------------------------

objc_library(
    name = "dynamic_fmwk_depending_lib",
    tags = common.fixture_tags,
    deps = [":imported_watchos_dynamic_fmwk"],
)

apple_dynamic_framework_import(
    name = "imported_watchos_dynamic_fmwk",
    framework_imports = [":generated_watchos_dynamic_fmwk"],
    tags = common.fixture_tags,
)

generate_import_framework(
    name = "generated_watchos_dynamic_fmwk",
    archs = ["x86_64"],
    libtype = "dynamic",
    minimum_os_version = common.min_os_watchos.baseline,
    sdk = "watchsimulator",
    tags = common.fixture_tags,
)

# ---------------------------------------------------------------------------------------

ios_application(
    name = "ios_watchos_with_watchos_extension",
    bundle_id = "com.google",
    bundle_name = "companion",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_ios.arm_sim_support,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    watch_application = ":watchos_app_with_extension",
    deps = [
        ":swift_lib",
    ],
)

watchos_extension(
    name = "watchos_app_extension",
    bundle_id = "com.google.example.watchosext.nestedwatchosext",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

watchos_extension(
    name = "watchos_ext_with_extension",
    bundle_id = "com.google.example.watchosext",
    bundle_name = "ext",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    extensions = [":watchos_app_extension"],
    infoplists = [
        "//test/starlark_tests/resources:WatchosExtensionInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

watchos_application(
    name = "watchos_app_with_extension",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example",
    bundle_name = "app",
    extension = ":watchos_ext_with_extension",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
)

watchos_application(
    name = "single_target_app_too_low_minos",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = "6.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    resources = [
        "//test/starlark_tests/resources:example_filegroup",
        "//test/starlark_tests/resources:localization",
        "//test/starlark_tests/resources:resource_bundle",
    ],
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:watchkit_single_target_app_main_lib",
    ],
)

watchos_application(
    name = "single_target_app_with_watch2_ext",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    extension = ":watchos_app_extension",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.single_target_app,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    resources = [
        "//test/starlark_tests/resources:example_filegroup",
        "//test/starlark_tests/resources:localization",
        "//test/starlark_tests/resources:resource_bundle",
    ],
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:watchkit_single_target_app_main_lib",
    ],
)

# ---------------------------------------------------------------------------------------

ios_application(
    name = "ios_with_swift_watchos_no_swift",
    bundle_id = "com.google",
    bundle_name = "companion",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_ios.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    watch_application = ":watchos_app_no_swift",
    deps = [
        ":swift_lib",
    ],
)

ios_application(
    name = "ios_no_swift_watchos_with_swift",
    bundle_id = "com.google",
    bundle_name = "companion",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_ios.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    watch_application = ":watchos_app_swift",
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "ios_with_swift_watchos_with_swift",
    bundle_id = "com.google",
    bundle_name = "companion",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_ios.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    watch_application = ":watchos_app_swift",
    deps = [
        ":swift_lib",
    ],
)

ios_application(
    name = "ios_with_swift_watchos_with_swift_stable_abi",
    bundle_id = "com.google",
    bundle_name = "companion",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_ios.stable_swift_abi,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    watch_application = ":watchos_app_swift_stable_abi",
    deps = [
        ":swift_lib",
    ],
)

ios_application(
    name = "ios_with_swift_single_target_watchos_with_swift_stable_abi",
    bundle_id = "com.google",
    bundle_name = "companion",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_ios.stable_swift_abi,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    watch_application = ":watchos_single_target_app_swift_stable_abi",
    deps = [
        ":swift_lib",
    ],
)

watchos_application(
    name = "watchos_app_no_swift",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example",
    bundle_name = "app",
    extension = ":watchos_ext_no_swift",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
)

watchos_extension(
    name = "watchos_ext_no_swift",
    bundle_id = "com.google.example.ext",
    bundle_name = "ext",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:WatchosExtensionInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

watchos_application(
    name = "watchos_app_swift",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example",
    bundle_name = "app",
    extension = ":watchos_ext_swift",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
)

watchos_extension(
    name = "watchos_ext_swift",
    bundle_id = "com.google.example.ext",
    bundle_name = "ext",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:WatchosExtensionInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:watchkit_ext_main_lib",
    ],
)

watchos_application(
    name = "watchos_app_swift_stable_abi",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example",
    bundle_name = "app",
    extension = ":watchos_ext_swift_stable_abi",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = "6.0",
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
)

watchos_application(
    name = "watchos_single_target_app_swift_stable_abi",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example",
    bundle_name = "app",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.single_target_app,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:watchkit_single_target_app_main_lib",
    ],
)

watchos_extension(
    name = "watchos_ext_swift_stable_abi",
    bundle_id = "com.google.example.ext",
    bundle_name = "ext",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:WatchosExtensionInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.stable_swift_abi,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:watchkit_ext_main_lib",
    ],
)

swift_library(
    name = "swift_lib",
    srcs = ["//test/testdata/sources:main.swift"],
    tags = common.fixture_tags,
)

watchos_ui_test(
    name = "ui_test",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.test_runner_support,
    runner = "//test/starlark_tests/targets_under_test/apple:dummy_test_runner",
    tags = common.fixture_tags,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

watchos_ui_test(
    name = "single_target_ui_test",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.test_runner_support,
    runner = "//test/starlark_tests/targets_under_test/apple:dummy_test_runner",
    tags = common.fixture_tags,
    test_host = ":single_target_app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

watchos_unit_test(
    name = "unit_test",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.test_runner_support,
    runner = "//test/starlark_tests/targets_under_test/apple:dummy_test_runner",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

# -----------------------------------------------------------------------------------------
# Targets for Apple dynamic XCFramework import tests.

watchos_application(
    name = "app_with_imported_xcframework",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.arm64_support,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        ":dynamic_xcframework_depending_lib",
        "//test/starlark_tests/resources:watchkit_single_target_app_main_lib",
    ],
)

objc_library(
    name = "dynamic_xcframework_depending_lib",
    tags = common.fixture_tags,
    deps = [
        ":watchos_imported_dynamic_xcframework",
    ],
)

apple_dynamic_xcframework_import(
    name = "watchos_imported_dynamic_xcframework",
    tags = common.fixture_tags,
    xcframework_imports = [":generated_dynamic_watchos_xcframework"],
)

generate_dynamic_xcframework(
    name = "generated_dynamic_watchos_xcframework",
    srcs = ["//test/starlark_tests/resources/frameworks:SharedClass.m"],
    hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    minimum_os_versions = {
        "watchos": common.min_os_watchos.arm64_support,
        "watchos_simulator": common.min_os_watchos.arm_sim_support,
    },
    platforms = {
        "watchos": [
            "armv7k",
            "arm64_32",
        ],
        "watchos_simulator": [
            "x86_64",
            "arm64",
        ],
    },
    tags = common.fixture_tags,
)

# -----------------------------------------------------------------------------------------
# Targets for Apple static XCFramework import tests.

watchos_application(
    name = "app_with_imported_static_xcframework",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.arm64_support,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        ":static_xcframework_depending_lib",
        "//test/starlark_tests/resources:watchkit_single_target_app_main_lib",
    ],
)

objc_library(
    name = "static_xcframework_depending_lib",
    tags = common.fixture_tags,
    deps = [":watchos_imported_static_xcframework"],
)

apple_static_xcframework_import(
    name = "watchos_imported_static_xcframework",
    features = ["-swift.layering_check"],
    tags = common.fixture_tags,
    xcframework_imports = [":generated_static_watchos_xcframework"],
)

generate_static_xcframework(
    name = "generated_static_watchos_xcframework",
    srcs = ["//test/starlark_tests/resources/frameworks:SharedClass.m"],
    hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    minimum_os_versions = {
        "watchos": common.min_os_watchos.arm64_support,
        "watchos_simulator": common.min_os_watchos.arm_sim_support,
    },
    platforms = {
        "watchos": [
            "armv7k",
            "arm64_32",
        ],
        "watchos_simulator": [
            "x86_64",
            "arm64",
        ],
    },
    tags = common.fixture_tags,
)

# ---------------------------------------------------------------------------------------
# Targets for AppIntents

watchos_application(
    name = "app_with_app_intents",
    app_intents = [
        "//test/starlark_tests/resources:app_intent",
    ],
    bundle_id = "com.google.example",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.app_intents_support,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:watchkit_single_target_app_main_lib",
    ],
)

# ---------------------------------------------------------------------------------------
# Targets for base_bundle_id and bundle_id flows with and without shared capabilities.

watchos_application(
    name = "app_with_ext_with_capability_set_derived_bundle_id",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_name = "app",
    extension = ":ext_with_capability_set_derived_bundle_id",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    shared_capabilities = [
        "//test/starlark_tests/targets_under_test/apple/capabilities:base_capability_set",
    ],
    tags = common.fixture_tags,
)

watchos_extension(
    name = "ext_with_capability_set_derived_bundle_id",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:WatchosExtensionCapabilityDerivedInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    resources = [
        "//test/starlark_tests/resources:example_filegroup",
        "//test/starlark_tests/resources:localization",
        "//test/starlark_tests/resources:resource_bundle",
    ],
    shared_capabilities = [
        "//test/starlark_tests/targets_under_test/apple/capabilities:base_capability_set",
    ],
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:watchkit_ext_main_lib",
    ],
)

watchos_application(
    name = "single_target_app_with_capability_set_derived_bundle_id",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.single_target_app,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    shared_capabilities = [
        "//test/starlark_tests/targets_under_test/apple/capabilities:base_capability_set",
    ],
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:watchkit_single_target_app_main_lib",
    ],
)

watchos_ui_test(
    name = "ui_test_with_base_bundle_id_derived_bundle_id",
    base_bundle_id = "//test/starlark_tests/targets_under_test/apple/capabilities:base_bundle_id",
    bundle_id_suffix = "ui-test-with-base-bundle-id-derived-bundle-id",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.test_runner_support,
    runner = "//test/starlark_tests/targets_under_test/apple:dummy_test_runner",
    tags = common.fixture_tags,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

watchos_unit_test(
    name = "unit_test_with_base_bundle_id_derived_bundle_id",
    base_bundle_id = "//test/starlark_tests/targets_under_test/apple/capabilities:base_bundle_id",
    bundle_id_suffix = "unit-test-with-base-bundle-id-derived-bundle-id",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.test_runner_support,
    runner = "//test/starlark_tests/targets_under_test/apple:dummy_test_runner",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

watchos_ui_test(
    name = "single_target_ui_test_with_base_bundle_id_derived_bundle_id",
    base_bundle_id = "//test/starlark_tests/targets_under_test/apple/capabilities:base_bundle_id",
    bundle_id_suffix = "single-target-ui-test-with-base-bundle-id-derived-bundle-id",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.test_runner_support,
    runner = "//test/starlark_tests/targets_under_test/apple:dummy_test_runner",
    tags = common.fixture_tags,
    test_host = ":single_target_app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)
