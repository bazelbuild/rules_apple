load(
    "@build_bazel_rules_swift//swift:swift_library.bzl",
    "swift_library",
)
load("@rules_cc//cc:objc_library.bzl", "objc_library")
load(
    "//apple:apple_imports.bzl",
    "apple_dynamic_framework_import",
    "apple_dynamic_xcframework_import",
    "apple_static_framework_import",
    "apple_static_xcframework_import",
)
load(
    "//apple:apple_xcframework.bzl",
    "apple_static_xcframework",
    "apple_xcframework",
)
load(
    "//apple:macos.bzl",
    "macos_application",
    "macos_bundle",
    "macos_command_line_application",
    "macos_dylib",
    "macos_extension",
    "macos_framework",
    "macos_ui_test",
    "macos_unit_test",
)
load(
    "//apple:resources.bzl",
    "apple_resource_group",
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

macos_application(
    name = "app",
    additional_contents = {
        "//test/starlark_tests/resources:additional.txt": "Additional",
        "//test/starlark_tests/resources:all_nested": "Nested",
    },
    app_icons = ["//test/starlark_tests/resources:MacAppIcon.xcassets"],
    bundle_id = "com.google.example",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_macos.provisionprofile",
    resources = [
        "//test/starlark_tests/resources:example_filegroup",
        "//test/starlark_tests/resources:localization",
        "//test/starlark_tests/resources:resource_bundle",
    ],
    tags = common.fixture_tags,
    visibility = [
        "//test/starlark_tests:__subpackages__",
    ],
    deps = [
        "//test/starlark_tests/resources:apple_localized_assets_lib",
        "//test/starlark_tests/resources:apple_non_localized_assets_lib",
        "//test/starlark_tests/resources:basic_bundle_lib",
        "//test/starlark_tests/resources:bundle_library_apple_lib",
        "//test/starlark_tests/resources:empty_strings_file_lib",
        "//test/starlark_tests/resources:nested_bundle_lib",
        "//test/starlark_tests/resources:objc_main_lib_with_common_lib",
    ],
)

macos_application(
    name = "app_basic_swift",
    bundle_id = "com.google.example",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_macos.provisionprofile",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:swift_main_lib",
    ],
)

