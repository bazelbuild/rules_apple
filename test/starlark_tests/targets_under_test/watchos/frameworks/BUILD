load("@rules_cc//cc:objc_library.bzl", "objc_library")
load(
    "//apple:apple.bzl",
    "apple_static_framework_import",
)
load(
    "//apple:watchos.bzl",
    "watchos_application",
    "watchos_extension",
    "watchos_framework",
)
load(
    "//test/starlark_tests:common.bzl",
    "common",
)
load(
    "//test/starlark_tests/rules:generate_framework.bzl",
    "generate_import_framework",
)

licenses(["notice"])

package(
    default_applicable_licenses = ["//:license"],
    default_testonly = 1,
    default_visibility = ["//test/starlark_tests:__subpackages__"],
)

watchos_application(
    name = "watchos_2_application_with_watchos_framework",
    app_icons = ["//test/starlark_tests/resources:WatchAppIcon.xcassets"],
    bundle_id = "com.google.example",
    extension = "//test/starlark_tests/targets_under_test/watchos:ext",
    frameworks = [":fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:WatchosAppInfo.plist",
    ],
    minimum_os_version = common.min_os_watchos.baseline,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
)

watchos_application(
    name = "app_with_ext_with_fmwk_not_extension_safe",
    bundle_id = "com.google.example",
    extensions = [":ext_with_fmwk_not_extension_safe"],
    frameworks = [":fmwk_not_extension_safe"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

watchos_extension(
    name = "ext_with_fmwk_not_extension_safe",
    bundle_id = "com.google.example.ext",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    frameworks = [":fmwk_not_extension_safe"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

watchos_application(
    name = "app_with_framework_depending_ext",
    bundle_id = "com.google.example",
    extensions = [":ext_with_framework"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

watchos_application(
    name = "app_with_framework_and_framework_depending_ext",
    bundle_id = "com.google.example",
    extensions = [":ext_with_framework"],
    frameworks = [":fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

watchos_extension(
    name = "ext_with_framework",
    bundle_id = "com.google.example.ext",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    frameworks = [":fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

watchos_application(
    name = "app_with_ext_min_os_nplus1",
    bundle_id = "com.google.example",
    extensions = [":ext_min_os_nplus1"],
    frameworks = [":fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

watchos_extension(
    name = "ext_min_os_nplus1",
    bundle_id = "com.google.example.ext",
    frameworks = [":fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app_nplus1,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

watchos_application(
    name = "app_with_ext_and_fmwk_with_common_structured_resources",
    bundle_id = "com.google.example",
    extensions = [":ext_with_framework_with_structured_resources"],
    frameworks = [":fmwk_with_structured_resources"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib_with_structured_images",
    ],
)

watchos_extension(
    name = "ext_with_framework_with_structured_resources",
    bundle_id = "com.google.example.ext",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    frameworks = [":fmwk_with_structured_resources"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib_with_structured_images",
    ],
)

# ---------------------------------------------------------------------------------------

watchos_application(
    name = "app_with_fmwk",
    bundle_id = "com.google.example",
    frameworks = [":fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

watchos_application(
    name = "app_with_baseline_min_os_and_nplus1_fmwk",
    bundle_id = "com.google.example",
    frameworks = [":fmwk_min_os_nplus1"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:basic_bundle_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

watchos_application(
    name = "app_structured_resources_and_fmwk_with_structured_resources",
    bundle_id = "com.google.example",
    frameworks = [":fmwk_with_structured_resources"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib_with_structured_images",
    ],
)

watchos_application(
    name = "app_with_fmwk_with_transitive_structured_resources",
    bundle_id = "com.google.example",
    frameworks = [":fmwk_with_transitive_structured_resources"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib_with_transitive_structured_images",
    ],
)

watchos_application(
    name = "app_with_fmwk_with_resource_bundles",
    bundle_id = "com.google.example",
    frameworks = [":fmwk_with_resource_bundles"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

watchos_application(
    name = "app_with_resource_bundles_and_fmwk_with_resource_bundles",
    bundle_id = "com.google.example",
    frameworks = [":fmwk_with_resource_bundles"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib_with_transitive_resource_bundles",
    ],
)

watchos_application(
    name = "app_nplus1_with_resource_bundles_and_fmwk_baseline_with_resource_bundles",
    bundle_id = "com.google.example",
    frameworks = [":fmwk_with_resource_bundles"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib_with_transitive_resource_bundles",
    ],
)

watchos_application(
    name = "app_with_two_fmwk_provisioned",
    bundle_id = "com.google.example",
    frameworks = [
        ":fmwk_with_provisioning",
        ":second_fmwk_with_provisioning",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

watchos_application(
    name = "app_with_fmwk_with_fmwk_provisioned",
    bundle_id = "com.google.example",
    frameworks = [":fmwk_with_fmwk_with_provisioning"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

watchos_application(
    name = "app_with_fmwk_with_fmwk",
    bundle_id = "com.google.example",
    frameworks = [":fmwk_with_fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
        "//test/starlark_tests/resources:Another.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

watchos_application(
    name = "app_with_imported_fmwk",
    bundle_id = "com.google.example",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
        "//test/starlark_tests/targets_under_test/watchos:dynamic_fmwk_depending_lib",
    ],
)

watchos_application(
    name = "app_with_runtime_framework_using_import_static_lib_dep",
    bundle_id = "com.google.example",
    frameworks = [":fmwk_with_imported_static_framework"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

watchos_application(
    name = "app_with_runtime_framework_using_import_framework_dep",
    bundle_id = "com.google.example",
    frameworks = [":fmwk_with_imported_dynamic_framework"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    ipa_post_processor = "//test/starlark_tests/targets_under_test/apple:ipa_post_processor_verify_codesigning",
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

watchos_framework(
    name = "fmwk",
    bundle_id = "com.google.example.framework",
    extension_safe = True,
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
        "//test/starlark_tests/resources:Another.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib_with_transitive_resources",
    ],
)

watchos_framework(
    name = "fmwk_with_no_version",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Info-noversion.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

watchos_framework(
    name = "fmwk_with_structured_resources",
    bundle_id = "com.google.example.framework",
    extension_safe = True,
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    linkopts = ["-application_extension"],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_common_lib_with_structured_images",
    ],
)

watchos_framework(
    name = "fmwk_with_transitive_structured_resources",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib_with_transitive_structured_resources",
    ],
)

watchos_framework(
    name = "fmwk_with_resource_bundles",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    resources = [],
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib_with_resource_bundles",
    ],
)

watchos_framework(
    name = "fmwk_dead_stripped",
    bundle_id = "com.google.example.framework",
    exported_symbols_lists = [
        "//test/starlark_tests/resources:ExportAnotherFunctionShared.exp",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    linkopts = ["-dead_strip"],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

watchos_framework(
    name = "fmwk_with_provisioning",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

watchos_framework(
    name = "second_fmwk_with_provisioning",
    bundle_id = "com.google.example.frameworktoo",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

watchos_framework(
    name = "fmwk_with_fmwk",
    bundle_id = "com.google.example.frameworkception",
    frameworks = [":fmwk"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
        "//test/starlark_tests/resources:Another.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:another_objc_shared_lib_with_transitive_resources",
    ],
)

watchos_framework(
    name = "fmwk_with_fmwk_with_provisioning",
    bundle_id = "com.google.example.frameworkception",
    frameworks = [":fmwk_with_provisioning"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

watchos_framework(
    name = "fmwk_with_imported_static_framework",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        ":static_fmwk_depending_lib",
    ],
)

watchos_framework(
    name = "fmwk_not_extension_safe",
    bundle_id = "com.google.example.framework",
    extension_safe = False,
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

watchos_framework(
    name = "fmwk_with_imported_dynamic_framework",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/targets_under_test/watchos:dynamic_fmwk_depending_lib",
    ],
)

objc_library(
    name = "shared_lib",
    data = [
        "//test/starlark_tests/resources:basic_bundle",
    ],
    tags = common.fixture_tags,
)

objc_library(
    name = "app_lib",
    data = [
        "//test/starlark_tests/resources:empty.strings",
    ],
    tags = common.fixture_tags,
    deps = [":shared_lib"],
)

objc_library(
    name = "test_lib",
    data = [
        "//test/starlark_tests/resources:nonlocalized.strings",
    ],
    tags = common.fixture_tags,
    deps = [":app_lib"],
)

objc_library(
    name = "main_lib",
    tags = common.fixture_tags,
    deps = [
        ":app_lib",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

watchos_framework(
    name = "dedupe_test_fmwk",
    bundle_id = "com.fmwk",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    tags = common.fixture_tags,
    deps = [
        ":shared_lib",
    ],
)

watchos_application(
    name = "dedupe_test_app",
    bundle_id = "com.app",
    frameworks = [
        ":dedupe_test_fmwk",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        ":main_lib",
    ],
)

watchos_framework(
    name = "fmwk_min_os_nplus1",
    bundle_id = "com.google.example.framework",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app_nplus1,
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:basic_bundle_lib",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

watchos_application(
    name = "app_with_framework_app_intents",
    bundle_id = "com.google.example",
    frameworks = [":framework_with_app_intents"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.app_intents_package_support,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:framework_app_intent_dependent_main",
        "//test/starlark_tests/resources:framework_defined_app_intent",
    ],
)

watchos_application(
    name = "app_with_no_exclusive_framework_app_intents",
    bundle_id = "com.google.example",
    frameworks = [":framework_with_app_intents"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.app_intents_package_support,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:framework_defined_app_intent",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

watchos_application(
    name = "app_with_load_deferred_framework_app_intents",
    bundle_id = "com.google.example",
    frameworks = [":framework_with_app_intents"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.app_intents_package_support,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        ":load_deferred_framework_app_intents",
        "//test/starlark_tests/resources:framework_app_intent_dependent_main",
        "//test/starlark_tests/resources:framework_defined_app_intent",
    ],
)

watchos_extension(
    name = "ext_with_framework_app_intents",
    bundle_id = "com.google.example.ext",
    entitlements = "//test/starlark_tests/resources:entitlements.plist",
    frameworks = [":framework_with_app_intents"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.app_intents_package_support,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:framework_app_intent_dependent_main",
        "//test/starlark_tests/resources:framework_defined_app_intent",
    ],
)

watchos_application(
    name = "app_with_ext_and_framework_app_intents",
    bundle_id = "com.google.example",
    extensions = [":ext_with_framework_app_intents"],
    frameworks = [":framework_with_app_intents"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.app_intents_package_support,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:framework_app_intent_dependent_main",
        "//test/starlark_tests/resources:framework_defined_app_intent",
    ],
)

watchos_framework(
    name = "framework_with_app_intents",
    bundle_id = "com.google.example.framework",
    extension_safe = 1,
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.app_intents_package_support,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:framework_defined_app_intent",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

watchos_application(
    name = "app_with_multi_module_framework_app_intents",
    bundle_id = "com.google.example",
    families = [
        "iphone",
        "ipad",
    ],
    frameworks = [":framework_with_multi_module_app_intents"],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.app_intents_package_support,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:framework_app_intent_dependent_main_with_dependency",
        "//test/starlark_tests/resources:framework_defined_app_intent_with_dependency",
    ],
)

watchos_framework(
    name = "framework_with_multi_module_app_intents",
    bundle_id = "com.google.example.framework",
    extension_safe = 1,
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.app_intents_package_support,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:framework_defined_app_intent_with_dependency",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

watchos_application(
    name = "app_with_transitive_widget_configuration_intent_dependency_in_app_intents_package",
    bundle_id = "com.google.example",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.app_intents_package_support,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:StaticLibraryAppIntentsWithTransitiveWidgetConfigurationDependency",
        "//test/starlark_tests/resources:objc_main_lib",
    ],
)

watchos_framework(
    name = "fmwk_with_base_bundle_id_derived_bundle_id",
    base_bundle_id = "//test/starlark_tests/targets_under_test/apple/capabilities:base_bundle_id",
    bundle_name = "fmwk-with-base-bundle-id-derived-bundle-id",
    infoplists = [
        "//test/starlark_tests/resources:Info.plist",
    ],
    minimum_os_version = common.min_os_watchos.requires_single_target_app,
    provisioning_profile = "//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    tags = common.fixture_tags,
    deps = [
        "//test/starlark_tests/resources:framework_resources_lib",
        "//test/starlark_tests/resources:objc_shared_lib",
    ],
)

# ---------------------------------------------------------------------------------------
# Targets for Apple static framework import tests.

objc_library(
    name = "static_fmwk_depending_lib",
    tags = common.fixture_tags,
    deps = [":imported_watchos_static_fmwk"],
)

apple_static_framework_import(
    name = "imported_watchos_static_fmwk",
    framework_imports = [":generated_watchos_static_fmwk"],
    tags = common.fixture_tags,
)

generate_import_framework(
    name = "generated_watchos_static_fmwk",
    # buildifier: disable=platform-specific-binaries
    archs = ["x86_64"],
    libtype = "static",
    minimum_os_version = common.min_os_watchos.baseline,
    sdk = "watchsimulator",
    tags = common.fixture_tags,
)
