load(
    "@build_bazel_rules_swift//swift:swift_library.bzl",
    "swift_library",
)
load("@rules_cc//cc:objc_library.bzl", "objc_library")
load(
    "//apple:apple_imports.bzl",
    "apple_dynamic_framework_import",
    "apple_dynamic_xcframework_import",
    "apple_static_xcframework_import",
)
load(
    "//apple:apple_xcframework.bzl",
    "apple_static_xcframework",
    "apple_xcframework",
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

licenses(["notice"])

package(
    default_testonly = 1,
    default_visibility = ["//test/starlark_tests:__subpackages__"],
)

watchos_application(
    name = "app_with_no_extension_or_deps",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.min_deployment_target,
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
    minimum_os_version = common.min_os_watchos.min_deployment_target,
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
    name = "app_with_icon_bundle",
    app_icons = ["//test/starlark_tests/resources:icon_bundle_assets"],
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.icon_bundle_required,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:watchkit_single_target_app_main_lib",
    ],
)

watchos_application(
    name = "app_with_icon_bundle_only_for_low_minimum_os_version",
    app_icons = ["//test/starlark_tests/resources:icon_bundle_assets"],
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.min_deployment_target,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:watchkit_single_target_app_main_lib",
    ],
)

watchos_application(
    name = "app_with_icon_bundle_and_xcassets_app_icons",
    app_icons = [
        "//test/starlark_tests/resources:WatchAppIcon.xcassets",
        "//test/starlark_tests/resources:icon_bundle_assets",
    ],
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.min_deployment_target,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:watchkit_single_target_app_main_lib",
    ],
)