macos_application(
    name = "app_with_icon_bundle",
    app_icons = ["//test/starlark_tests/resources:icon_bundle_assets"],
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.icon_bundle_required,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_application(
    name = "app_with_icon_bundle_only_for_low_minimum_os_version",
    app_icons = ["//test/starlark_tests/resources:icon_bundle_assets"],
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_application(
    name = "app_with_icon_bundle_and_xcassets_app_icons",
    app_icons = [
        "//test/starlark_tests/resources:MacAppIcon.xcassets",
        "//test/starlark_tests/resources:icon_bundle_assets",
    ],
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_application(
    name = "app_with_mergeable_strings",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    resources = [
        "//test/starlark_tests/resources:mergeable_strings_resources",
    ],
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_application(
    name = "app_multiple_infoplists",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Another.plist",
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_application(
    name = "app_special_linkopts",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    linkopts = [
        "-alias",
        "_main",
        "_linkopts_test_main",
        "-exported_symbol",
        "_linkopts_test_main",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_application(
    name = "app_with_space_in_bundle_name",
    bundle_id = "com.google.example",
    bundle_name = "app with space",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_application(
    name = "app with space in target name",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_application(
    name = "app_bundling_app",
    additional_contents = {
        ":app_basic_swift": "Helpers",
        ":cmd_app_info_plists": "Helpers",
        ":bundle": "PlugIns",
        ":dylib": "Frameworks",
    },
    bundle_id = "com.google.example",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_macos.provisionprofile",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:swift_main_lib",
    ],
)

# ---------------------------------------------------------------------------------------

macos_application(
    name = "app_with_ext",
    bundle_id = "com.google.example",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    extensions = [":ext"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_macos.provisionprofile",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_application(
    name = "app_with_extensionkit_ext",
    bundle_id = "com.google.example",
    extensions = [":extensionkit_ext"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_extension(
    name = "ext",
    additional_contents = {
        "//test/starlark_tests/resources:additional.txt": "Additional",
        "//test/starlark_tests/resources:all_nested": "Nested",
    },
    bundle_id = "com.google.example.ext",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_macos.provisionprofile",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:another_plist_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_extension(
    name = "extensionkit_ext",
    additional_contents = {
        "//test/starlark_tests/resources:additional.txt": "Additional",
        "//test/starlark_tests/resources:all_nested": "Nested",
    },
    bundle_id = "com.google.example.ext",
    extensionkit_extension = True,
    infoplists = [
        "//test/starlark_tests/resources:ExtensionKitInfo.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

# ---------------------------------------------------------------------------------------
# Targets for Apple dynamic framework import tests.

macos_application(
    name = "app_with_imported_fmwk",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        ":dynamic_fmwk_depending_lib",
        "//test/starlark_tests/resources:another_plist_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

objc_library(
    name = "dynamic_fmwk_depending_lib",
    tags = common.fixture_tags,
    deps = [":imported_macos_dynamic_fmwk"],
)

apple_dynamic_framework_import(
    name = "imported_macos_dynamic_fmwk",
    framework_imports = [":generated_macos_dynamic_fmwk"],
    tags = common.fixture_tags,
)

objc_library(
    name = "generated_macos_dynamic_fmwk_lib",
    srcs = ["//test/starlark_tests/resources/frameworks:SharedClass.m"],
    hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    tags = common.fixture_tags,
)

apple_xcframework(
    name = "generated_macos_dynamic_fmwk_xcframework",
    bundle_id = "com.google.example",
    bundle_name = "generated_macos_dynamic_fmwk",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    macos = {
        "device": [
            "x86_64",
        ],
    },
    minimum_os_versions = {
        "macos": common.min_os_macos.min_deployment_target,
    },
    public_hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    resources = ["//test/starlark_tests/resources:Another.plist"],
    tags = common.fixture_tags + ["requires-darwin"],
    deps = [
        ":generated_macos_dynamic_fmwk_lib",
    ],
)

genrule(
    name = "generated_macos_dynamic_fmwk",
    srcs = [
        ":generated_macos_dynamic_fmwk_xcframework",
    ],
    outs = [
        "generated_macos_dynamic_fmwk.framework/Versions/A/Headers/SharedClass.h",
        "generated_macos_dynamic_fmwk.framework/Versions/A/Headers/generated_macos_dynamic_fmwk.h",
        "generated_macos_dynamic_fmwk.framework/Versions/A/Modules/module.modulemap",
        "generated_macos_dynamic_fmwk.framework/Versions/A/Resources/Info.plist",
        "generated_macos_dynamic_fmwk.framework/Versions/A/generated_macos_dynamic_fmwk",
        "generated_macos_dynamic_fmwk.framework/generated_macos_dynamic_fmwk",
    ],
    cmd = common.extract_xcframework_cmd("generated_macos_dynamic_fmwk"),
    tags = common.fixture_tags,
)

macos_application(
    name = "app_with_imported_versioned_fmwk",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        ":dynamic_versioned_fmwk_depending_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

objc_library(
    name = "dynamic_versioned_fmwk_depending_lib",
    tags = common.fixture_tags,
    deps = [":imported_dynamic_versioned_fmwk"],
)

apple_dynamic_framework_import(
    name = "imported_dynamic_versioned_fmwk",
    framework_imports = [":generated_macos_dynamic_versioned_fmwk"],
    tags = common.fixture_tags,
)

objc_library(
    name = "generated_macos_dynamic_versioned_fmwk_lib",
    srcs = ["//test/starlark_tests/resources/frameworks:SharedClass.m"],
    hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    tags = common.fixture_tags,
)

apple_xcframework(
    name = "generated_macos_dynamic_versioned_fmwk_xcframework",
    bundle_id = "com.google.example",
    bundle_name = "generated_macos_dynamic_versioned_fmwk",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    macos = {
        "device": [
            "x86_64",
        ],
    },
    minimum_os_versions = {
        "macos": common.min_os_macos.min_deployment_target,
    },
    public_hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    resources = ["//test/starlark_tests/resources:Another.plist"],
    tags = common.fixture_tags + ["requires-darwin"],
    deps = [
        ":generated_macos_dynamic_versioned_fmwk_lib",
    ],
)

genrule(
    name = "generated_macos_dynamic_versioned_fmwk",
    srcs = [
        ":generated_macos_dynamic_versioned_fmwk_xcframework",
    ],
    outs = [
        "generated_macos_dynamic_versioned_fmwk.framework/Versions/A/Headers/SharedClass.h",
        "generated_macos_dynamic_versioned_fmwk.framework/Versions/A/Headers/generated_macos_dynamic_versioned_fmwk.h",
        "generated_macos_dynamic_versioned_fmwk.framework/Versions/A/Modules/module.modulemap",
        "generated_macos_dynamic_versioned_fmwk.framework/Versions/A/Resources/Info.plist",
        "generated_macos_dynamic_versioned_fmwk.framework/Versions/A/generated_macos_dynamic_versioned_fmwk",
        "generated_macos_dynamic_versioned_fmwk.framework/generated_macos_dynamic_versioned_fmwk",
    ],
    cmd = common.extract_xcframework_cmd("generated_macos_dynamic_versioned_fmwk"),
    tags = common.fixture_tags,
)

# ---------------------------------------------------------------------------------------
# Targets for Apple dynamic XCFramework import tests.

macos_application(
    name = "app_with_imported_dynamic_unversioned_xcframework",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        ":dynamic_xcframework_depending_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

objc_library(
    name = "dynamic_xcframework_depending_lib",
    tags = common.fixture_tags,
    deps = [
        ":macos_imported_dynamic_xcframework",
    ],
)

apple_dynamic_xcframework_import(
    name = "macos_imported_dynamic_xcframework",
    tags = common.fixture_tags,
    xcframework_imports = [":generated_dynamic_macos_unversioned_xcframework"],
)

objc_library(
    name = "generated_dynamic_macos_unversioned_xcframework_lib",
    srcs = ["//test/starlark_tests/resources/frameworks:SharedClass.m"],
    hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    tags = common.fixture_tags,
)

apple_xcframework(
    name = "generated_dynamic_macos_unversioned_xcframework_xcframework",
    bundle_id = "com.google.example",
    bundle_name = "generated_dynamic_macos_unversioned_xcframework",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    macos = {
        "device": [
            "arm64",
            "arm64e",
            "x86_64",
        ],
    },
    minimum_os_versions = {
        "macos": common.min_os_macos.min_deployment_target,
    },
    public_hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    resources = ["//test/starlark_tests/resources:Another.plist"],
    secure_features = [
        "pointer_authentication",
    ],
    tags = common.fixture_tags + ["requires-darwin"],
    deps = [
        ":generated_dynamic_macos_unversioned_xcframework_lib",
    ],
)

# This target intentionally rips out the "Versions/A/" hierarchy and flattens
# the framework payload. This creates a deliberately corrupted macOS
# framework struct to test the analyzer's rejection logic in
# imported_unversioned_xcframework_failure_test.
genrule(
    name = "generated_dynamic_macos_unversioned_xcframework",
    srcs = [
        ":generated_dynamic_macos_unversioned_xcframework_xcframework",
    ],
    outs = [
        "generated_dynamic_macos_unversioned_xcframework/generated_dynamic_macos_unversioned_xcframework.xcframework/Info.plist",
        "generated_dynamic_macos_unversioned_xcframework/generated_dynamic_macos_unversioned_xcframework.xcframework/macos-arm64_arm64e_x86_64/generated_dynamic_macos_unversioned_xcframework.framework/Headers/SharedClass.h",
        "generated_dynamic_macos_unversioned_xcframework/generated_dynamic_macos_unversioned_xcframework.xcframework/macos-arm64_arm64e_x86_64/generated_dynamic_macos_unversioned_xcframework.framework/Headers/generated_dynamic_macos_unversioned_xcframework.h",
        "generated_dynamic_macos_unversioned_xcframework/generated_dynamic_macos_unversioned_xcframework.xcframework/macos-arm64_arm64e_x86_64/generated_dynamic_macos_unversioned_xcframework.framework/Modules/module.modulemap",
        "generated_dynamic_macos_unversioned_xcframework/generated_dynamic_macos_unversioned_xcframework.xcframework/macos-arm64_arm64e_x86_64/generated_dynamic_macos_unversioned_xcframework.framework/Resources/Info.plist",
        "generated_dynamic_macos_unversioned_xcframework/generated_dynamic_macos_unversioned_xcframework.xcframework/macos-arm64_arm64e_x86_64/generated_dynamic_macos_unversioned_xcframework.framework/generated_dynamic_macos_unversioned_xcframework",
    ],
    cmd = common.extract_xcframework_cmd("generated_dynamic_macos_unversioned_xcframework") + """
        FMWK="$$DEST/macos-arm64_arm64e_x86_64/generated_dynamic_macos_unversioned_xcframework.framework"
        # Remove symlinks
        rm -f "$$FMWK/generated_dynamic_macos_unversioned_xcframework" "$$FMWK/Headers" "$$FMWK/Modules" "$$FMWK/Resources"
        # Move Versions/A/* out
        mv "$$FMWK/Versions/A/"* "$$FMWK/"
        rm -rf "$$FMWK/Versions"
    """,
    tags = common.fixture_tags,
)

macos_application(
    name = "app_with_imported_dynamic_versioned_xcframework",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    secure_features = [
        "apple.enable_enhanced_security",
        "pointer_authentication",
    ],
    tags = common.fixture_tags,
    deps = [
        ":dynamic_versioned_xcframework_depending_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

objc_library(
    name = "dynamic_versioned_xcframework_depending_lib",
    tags = common.fixture_tags,
    deps = [
        ":imported_dynamic_versioned_xcframework",
    ],
)

apple_dynamic_xcframework_import(
    name = "imported_dynamic_versioned_xcframework",
    expected_secure_features = [
        "apple.enable_enhanced_security",
        "pointer_authentication",
    ],
    tags = common.fixture_tags,
    xcframework_imports = [":generated_dynamic_macos_versioned_xcframework"],
)

objc_library(
    name = "generated_dynamic_macos_versioned_xcframework_lib",
    srcs = ["//test/starlark_tests/resources/frameworks:SharedClass.m"],
    hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    tags = common.fixture_tags,
)

apple_xcframework(
    name = "generated_dynamic_macos_versioned_xcframework_xcframework",
    bundle_id = "com.google.example",
    bundle_name = "generated_dynamic_macos_versioned_xcframework",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    macos = {
        "device": [
            "arm64",
            "arm64e",
            "x86_64",
        ],
    },
    minimum_os_versions = {
        "macos": common.min_os_macos.min_deployment_target,
    },
    public_hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    resources = ["//test/starlark_tests/resources:Another.plist"],
    secure_features = [
        "pointer_authentication",
    ],
    tags = common.fixture_tags + ["requires-darwin"],
    deps = [
        ":generated_dynamic_macos_versioned_xcframework_lib",
    ],
)

genrule(
    name = "generated_dynamic_macos_versioned_xcframework",
    srcs = [
        ":generated_dynamic_macos_versioned_xcframework_xcframework",
    ],
    outs = [
        "generated_dynamic_macos_versioned_xcframework/generated_dynamic_macos_versioned_xcframework.xcframework/Info.plist",
        "generated_dynamic_macos_versioned_xcframework/generated_dynamic_macos_versioned_xcframework.xcframework/macos-arm64_arm64e_x86_64/generated_dynamic_macos_versioned_xcframework.framework/Versions/A/Headers/SharedClass.h",
        "generated_dynamic_macos_versioned_xcframework/generated_dynamic_macos_versioned_xcframework.xcframework/macos-arm64_arm64e_x86_64/generated_dynamic_macos_versioned_xcframework.framework/Versions/A/Headers/generated_dynamic_macos_versioned_xcframework.h",
        "generated_dynamic_macos_versioned_xcframework/generated_dynamic_macos_versioned_xcframework.xcframework/macos-arm64_arm64e_x86_64/generated_dynamic_macos_versioned_xcframework.framework/Versions/A/Modules/module.modulemap",
        "generated_dynamic_macos_versioned_xcframework/generated_dynamic_macos_versioned_xcframework.xcframework/macos-arm64_arm64e_x86_64/generated_dynamic_macos_versioned_xcframework.framework/Versions/A/Resources/Info.plist",
        "generated_dynamic_macos_versioned_xcframework/generated_dynamic_macos_versioned_xcframework.xcframework/macos-arm64_arm64e_x86_64/generated_dynamic_macos_versioned_xcframework.framework/Versions/A/generated_dynamic_macos_versioned_xcframework",
        "generated_dynamic_macos_versioned_xcframework/generated_dynamic_macos_versioned_xcframework.xcframework/macos-arm64_arm64e_x86_64/generated_dynamic_macos_versioned_xcframework.framework/generated_dynamic_macos_versioned_xcframework",
    ],
    cmd = common.extract_xcframework_cmd("generated_dynamic_macos_versioned_xcframework"),
    tags = common.fixture_tags,
)

macos_application(
    name = "app_with_imported_static_unversioned_xcframework",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = common.min_os_macos.nplus1,
    secure_features = [
        "apple.enable_enhanced_security",
        "pointer_authentication",
    ],
    tags = common.fixture_tags,
    deps = [
        ":static_unversioned_xcframework_depending_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

objc_library(
    name = "static_unversioned_xcframework_depending_lib",
    tags = common.fixture_tags,
    deps = [
        ":imported_static_unversioned_xcframework",
    ],
)

apple_static_xcframework_import(
    name = "imported_static_unversioned_xcframework",
    expected_secure_features = [
        "apple.enable_enhanced_security",
        "pointer_authentication",
    ],
    tags = common.fixture_tags,
    xcframework_imports = [":generated_static_macos_unversioned_xcframework"],
)

objc_library(
    name = "generated_static_macos_unversioned_xcframework_lib",
    srcs = ["//test/starlark_tests/resources/frameworks:SharedClass.m"],
    hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    tags = common.fixture_tags,
)

apple_static_xcframework(
    name = "generated_static_macos_unversioned_xcframework_xcframework",
    bundle_format = "framework",
    bundle_id = "com.google.mock",
    bundle_name = "generated_static_macos_unversioned_xcframework",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    macos = {
        "device": [
            "arm64",
            "arm64e",
            "x86_64",
        ],
    },
    minimum_os_versions = {
        "macos": common.min_os_macos.min_deployment_target,
    },
    public_hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    resources = ["//test/starlark_tests/resources:Another.plist"],
    secure_features = [
        "pointer_authentication",
    ],
    tags = common.fixture_tags + ["requires-darwin"],
    deps = [
        ":generated_static_macos_unversioned_xcframework_lib",
    ],
)

genrule(
    name = "generated_static_macos_unversioned_xcframework",
    srcs = [
        ":generated_static_macos_unversioned_xcframework_xcframework",
    ],
    outs = [
        "generated_static_macos_unversioned_xcframework/generated_static_macos_unversioned_xcframework.xcframework/Info.plist",
        "generated_static_macos_unversioned_xcframework/generated_static_macos_unversioned_xcframework.xcframework/macos-arm64_arm64e_x86_64/generated_static_macos_unversioned_xcframework.framework/Headers/SharedClass.h",
        "generated_static_macos_unversioned_xcframework/generated_static_macos_unversioned_xcframework.xcframework/macos-arm64_arm64e_x86_64/generated_static_macos_unversioned_xcframework.framework/Headers/generated_static_macos_unversioned_xcframework.h",
        "generated_static_macos_unversioned_xcframework/generated_static_macos_unversioned_xcframework.xcframework/macos-arm64_arm64e_x86_64/generated_static_macos_unversioned_xcframework.framework/Modules/module.modulemap",
        "generated_static_macos_unversioned_xcframework/generated_static_macos_unversioned_xcframework.xcframework/macos-arm64_arm64e_x86_64/generated_static_macos_unversioned_xcframework.framework/Resources/Another.plist",
        "generated_static_macos_unversioned_xcframework/generated_static_macos_unversioned_xcframework.xcframework/macos-arm64_arm64e_x86_64/generated_static_macos_unversioned_xcframework.framework/generated_static_macos_unversioned_xcframework",
    ],
    cmd = common.extract_xcframework_cmd("generated_static_macos_unversioned_xcframework") + """
        FMWK="$$DEST/macos-arm64_arm64e_x86_64/generated_static_macos_unversioned_xcframework.framework"
        # Remove symlinks
        rm -f "$$FMWK/generated_static_macos_unversioned_xcframework" "$$FMWK/Headers" "$$FMWK/Modules" "$$FMWK/Resources"
        # Move Versions/A/* out
        mv "$$FMWK/Versions/A/"* "$$FMWK/"
        rm -rf "$$FMWK/Versions"
    """,
    tags = common.fixture_tags,
)

macos_application(
    name = "app_with_imported_static_versioned_xcframework",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = common.min_os_macos.nplus1,
    secure_features = [
        "apple.enable_enhanced_security",
        "pointer_authentication",
    ],
    tags = common.fixture_tags,
    deps = [
        ":static_versioned_xcframework_depending_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

objc_library(
    name = "static_versioned_xcframework_depending_lib",
    tags = common.fixture_tags,
    deps = [
        ":imported_static_versioned_xcframework",
    ],
)

apple_static_xcframework_import(
    name = "imported_static_versioned_xcframework",
    expected_secure_features = [
        "apple.enable_enhanced_security",
        "pointer_authentication",
    ],
    tags = common.fixture_tags,
    xcframework_imports = [":generated_static_macos_versioned_xcframework"],
)

objc_library(
    name = "generated_static_macos_versioned_xcframework_lib",
    srcs = ["//test/starlark_tests/resources/frameworks:SharedClass.m"],
    hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    tags = common.fixture_tags,
)

apple_static_xcframework(
    name = "generated_static_macos_versioned_xcframework_xcframework",
    bundle_format = "framework",
    bundle_id = "com.google.macos-versioned",
    bundle_name = "generated_static_macos_versioned_xcframework",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    macos = {
        "device": [
            "arm64",
            "arm64e",
            "x86_64",
        ],
    },
    minimum_os_versions = {
        "macos": common.min_os_macos.min_deployment_target,
    },
    public_hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    resources = ["//test/starlark_tests/resources:Another.plist"],
    secure_features = [
        "pointer_authentication",
    ],
    tags = common.fixture_tags + ["requires-darwin"],
    deps = [
        ":generated_static_macos_versioned_xcframework_lib",
    ],
)

genrule(
    name = "generated_static_macos_versioned_xcframework",
    srcs = [
        ":generated_static_macos_versioned_xcframework_xcframework",
    ],
    outs = [
        "generated_static_macos_versioned_xcframework/generated_static_macos_versioned_xcframework.xcframework/macos-arm64_arm64e_x86_64/generated_static_macos_versioned_xcframework.framework/Versions/A/Modules/module.modulemap",
        "generated_static_macos_versioned_xcframework/generated_static_macos_versioned_xcframework.xcframework/macos-arm64_arm64e_x86_64/generated_static_macos_versioned_xcframework.framework/Versions/A/Headers/generated_static_macos_versioned_xcframework.h",
        "generated_static_macos_versioned_xcframework/generated_static_macos_versioned_xcframework.xcframework/macos-arm64_arm64e_x86_64/generated_static_macos_versioned_xcframework.framework/Versions/A/Headers/SharedClass.h",
        "generated_static_macos_versioned_xcframework/generated_static_macos_versioned_xcframework.xcframework/macos-arm64_arm64e_x86_64/generated_static_macos_versioned_xcframework.framework/Versions/A/Resources/Info.plist",
        "generated_static_macos_versioned_xcframework/generated_static_macos_versioned_xcframework.xcframework/macos-arm64_arm64e_x86_64/generated_static_macos_versioned_xcframework.framework/Versions/A/generated_static_macos_versioned_xcframework",
        "generated_static_macos_versioned_xcframework/generated_static_macos_versioned_xcframework.xcframework/macos-arm64_arm64e_x86_64/generated_static_macos_versioned_xcframework.framework/generated_static_macos_versioned_xcframework",
        "generated_static_macos_versioned_xcframework/generated_static_macos_versioned_xcframework.xcframework/Info.plist",
    ],
    cmd = common.extract_xcframework_cmd("generated_static_macos_versioned_xcframework"),
    tags = common.fixture_tags,
)

# ---------------------------------------------------------------------------------------

macos_bundle(
    name = "bundle",
    additional_contents = {
        "//test/starlark_tests/resources:additional.txt": "Additional",
        "//test/starlark_tests/resources:all_nested": "Nested",
    },
    bundle_id = "com.google.example",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_macos.provisionprofile",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_bundle(
    name = "bundle_for_app",
    bundle_id = "com.google.example",
    bundle_loader = ":app",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_bundle(
    name = "bundle_for_cmd_app",
    bundle_id = "com.google.example",
    bundle_loader = ":cmd_app_basic",
    infoplists = [
        "//test/starlark_tests/resources:Info-nopackage.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_bundle(
    name = "bundle_dead_stripped",
    additional_contents = {
        "//test/starlark_tests/resources:additional.txt": "Additional",
        "//test/starlark_tests/resources:all_nested": "Nested",
    },
    bundle_id = "com.google.example",
    exported_symbols_lists = [
        "//test/starlark_tests/resources:ExportAnotherFunctionShared.exp",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    linkopts = ["-dead_strip"],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_bundle(
    name = "bundle_special_linkopts",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    linkopts = [
        "-alias",
        "_anotherFunctionShared",
        "_linkopts_test_anotherFunctionShared",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_bundle(
    name = "bundle_with_different_extension",
    bundle_extension = "prefPane",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

# ---------------------------------------------------------------------------------------

macos_command_line_application(
    name = "cmd_app_basic",
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib_with_common_lib",
    ],
)

macos_command_line_application(
    name = "cmd_app_basic_swift",
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:swift_main_lib",
    ],
)

macos_command_line_application(
    name = "cmd_app_info_plists",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Another.plist",
        "//test/starlark_tests/resources:Info-nopackage.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_macos.provisionprofile",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_command_line_application(
    name = "cmd_app_info_and_launchd_plists",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Another.plist",
        "//test/starlark_tests/resources:Info-nopackage.plist",
    ],
    launchdplists = [
        "//test/starlark_tests/resources:Another.plist",
        "//test/starlark_tests/resources:launchd.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_command_line_application(
    name = "cmd_app_special_linkopts",
    linkopts = [
        "-alias",
        "_main",
        "_linkopts_test_main",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_command_line_application(
    name = "cmd_app_dead_stripped",
    exported_symbols_lists = [
        "//test/starlark_tests/resources:ExportAnotherFunctionMain.exp",
    ],
    linkopts = ["-dead_strip"],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_command_line_application(
    name = "cmd_app_basic_version",
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    version = "//test/starlark_tests/targets_under_test/apple:manual_1_2_build_1_2_3_version",
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

# ---------------------------------------------------------------------------------------

macos_dylib(
    name = "dylib",
    minimum_os_version = common.min_os_macos.min_deployment_target,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_macos.provisionprofile",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_dylib(
    name = "dylib_dead_stripped",
    exported_symbols_lists = [
        "//test/starlark_tests/resources:ExportAnotherFunctionShared.exp",
    ],
    linkopts = ["-dead_strip"],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

# ---------------------------------------------------------------------------------------

macos_ui_test(
    name = "ui_test",
    additional_contents = {
        "//test/starlark_tests/resources:additional.txt": "Additional",
        "//test/starlark_tests/resources:all_nested": "Nested",
    },
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    runner = "//test/starlark_tests/targets_under_test/apple:dummy_test_runner",
    tags = common.fixture_tags,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

macos_ui_test(
    name = "ui_test_custom_bundle_id",
    bundle_id = "my.test.bundle.id",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    runner = "//test/starlark_tests/targets_under_test/apple:dummy_test_runner",
    tags = common.fixture_tags,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

macos_ui_test(
    name = "ui_test_invalid_bundle_id",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    runner = "//test/starlark_tests/targets_under_test/apple:dummy_test_runner",
    tags = common.fixture_tags,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

macos_ui_test(
    name = "ui_test_dummy_runner",
    additional_contents = {
        "//test/starlark_tests/resources:additional.txt": "Additional",
        "//test/starlark_tests/resources:all_nested": "Nested",
    },
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    runner = "//test/starlark_tests/targets_under_test/apple:dummy_test_runner",
    tags = common.fixture_tags,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

# ---------------------------------------------------------------------------------------

macos_unit_test(
    name = "unit_test",
    additional_contents = {
        "//test/starlark_tests/resources:additional.txt": "Additional",
        "//test/starlark_tests/resources:all_nested": "Nested",
    },
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    runner = "//test/starlark_tests/targets_under_test/apple:dummy_test_runner",
    tags = common.fixture_tags,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

macos_unit_test(
    name = "unit_test_no_host",
    additional_contents = {
        "//test/starlark_tests/resources:additional.txt": "Additional",
        "//test/starlark_tests/resources:all_nested": "Nested",
    },
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    runner = "//test/starlark_tests/targets_under_test/apple:dummy_test_runner",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

macos_unit_test(
    name = "unit_test_custom_bundle_id",
    bundle_id = "my.test.bundle.id",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    runner = "//test/starlark_tests/targets_under_test/apple:dummy_test_runner",
    tags = common.fixture_tags,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

macos_unit_test(
    name = "unit_test_invalid_bundle_id",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    runner = "//test/starlark_tests/targets_under_test/apple:dummy_test_runner",
    tags = common.fixture_tags,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

macos_unit_test(
    name = "unit_test_dummy_runner",
    additional_contents = {
        "//test/starlark_tests/resources:additional.txt": "Additional",
        "//test/starlark_tests/resources:all_nested": "Nested",
    },
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    runner = "//test/starlark_tests/targets_under_test/apple:dummy_test_runner",
    tags = common.fixture_tags,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

macos_unit_test(
    name = "unit_test_data_deps",
    data = [":runfiles1"],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    runner = "//test/starlark_tests/targets_under_test/apple:dummy_test_runner",
    tags = common.fixture_tags,
)

filegroup(
    name = "runfiles1",
    # NOTE: we specify `data` instead of `srcs` because `data` puts the files
    # into runfiles, while `srcs` puts them into the default outputs.
    data = [
        "runfile1.txt",
        # Add a second-order dependency to check that the transitive runfiles
        # are being added.
        ":runfiles2",
    ],
    tags = common.fixture_tags,
)

filegroup(
    name = "runfiles2",
    # NOTE: we specify `data` instead of `srcs` because `data` puts the files
    # into runfiles, while `srcs` puts them into the default outputs.
    data = ["runfile2.txt"],
    tags = common.fixture_tags,
)

# ---------------------------------------------------------------------------------------
# Targets for AppIntents

macos_application(
    name = "app_with_app_intents",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.app_intents_support,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:hinted_app_intent",
        "//test/starlark_tests/resources:objc_main_lib_with_common_lib",
    ],
)

macos_application(
    name = "app_with_transitive_app_intents",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.app_intents_support,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib_with_common_lib_referencing_app_intent",
    ],
)

macos_extension(
    name = "ext_with_transitive_app_intents",
    bundle_id = "com.google.example.ext",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.app_intents_support,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_macos.provisionprofile",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib_with_common_lib_referencing_app_intent",
    ],
)
# ---------------------------------------------------------------------------------------
# Targets for base_bundle_id and bundle_id flows with and without shared capabilities.

macos_application(
    name = "app_with_capability_set_derived_bundle_id",
    bundle_name = "app-with-capability-set-derived-bundle-id",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    shared_capabilities = [
        "//test/starlark_tests/targets_under_test/apple/capabilities:base_capability_set",
    ],
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_bundle(
    name = "bundle_with_capability_set_derived_bundle_id",
    bundle_name = "bundle-with-capability-set-derived-bundle-id",
    infoplists = [
        "//test/starlark_tests/resources:Info-nopackage.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    shared_capabilities = [
        "//test/starlark_tests/targets_under_test/apple/capabilities:base_capability_set",
    ],
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_command_line_application(
    name = "cmd_app_with_capability_set_derived_bundle_id",
    bundle_id_suffix = "cmd-app-with-capability-set-derived-bundle-id",
    infoplists = [
        "//test/starlark_tests/resources:Info-nopackage.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    shared_capabilities = [
        "//test/starlark_tests/targets_under_test/apple/capabilities:base_capability_set",
    ],
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib_with_common_lib",
    ],
)

macos_extension(
    name = "ext_with_capability_set_derived_bundle_id",
    bundle_name = "ext-with-capability-set-derived-bundle-id",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    shared_capabilities = [
        "//test/starlark_tests/targets_under_test/apple/capabilities:base_capability_set",
    ],
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_ui_test(
    name = "ui_test_with_base_bundle_id_derived_bundle_id",
    base_bundle_id = "//test/starlark_tests/targets_under_test/apple/capabilities:base_bundle_id",
    bundle_id_suffix = "ui-test-with-base-bundle-id-derived-bundle-id",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    runner = "//test/starlark_tests/targets_under_test/apple:dummy_test_runner",
    tags = common.fixture_tags,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

macos_unit_test(
    name = "unit_test_with_base_bundle_id_derived_bundle_id",
    base_bundle_id = "//test/starlark_tests/targets_under_test/apple/capabilities:base_bundle_id",
    bundle_id_suffix = "unit-test-with-base-bundle-id-derived-bundle-id",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    runner = "//test/starlark_tests/targets_under_test/apple:dummy_test_runner",
    tags = common.fixture_tags,
    test_host = ":app",
    deps = [
        "//test/starlark_tests/resources:objc_test_lib",
    ],
)

# ---------------------------------------------------------------------------------------
# Targets for apple_resource_locales testing.

macos_application(
    name = "macos_locale_it",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    resource_locales = "//test/starlark_tests/resources:locales_it",
    resources = [
        "//test/starlark_tests/resources:localized_strings",
    ],
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

# ---------------------------------------------------------------------------------------
# Targets for secure_features testing.

macos_dylib(
    name = "simple_enhanced_security_dylib_with_rule_level_disabled_features",
    features = [
        "-trivial_auto_var_init",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_macos.provisionprofile",
    secure_features = [
        "trivial_auto_var_init",
    ],
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_dylib(
    name = "simple_trivial_auto_var_init_dylib",
    minimum_os_version = common.min_os_macos.min_deployment_target,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_macos.provisionprofile",
    secure_features = [
        "trivial_auto_var_init",
    ],
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_dylib(
    name = "pointer_authentication_dylib",
    minimum_os_version = common.min_os_macos.min_deployment_target,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_macos.provisionprofile",
    secure_features = [
        "apple.enable_enhanced_security",
        "pointer_authentication",
    ],
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

# ---------------------------------------------------------------------------------------
# Tests for the `building_apple_bundle` build setting.

config_setting(
    name = "is_building_apple_bundle",
    flag_values = {
        "//apple/build_settings:building_apple_bundle": "True",
    },
)

genrule(
    name = "is_building_apple_bundle_src",
    outs = ["IsBuildingAppleBundle.m"],
    cmd = """
cat > $@ <<'EOF'
__attribute__((used)) void IS_BUILDING_APPLE_BUNDLE_SYMBOL() {}
int main() { return 0; }
EOF
""",
    tags = common.fixture_tags,
)

objc_library(
    name = "is_building_apple_bundle_lib",
    srcs = ["IsBuildingAppleBundle.m"],
    copts = select({
        ":is_building_apple_bundle": ["-DIS_BUILDING_APPLE_BUNDLE_SYMBOL=IsBuildingAppleBundle"],
        "//conditions:default": ["-DIS_BUILDING_APPLE_BUNDLE_SYMBOL=IsNotBuildingAppleBundle"],
    }),
    tags = common.fixture_tags,
)

macos_command_line_application(
    name = "cmd_app_to_test_building_apple_bundle",
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        ":is_building_apple_bundle_lib",
    ],
)

macos_application(
    name = "bundled_app_to_test_building_apple_bundle",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        ":is_building_apple_bundle_lib",
    ],
)

macos_framework(
    name = "fmwk",
    bundle_id = "com.google.example.framework",
    extension_safe = True,
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:framework_resources_lib",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_application(
    name = "app_with_fmwk",
    bundle_id = "com.google.example",
    frameworks = [":fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_application(
    name = "app_with_fmwk_and_resources",
    bundle_id = "com.google.example",
    frameworks = [":fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    visibility = [
        "//test/starlark_tests:__subpackages__",
    ],
    deps = [
        "//test/starlark_tests/resources:apple_non_localized_assets_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

objc_library(
    name = "objc_lib_with_generated_resources",
    data = [
        "//test/starlark_tests/resources:generate_strings",
    ],
    tags = common.fixture_tags,
)

macos_framework(
    name = "fmwk_with_generated_resources",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        ":objc_lib_with_generated_resources",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_application(
    name = "app_with_fmwk_with_generated_resources",
    bundle_id = "com.google.example",
    frameworks = [":fmwk_with_generated_resources"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_framework(
    name = "fmwk_with_apple_resource_bundle",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:bundle_library_apple_lib",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_application(
    name = "app_with_fmwk_with_apple_resource_bundle",
    bundle_id = "com.google.example",
    frameworks = [":fmwk_with_apple_resource_bundle"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_extension(
    name = "ext_with_fmwk",
    bundle_id = "com.google.example.ext",
    frameworks = [":fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_application(
    name = "app_with_ext_with_fmwk",
    bundle_id = "com.google.example",
    extensions = [":ext_with_fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

# Helper libraries

macos_framework(
    name = "fmwk_no_version",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Info-noversion.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_application(
    name = "app_with_ext_and_fmwk",
    bundle_id = "com.google.example",
    extensions = [":ext_with_fmwk"],
    frameworks = [":fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_framework(
    name = "fmwk_with_duplicate_resource_names",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:fmwk_structured_resources_lib",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_application(
    name = "app_with_same_resource_names_as_framework",
    bundle_id = "com.google.example",
    frameworks = [":fmwk_with_duplicate_resource_names"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:app_structured_resources_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_framework(
    name = "fmwk_min_os_baseline_with_bundle",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:basic_bundle_lib",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_application(
    name = "app_with_fmwk_with_bundle_resources",
    bundle_id = "com.google.example",
    frameworks = [":fmwk_min_os_baseline_with_bundle"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_framework(
    name = "fmwk_with_resources",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib_with_resources",
    ],
)

macos_application(
    name = "app_with_framework_and_shared_resources",
    bundle_id = "com.google.example",
    frameworks = [":fmwk_with_resources"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:lib_with_structured_resources",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_application(
    name = "app_with_framework_and_resources",
    bundle_id = "com.google.example",
    frameworks = [":fmwk_with_resources"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
        "//test/starlark_tests/resources:objc_shared_lib_with_resources",
    ],
)

macos_framework(
    name = "fmwk_with_fmwk",
    bundle_id = "com.google.example.framework",
    frameworks = [":fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_application(
    name = "app_with_fmwk_with_fmwk",
    bundle_id = "com.google.example",
    frameworks = [":fmwk_with_fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_framework(
    name = "fmwk_multiple_infoplists",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Another.plist",
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_framework(
    name = "fmwk_stripped",
    bundle_id = "com.google.example.framework",
    exported_symbols_lists = [
        "//test/starlark_tests/resources:ExportAnotherFunctionShared.exp",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    linkopts = ["-x"],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_framework(
    name = "fmwk_dead_stripped",
    bundle_id = "com.google.example.framework",
    exported_symbols_lists = [
        "//test/starlark_tests/resources:ExportAnotherFunctionShared.exp",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    linkopts = ["-dead_strip"],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_framework(
    name = "fmwk_with_imported_fmwk",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        ":imported_dynamic_versioned_fmwk",
        "//test/starlark_tests/resources:objc_shared_lib_with_resources",
    ],
)

macos_application(
    name = "app_with_inner_and_outer_fmwk",
    bundle_id = "com.google.example",
    frameworks = [":fmwk_with_imported_fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_framework(
    name = "fmwk_min_os_nplus1",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.nplus1,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_application(
    name = "app_with_baseline_min_os_and_nplus1_fmwk",
    bundle_id = "com.google.example",
    frameworks = [":fmwk_min_os_nplus1"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

# Targets for macOS extension framework tests:

objc_library(
    name = "macOSStaticFramework_lib",
    srcs = ["//test/starlark_tests/resources/frameworks:SharedClass.m"],
    hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    tags = common.fixture_tags,
)

apple_static_xcframework(
    name = "macOSStaticFramework_xcframework",
    bundle_format = "framework",
    bundle_id = "com.google.macOSStaticFramework",
    bundle_name = "macOSStaticFramework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    macos = {
        "device": [
            "arm64",
        ],
    },
    minimum_os_versions = {
        "macos": common.min_os_macos.min_deployment_target,
    },
    public_hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    resources = ["//test/starlark_tests/resources:resource_bundle"],
    tags = common.fixture_tags + ["requires-darwin"],
    deps = [
        ":macOSStaticFramework_lib",
    ],
)

genrule(
    name = "macOSStaticFramework",
    srcs = [
        ":macOSStaticFramework_xcframework",
    ],
    outs = [
        "macOSStaticFramework.framework/Versions/A/Headers/SharedClass.h",
        "macOSStaticFramework.framework/Versions/A/Headers/macOSStaticFramework.h",
        "macOSStaticFramework.framework/Versions/A/Modules/module.modulemap",
        "macOSStaticFramework.framework/Versions/A/Resources/Info.plist",
        "macOSStaticFramework.framework/Versions/A/Resources/resource_bundle.bundle/Info.plist",
        "macOSStaticFramework.framework/Versions/A/macOSStaticFramework",
        "macOSStaticFramework.framework/macOSStaticFramework",
    ],
    cmd = common.extract_xcframework_cmd("macOSStaticFramework"),
    tags = common.fixture_tags,
)

objc_library(
    name = "macOSDynamicFramework_lib",
    srcs = ["//test/starlark_tests/resources/frameworks:SharedClass.m"],
    hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    tags = common.fixture_tags,
)

apple_xcframework(
    name = "macOSDynamicFramework_xcframework",
    bundle_id = "com.google.example",
    bundle_name = "macOSDynamicFramework",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    macos = {
        "device": [
            "arm64",
        ],
    },
    minimum_os_versions = {
        "macos": common.min_os_macos.min_deployment_target,
    },
    public_hdrs = ["//test/starlark_tests/resources/frameworks:SharedClass.h"],
    resources = ["//test/starlark_tests/resources:resource_bundle"],
    tags = common.fixture_tags + ["requires-darwin"],
    visibility = ["//visibility:public"],
    deps = [
        ":macOSDynamicFramework_lib",
    ],
)

genrule(
    name = "macOSDynamicFramework",
    srcs = [
        ":macOSDynamicFramework_xcframework",
    ],
    outs = [
        "macOSDynamicFramework.framework/Versions/A/Headers/SharedClass.h",
        "macOSDynamicFramework.framework/Versions/A/Headers/macOSDynamicFramework.h",
        "macOSDynamicFramework.framework/Versions/A/Modules/module.modulemap",
        "macOSDynamicFramework.framework/Versions/A/Resources/Info.plist",
        "macOSDynamicFramework.framework/Versions/A/Resources/resource_bundle.bundle/Info.plist",
        "macOSDynamicFramework.framework/Versions/A/macOSDynamicFramework",
        "macOSDynamicFramework.framework/macOSDynamicFramework",
    ],
    cmd = common.extract_xcframework_cmd("macOSDynamicFramework"),
    tags = common.fixture_tags,
    visibility = ["//visibility:public"],
)

apple_static_framework_import(
    name = "macOSImportedStaticFramework",
    features = ["-swift.layering_check_for_c_deps"],
    framework_imports = [":macOSStaticFramework"],
    tags = common.fixture_tags,
    deps = [
    ],
)

apple_dynamic_framework_import(
    name = "macOSImportedDynamicFramework",
    features = ["-swift.layering_check_for_c_deps"],
    framework_imports = [":macOSDynamicFramework"],
    tags = common.fixture_tags,
    deps = [
    ],
)

macos_application(
    name = "app_with_imported_static_fmwk_and_ext",
    bundle_id = "com.google.example",
    extensions = [":ext"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        ":macOSImportedStaticFramework",
        "//test/starlark_tests/resources:another_plist_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

macos_application(
    name = "app_with_imported_dynamic_fmwk_and_ext",
    bundle_id = "com.google.example",
    extensions = [":ext"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        ":macOSImportedDynamicFramework",
        "//test/starlark_tests/resources:another_plist_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

objc_library(
    name = "objc_lib_with_macos_framework",
    srcs = [
        "//test/starlark_tests/resources:shared.h",
        "//test/starlark_tests/resources:shared.m",
    ],
    data = [
        ":fmwk_with_resources",
        ":mac_resource_group_with_framework",
    ],
    tags = common.fixture_tags,
)

apple_resource_group(
    name = "mac_resource_group_with_framework",
    resources = [":fmwk_no_version"],
    tags = common.fixture_tags,
)

swift_library(
    name = "swift_lib_with_macos_framework",
    srcs = ["//test/starlark_tests/resources:DummySwiftFile"],
    data = [":fmwk_min_os_baseline_with_bundle"],
    tags = common.fixture_tags,
)

macos_extension(
    name = "ext_with_fmwks_from_objc_swift_libraries_using_data",
    bundle_id = "com.google.example.ext",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = [
        ":objc_lib_with_macos_framework",
        ":swift_lib_with_macos_framework",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

# ---------------------------------------------------------------------------------------
# Targets for App Intents testing in macOS frameworks.

macos_framework(
    name = "framework_with_app_intents",
    bundle_id = "com.google.example.framework",
    extension_safe = 1,
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.app_intents_support,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:framework_defined_app_intent",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_application(
    name = "app_with_framework_app_intents",
    bundle_id = "com.google.example",
    frameworks = [":framework_with_app_intents"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.app_intents_support,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:framework_app_intent_dependent_main",
        "//test/starlark_tests/resources:framework_defined_app_intent",
    ],
)

macos_framework(
    name = "framework_with_multi_module_app_intents",
    bundle_id = "com.google.example.framework",
    extension_safe = 1,
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.app_intents_package_support,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:framework_defined_app_intent_with_dependency",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

macos_application(
    name = "app_with_multi_module_framework_app_intents",
    bundle_id = "com.google.example",
    frameworks = [":framework_with_multi_module_app_intents"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.app_intents_package_support,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:framework_app_intent_dependent_main_with_dependency",
        "//test/starlark_tests/resources:framework_defined_app_intent_with_dependency",
    ],
)

objc_library(
    name = "load_deferred_framework_app_intents",
    data = [":framework_with_app_intents"],
)

macos_application(
    name = "app_with_load_deferred_framework_app_intents",
    bundle_id = "com.google.example",
    frameworks = [":framework_with_app_intents"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.app_intents_support,
    tags = common.fixture_tags,
    deps = [
        ":load_deferred_framework_app_intents",
        "//test/starlark_tests/resources:framework_app_intent_dependent_main",
        "//test/starlark_tests/resources:framework_defined_app_intent",
    ],
)

# ---------------------------------------------------------------------------------------
# Targets for testing basic bundling behavior.

macos_application(
    name = "macos_app_fixture",
    bundle_id = "my.bundle.id",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:objc_main_lib"],
)

macos_application(
    name = "macos_app_w_post_processor",
    bundle_id = "my.bundle.id",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    ipa_post_processor = "//test/starlark_tests/resources:post_processor.sh",
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:objc_main_lib"],
)

macos_bundle(
    name = "macos_bundle_fixture",
    bundle_id = "my.bundle.id",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:objc_main_lib"],
)

macos_bundle(
    name = "macos_bundle_w_post_processor",
    bundle_id = "my.bundle.id",
    infoplists = ["//test/starlark_tests/resources:Info.plist"],
    ipa_post_processor = "//test/starlark_tests/resources:post_processor.sh",
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:objc_main_lib"],
)

macos_application(
    name = "app_minimum_os_intel_deprecation",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.os_27_mandates,
    tags = common.fixture_tags,
    deps = ["//test/starlark_tests/resources:objc_main_lib"],
)

# ---------------------------------------------------------------------------------------
# Target for Unversioned Framework Failure test
# ---------------------------------------------------------------------------------------

genrule(
    name = "generated_macos_dynamic_unversioned_fmwk",
    srcs = [
        ":generated_macos_dynamic_fmwk_xcframework",
    ],
    outs = [
        "generated_macos_dynamic_unversioned_fmwk.framework/Headers/SharedClass.h",
        "generated_macos_dynamic_unversioned_fmwk.framework/Headers/generated_macos_dynamic_fmwk.h",
        "generated_macos_dynamic_unversioned_fmwk.framework/Modules/module.modulemap",
        "generated_macos_dynamic_unversioned_fmwk.framework/Resources/Info.plist",
        "generated_macos_dynamic_unversioned_fmwk.framework/generated_macos_dynamic_unversioned_fmwk",
    ],
    # Purposely un-version the framework by pulling contents out of Versions/A and putting them directly into the root.
    # This intentionally corrupts the strict macOS framework layout to test that Starlark correctly rejects it.
    cmd = "mkdir -p $(@D)/generated_macos_dynamic_unversioned_fmwktmp && for f in $(locations :generated_macos_dynamic_fmwk_xcframework); do if [[ \"$$f\" == *.xcframework.zip ]] && unzip -tq \"$$f\" &>/dev/null; then unzip -qq -o \"$$f\" -d $(@D)/generated_macos_dynamic_unversioned_fmwktmp; elif [[ \"$$f\" == *.xcframework ]] && [ -d \"$$f\" ]; then cp -a \"$$f\" $(@D)/generated_macos_dynamic_unversioned_fmwktmp/; fi; done && mkdir -p $(@D)/generated_macos_dynamic_unversioned_fmwk.framework && cp -a $(@D)/generated_macos_dynamic_unversioned_fmwktmp/*.xcframework/*/*.framework/Versions/A/* $(@D)/generated_macos_dynamic_unversioned_fmwk.framework/ 2>/dev/null || true ; mv $(@D)/generated_macos_dynamic_unversioned_fmwk.framework/generated_macos_dynamic_fmwk $(@D)/generated_macos_dynamic_unversioned_fmwk.framework/generated_macos_dynamic_unversioned_fmwk ; rm -rf $(@D)/generated_macos_dynamic_unversioned_fmwktmp",
    tags = common.fixture_tags,
)

apple_dynamic_framework_import(
    name = "imported_macos_dynamic_unversioned_fmwk",
    framework_imports = [":generated_macos_dynamic_unversioned_fmwk"],
    tags = common.fixture_tags,
)

objc_library(
    name = "dynamic_unversioned_fmwk_depending_lib",
    tags = common.fixture_tags,
    deps = [":imported_macos_dynamic_unversioned_fmwk"],
)

macos_application(
    name = "app_with_imported_unversioned_fmwk",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_macos.min_deployment_target,
    tags = [
        "manual",
        "notap",
    ],
    deps = [
        ":dynamic_unversioned_fmwk_depending_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)