watchos_extension(
    name = "generic_ext",
    bundle_id = "com.google.example.ext",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.min_deployment_target,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    resources = [
        "//test/starlark_tests/resources:Another.plist",
        "//test/starlark_tests/resources:localization",
        "//test/starlark_tests/resources:resource_bundle",
    ],
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

ios_application(
    name = "ios_app_with_watchos_app_with_generic_ext",
    bundle_id = "com.google",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_ios.min_deployment_target,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    watch_application = ":single_target_app_with_generic_ext",
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

watchos_application(
    name = "single_target_app_with_generic_ext",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example",
    extensions = [":generic_ext"],
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.min_deployment_target,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:watchkit_single_target_app_main_lib",
    ],
)

watchos_extension(
    name = "extensionkit_ext",
    bundle_id = "com.google.example.extensionkitext",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    extensionkit_extension = True,
    infoplists = [
        "//test/starlark_tests/resources:ExtensionKitInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.min_deployment_target,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

watchos_application(
    name = "single_target_app_with_extensionkit_ext",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example",
    extensions = [":extensionkit_ext"],
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.min_deployment_target,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:watchkit_single_target_app_main_lib",
    ],
)

watchos_application(
    name = "single_target_app_for_test_runner",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.min_deployment_target,
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
    name = "single_target_app_with_imported_fmwk",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = common.min_os_watchos.min_deployment_target,
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
    minimum_os_version = common.min_os_watchos.min_deployment_target,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:watchkit_single_target_app_main_lib",
    ],
)

watchos_extension(
    name = "ext_multiple_infoplists",
    bundle_id = "com.google.example.ext",
    infoplists = [
        "//test/starlark_tests/resources:Another.plist",
        "//test/starlark_tests/resources:WatchosExtensionInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.min_deployment_target,
    tags = common.fixture_tags,
)

ios_application(
    name = "app_companion_arm64_support",
    bundle_id = "com.google",
    families = ["iphone"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_ios.min_deployment_target,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    secure_features = [
        "apple.enable_enhanced_security",
        "pointer_authentication",
    ],
    tags = common.fixture_tags,
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

objc_library(
    name = "generated_watchos_dynamic_fmwk_lib",
    srcs = ["//test/starlark_tests/resources/frameworks:SharedClass.m"],
    hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    tags = common.fixture_tags,
)

apple_xcframework(
    name = "generated_watchos_dynamic_fmwk_xcframework",
    bundle_id = "com.google.example",
    bundle_name = "generated_watchos_dynamic_fmwk",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    minimum_os_versions = {
        "watchos": common.min_os_watchos.min_deployment_target,
    },
    public_hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    tags = common.fixture_tags,
    watchos = {
        "simulator": [
            "x86_64",
        ],
    },
    deps = [
        ":generated_watchos_dynamic_fmwk_lib",
    ],
)

genrule(
    name = "generated_watchos_dynamic_fmwk",
    srcs = [":generated_watchos_dynamic_fmwk_xcframework"],
    outs = [
        "generated_watchos_dynamic_fmwk.framework/Headers/SharedClass.h",
        "generated_watchos_dynamic_fmwk.framework/Headers/generated_watchos_dynamic_fmwk.h",
        "generated_watchos_dynamic_fmwk.framework/Info.plist",
        "generated_watchos_dynamic_fmwk.framework/Modules/module.modulemap",
        "generated_watchos_dynamic_fmwk.framework/generated_watchos_dynamic_fmwk",
    ],
    cmd = common.extract_xcframework_cmd("generated_watchos_dynamic_fmwk"),
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
    minimum_os_version = common.min_os_ios.min_deployment_target,
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
        "//test/starlark_tests/resources:WatchosExtensionInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.min_deployment_target,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:watchkit_ext_main_lib",
    ],
)

watchos_application(
    name = "single_target_app_too_low_minos",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.min_deployment_target,
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
    minimum_os_version = common.min_os_watchos.min_deployment_target,
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
    minimum_os_version = common.min_os_watchos.min_deployment_target,
    runner = "//test/starlark_tests/targets_under_test/apple:dummy_test_runner",
    tags = common.fixture_tags,
    test_host = ":app_for_test_runner",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

watchos_ui_test(
    name = "single_target_ui_test",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.min_deployment_target,
    runner = "//test/starlark_tests/targets_under_test/apple:dummy_test_runner",
    tags = common.fixture_tags,
    test_host = ":single_target_app_for_test_runner",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

watchos_unit_test(
    name = "unit_test",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.min_deployment_target,
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
    minimum_os_version = common.min_os_watchos.min_deployment_target,
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

watchos_application(
    name = "app_with_imported_multiplatform_xcframework",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.min_deployment_target,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        ":multiplatform_dynamic_xcframework_depending_lib",
        "//test/starlark_tests/resources:watchkit_single_target_app_main_lib",
    ],
)

objc_library(
    name = "multiplatform_dynamic_xcframework_depending_lib",
    tags = common.fixture_tags,
    deps = [
        ":watchos_imported_multiplatform_dynamic_xcframework",
    ],
)

apple_dynamic_xcframework_import(
    name = "watchos_imported_multiplatform_dynamic_xcframework",
    tags = common.fixture_tags,
    xcframework_imports = [":generated_multiplatform_dynamic_xcframework"],
)

apple_xcframework(
    name = "multiplatform_dynamic_xcframework",
    bundle_id = "com.google.example",
    bundle_name = "generated_multiplatform_dynamic_xcframework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ios = {
        "device": [
            "arm64",
        ],
    },
    minimum_os_versions = {
        "ios": common.min_os_ios.min_deployment_target,
        "watchos": common.min_os_watchos.min_deployment_target,
    },
    public_hdrs = [
        "//test/starlark_tests/resources/frameworks:SharedClass.h",
    ],
    tags = common.fixture_tags,
    watchos = {
        "device": [
            "arm64_32",
            "arm64",
        ],
        "simulator": [
            "x86_64",
            "arm64",
        ],
    },
    deps = [

        # "//test/starlark_tests/targets_under_test/ios:xcframework_shared_class",
    ],
)

genrule(
    name = "generated_multiplatform_dynamic_xcframework",
    srcs = [":multiplatform_dynamic_xcframework"],
    outs = [
        "generated_multiplatform_dynamic_xcframework/generated_multiplatform_dynamic_xcframework.xcframework/Info.plist",
        "generated_multiplatform_dynamic_xcframework/generated_multiplatform_dynamic_xcframework.xcframework/ios-arm64/generated_multiplatform_dynamic_xcframework.framework/generated_multiplatform_dynamic_xcframework",
        "generated_multiplatform_dynamic_xcframework/generated_multiplatform_dynamic_xcframework.xcframework/ios-arm64/generated_multiplatform_dynamic_xcframework.framework/Info.plist",
        "generated_multiplatform_dynamic_xcframework/generated_multiplatform_dynamic_xcframework.xcframework/ios-arm64/generated_multiplatform_dynamic_xcframework.framework/Headers/SharedClass.h",
        "generated_multiplatform_dynamic_xcframework/generated_multiplatform_dynamic_xcframework.xcframework/ios-arm64/generated_multiplatform_dynamic_xcframework.framework/Headers/generated_multiplatform_dynamic_xcframework.h",
        "generated_multiplatform_dynamic_xcframework/generated_multiplatform_dynamic_xcframework.xcframework/ios-arm64/generated_multiplatform_dynamic_xcframework.framework/Modules/module.modulemap",
        "generated_multiplatform_dynamic_xcframework/generated_multiplatform_dynamic_xcframework.xcframework/watchos-arm64_arm64_32/generated_multiplatform_dynamic_xcframework.framework/generated_multiplatform_dynamic_xcframework",
        "generated_multiplatform_dynamic_xcframework/generated_multiplatform_dynamic_xcframework.xcframework/watchos-arm64_arm64_32/generated_multiplatform_dynamic_xcframework.framework/Info.plist",
        "generated_multiplatform_dynamic_xcframework/generated_multiplatform_dynamic_xcframework.xcframework/watchos-arm64_arm64_32/generated_multiplatform_dynamic_xcframework.framework/Headers/SharedClass.h",
        "generated_multiplatform_dynamic_xcframework/generated_multiplatform_dynamic_xcframework.xcframework/watchos-arm64_arm64_32/generated_multiplatform_dynamic_xcframework.framework/Headers/generated_multiplatform_dynamic_xcframework.h",
        "generated_multiplatform_dynamic_xcframework/generated_multiplatform_dynamic_xcframework.xcframework/watchos-arm64_arm64_32/generated_multiplatform_dynamic_xcframework.framework/Modules/module.modulemap",
        "generated_multiplatform_dynamic_xcframework/generated_multiplatform_dynamic_xcframework.xcframework/watchos-arm64_x86_64-simulator/generated_multiplatform_dynamic_xcframework.framework/generated_multiplatform_dynamic_xcframework",
        "generated_multiplatform_dynamic_xcframework/generated_multiplatform_dynamic_xcframework.xcframework/watchos-arm64_x86_64-simulator/generated_multiplatform_dynamic_xcframework.framework/Info.plist",
        "generated_multiplatform_dynamic_xcframework/generated_multiplatform_dynamic_xcframework.xcframework/watchos-arm64_x86_64-simulator/generated_multiplatform_dynamic_xcframework.framework/Headers/SharedClass.h",
        "generated_multiplatform_dynamic_xcframework/generated_multiplatform_dynamic_xcframework.xcframework/watchos-arm64_x86_64-simulator/generated_multiplatform_dynamic_xcframework.framework/Headers/generated_multiplatform_dynamic_xcframework.h",
        "generated_multiplatform_dynamic_xcframework/generated_multiplatform_dynamic_xcframework.xcframework/watchos-arm64_x86_64-simulator/generated_multiplatform_dynamic_xcframework.framework/Modules/module.modulemap",
    ],
    cmd = common.extract_xcframework_cmd("generated_multiplatform_dynamic_xcframework"),
    tags = common.fixture_tags,
)

objc_library(
    name = "generated_dynamic_watchos_xcframework_lib",
    srcs = ["//test/starlark_tests/resources/frameworks:SharedClass.m"],
    hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    tags = common.fixture_tags,
)

apple_xcframework(
    name = "generated_dynamic_watchos_xcframework_xcframework",
    bundle_id = "com.google.example",
    bundle_name = "generated_dynamic_watchos_xcframework",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    minimum_os_versions = {
        "watchos": common.min_os_watchos.min_deployment_target,
    },
    public_hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    tags = common.fixture_tags,
    watchos = {
        "device": [
            "arm64_32",
        ],
        "simulator": [
            "x86_64",
            "arm64",
        ],
    },
    deps = [
        ":generated_dynamic_watchos_xcframework_lib",
    ],
)

genrule(
    name = "generated_dynamic_watchos_xcframework",
    srcs = [":generated_dynamic_watchos_xcframework_xcframework"],
    outs = [
        "generated_dynamic_watchos_xcframework/generated_dynamic_watchos_xcframework.xcframework/Info.plist",
        "generated_dynamic_watchos_xcframework/generated_dynamic_watchos_xcframework.xcframework/watchos-arm64_32/generated_dynamic_watchos_xcframework.framework/Headers/SharedClass.h",
        "generated_dynamic_watchos_xcframework/generated_dynamic_watchos_xcframework.xcframework/watchos-arm64_32/generated_dynamic_watchos_xcframework.framework/Headers/generated_dynamic_watchos_xcframework.h",
        "generated_dynamic_watchos_xcframework/generated_dynamic_watchos_xcframework.xcframework/watchos-arm64_32/generated_dynamic_watchos_xcframework.framework/Info.plist",
        "generated_dynamic_watchos_xcframework/generated_dynamic_watchos_xcframework.xcframework/watchos-arm64_32/generated_dynamic_watchos_xcframework.framework/Modules/module.modulemap",
        "generated_dynamic_watchos_xcframework/generated_dynamic_watchos_xcframework.xcframework/watchos-arm64_32/generated_dynamic_watchos_xcframework.framework/generated_dynamic_watchos_xcframework",
        "generated_dynamic_watchos_xcframework/generated_dynamic_watchos_xcframework.xcframework/watchos-arm64_x86_64-simulator/generated_dynamic_watchos_xcframework.framework/Headers/SharedClass.h",
        "generated_dynamic_watchos_xcframework/generated_dynamic_watchos_xcframework.xcframework/watchos-arm64_x86_64-simulator/generated_dynamic_watchos_xcframework.framework/Headers/generated_dynamic_watchos_xcframework.h",
        "generated_dynamic_watchos_xcframework/generated_dynamic_watchos_xcframework.xcframework/watchos-arm64_x86_64-simulator/generated_dynamic_watchos_xcframework.framework/Info.plist",
        "generated_dynamic_watchos_xcframework/generated_dynamic_watchos_xcframework.xcframework/watchos-arm64_x86_64-simulator/generated_dynamic_watchos_xcframework.framework/Modules/module.modulemap",
        "generated_dynamic_watchos_xcframework/generated_dynamic_watchos_xcframework.xcframework/watchos-arm64_x86_64-simulator/generated_dynamic_watchos_xcframework.framework/generated_dynamic_watchos_xcframework",
    ],
    cmd = common.extract_xcframework_cmd("generated_dynamic_watchos_xcframework"),
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
    minimum_os_version = common.min_os_watchos.min_deployment_target,
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
    features = ["-swift.layering_check_for_c_deps"],
    tags = common.fixture_tags,
    xcframework_imports = [":generated_static_watchos_xcframework"],
)

objc_library(
    name = "generated_static_watchos_xcframework_lib",
    srcs = ["//test/starlark_tests/resources/frameworks:SharedClass.m"],
    hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    tags = common.fixture_tags,
)

apple_static_xcframework(
    name = "generated_static_watchos_xcframework_xcframework",
    bundle_name = "generated_static_watchos_xcframework",
    minimum_os_versions = {
        "watchos": common.min_os_watchos.min_deployment_target,
    },
    public_hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    tags = common.fixture_tags,
    watchos = {
        "device": [
            "arm64_32",
        ],
        "simulator": [
            "x86_64",
            "arm64",
        ],
    },
    deps = [
        ":generated_static_watchos_xcframework_lib",
    ],
)

genrule(
    name = "generated_static_watchos_xcframework",
    srcs = [":generated_static_watchos_xcframework_xcframework"],
    outs = [
        "generated_static_watchos_xcframework/generated_static_watchos_xcframework.xcframework/Info.plist",
        "generated_static_watchos_xcframework/generated_static_watchos_xcframework.xcframework/watchos-arm64_32/Headers/generated_static_watchos_xcframework/SharedClass.h",
        "generated_static_watchos_xcframework/generated_static_watchos_xcframework.xcframework/watchos-arm64_32/Headers/generated_static_watchos_xcframework/generated_static_watchos_xcframework.h",
        "generated_static_watchos_xcframework/generated_static_watchos_xcframework.xcframework/watchos-arm64_32/Headers/generated_static_watchos_xcframework/module.modulemap",
        "generated_static_watchos_xcframework/generated_static_watchos_xcframework.xcframework/watchos-arm64_32/generated_static_watchos_xcframework.a",
        "generated_static_watchos_xcframework/generated_static_watchos_xcframework.xcframework/watchos-arm64_x86_64-simulator/Headers/generated_static_watchos_xcframework/SharedClass.h",
        "generated_static_watchos_xcframework/generated_static_watchos_xcframework.xcframework/watchos-arm64_x86_64-simulator/Headers/generated_static_watchos_xcframework/generated_static_watchos_xcframework.h",
        "generated_static_watchos_xcframework/generated_static_watchos_xcframework.xcframework/watchos-arm64_x86_64-simulator/Headers/generated_static_watchos_xcframework/module.modulemap",
        "generated_static_watchos_xcframework/generated_static_watchos_xcframework.xcframework/watchos-arm64_x86_64-simulator/generated_static_watchos_xcframework.a",
    ],
    cmd = common.extract_xcframework_cmd("generated_static_watchos_xcframework"),
    tags = common.fixture_tags,
)

# ---------------------------------------------------------------------------------------
# Targets for AppIntents

watchos_application(
    name = "app_with_app_intents",
    bundle_id = "com.google.example",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.app_intents_support,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:hinted_app_intent",
        "//test/starlark_tests/resources:watchkit_single_target_app_main_lib",
    ],
)

watchos_application(
    name = "app_with_transitive_app_intents",
    bundle_id = "com.google.example",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.app_intents_support,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:watchkit_single_target_app_main_lib_referencing_app_intent",
    ],
)

# ---------------------------------------------------------------------------------------
# Targets for secure_features testing.

watchos_application(
    name = "simple_pointer_authentication_app",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.min_deployment_target,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    resources = [
        "//test/starlark_tests/resources:example_filegroup",
        "//test/starlark_tests/resources:localization",
        "//test/starlark_tests/resources:resource_bundle",
    ],
    secure_features = [
        "apple.enable_enhanced_security",
        "pointer_authentication",
    ],
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:watchkit_single_target_app_main_lib",
    ],
)

# ---------------------------------------------------------------------------------------
# Targets for base_bundle_id and bundle_id flows with and without shared capabilities.

watchos_application(
    name = "single_target_app_with_capability_set_derived_bundle_id",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.min_deployment_target,
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
    minimum_os_version = common.min_os_watchos.min_deployment_target,
    runner = "//test/starlark_tests/targets_under_test/apple:dummy_test_runner",
    tags = common.fixture_tags,
    test_host = ":app_for_test_runner",
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
    minimum_os_version = common.min_os_watchos.min_deployment_target,
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
    minimum_os_version = common.min_os_watchos.min_deployment_target,
    runner = "//test/starlark_tests/targets_under_test/apple:dummy_test_runner",
    tags = common.fixture_tags,
    test_host = ":single_target_app_for_test_runner",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

watchos_application(
    name = "app_minimum_os_27",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.os_27_mandates,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:objc_main_lib"],
)
