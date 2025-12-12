# Internal implementation details of the Apple rules.

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load(
    ":environment_plist.bzl",
    "environment_plist",
)

bzl_library(
    name = "apple_framework_import",
    srcs = ["apple_framework_import.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":cc_toolchain_info_support",
        ":experimental",
        ":features_support",
        ":framework_import_support",
        ":providers",
        ":resources",
        ":rule_attrs",
        ":secure_features_support",
        "//apple:utils",
        "//apple/build_settings",
        "//apple/internal/aspects:swift_usage_aspect",
        "//apple/internal/providers:apple_dynamic_framework_info",
        "@bazel_skylib//lib:partial",
        "@bazel_skylib//lib:paths",
        "@bazel_skylib//rules:common_settings",
        "@bazel_tools//tools/cpp:toolchain_utils_bzl",
        "@build_bazel_rules_swift//swift:swift_clang_module_aspect",
        "@build_bazel_rules_swift//swift:swift_common",
        "@rules_cc//cc/common",
    ],
)

bzl_library(
    name = "apple_universal_binary",
    srcs = ["apple_universal_binary.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":linking_support",
        ":providers",
        ":rule_attrs",
        ":rule_factory",
        ":transition_support",
        "@build_bazel_apple_support//lib:apple_support",
    ],
)

bzl_library(
    name = "apple_product_type",
    srcs = ["apple_product_type.bzl"],
    visibility = [
        "//apple:__subpackages__",
        "//test/starlark_tests:__subpackages__",
    ],
)

bzl_library(
    name = "apple_xcframework_import",
    srcs = ["apple_xcframework_import.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":cc_toolchain_info_support",
        ":experimental",
        ":features_support",
        ":framework_import_support",
        ":intermediates",
        ":providers",
        ":rule_attrs",
        ":secure_features_support",
        "//apple/internal/aspects:swift_usage_aspect",
        "//apple/internal/providers:apple_dynamic_framework_info",
        "//apple/internal/toolchains:apple_toolchains",
        "//apple/internal/utils:bundle_paths",
        "@bazel_skylib//lib:paths",
        "@bazel_tools//tools/cpp:toolchain_utils",
        "@build_bazel_apple_support//lib:apple_support",
        "@build_bazel_rules_swift//swift:swift_clang_module_aspect",
        "@build_bazel_rules_swift//swift:swift_common",
        "@rules_cc//cc/common",
    ],
)

bzl_library(
    name = "bundle_package_type",
    srcs = ["bundle_package_type.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
)

bzl_library(
    name = "bundling_support",
    srcs = ["bundling_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":providers",
        "@build_bazel_apple_support//lib:apple_support",
    ],
)

bzl_library(
    name = "capabilities_rules",
    srcs = ["capabilities_rules.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":bundling_support",
        ":providers",
    ],
)

bzl_library(
    name = "cc_info_support",
    srcs = ["cc_info_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = ["@rules_cc//cc/common"],
)

bzl_library(
    name = "cc_toolchain_info_support",
    srcs = ["cc_toolchain_info_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
)

bzl_library(
    name = "clang_modulemap_support",
    srcs = ["clang_modulemap_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":intermediates",
    ],
)

bzl_library(
    name = "codesigning_support",
    srcs = ["codesigning_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":intermediates",
        ":rule_support",
        "//apple/internal/utils:defines",
        "@bazel_skylib//lib:paths",
        "@bazel_skylib//lib:shell",
        "@build_bazel_apple_support//lib:apple_support",
    ],
)

bzl_library(
    name = "compilation_support",
    srcs = ["compilation_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":fragment_support",
        ":outputs",
        ":platform_support",
        "@bazel_skylib//lib:paths",
        "@rules_cc//cc/common",
    ],
)

bzl_library(
    name = "entitlements_support",
    srcs = ["entitlements_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":apple_product_type",
        ":bundling_support",
        ":features_support",
        ":resource_actions",
        ":secure_features_support",
        "//apple:common",
        "//apple/internal/utils:defines",
        "@build_bazel_apple_support//lib:apple_support",
    ],
)

bzl_library(
    name = "environment_plist",
    srcs = ["environment_plist.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":platform_support",
        ":rule_attrs",
        "//apple/internal/toolchains:apple_toolchains",
        "@build_bazel_apple_support//lib:apple_support",
    ],
)

bzl_library(
    name = "experimental",
    srcs = ["experimental.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        "//apple/internal/utils:defines",
    ],
)

bzl_library(
    name = "features_support",
    srcs = ["features_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        "//apple/internal/utils:package_specs",
        "@rules_cc//cc/common",
    ],
)

bzl_library(
    name = "fragment_support",
    srcs = ["fragment_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
)

bzl_library(
    name = "framework_import_support",
    srcs = ["framework_import_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":providers",
        "//apple:utils",
        "//apple/internal/utils:files",
        "@bazel_skylib//lib:paths",
        "@build_bazel_rules_swift//swift:providers",
        "@build_bazel_rules_swift//swift:swift_common",
        "@build_bazel_rules_swift//swift:swift_interop_info",
        "@rules_cc//cc/common",
    ],
)

bzl_library(
    name = "infoplist_support",
    srcs = ["infoplist_support.bzl"],
    visibility = ["//apple:__subpackages__"],
    deps = [
        "@bazel_skylib//lib:paths",
    ],
)

bzl_library(
    name = "intermediates",
    srcs = ["intermediates.bzl"],
    visibility = [
        "//apple:__subpackages__",
        "//test:__subpackages__",
    ],
    deps = [
        "@bazel_skylib//lib:paths",
    ],
)

bzl_library(
    name = "ios_rules",
    srcs = ["ios_rules.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":apple_product_type",
        ":bundling_support",
        ":cc_info_support",
        ":entitlements_support",
        ":features_support",
        ":infoplist_support",
        ":linking_support",
        ":outputs",
        ":partials",
        ":platform_support",
        ":processor",
        ":providers",
        ":resources",
        ":rule_attrs",
        ":rule_factory",
        ":rule_support",
        ":run_support",
        ":secure_features_support",
        ":stub_support",
        ":swift_support",
        ":transition_support",
        "//apple/internal/aspects:framework_provider_aspect",
        "//apple/internal/aspects:resource_aspect",
        "//apple/internal/aspects:swift_generated_header_aspect",
        "//apple/internal/providers:swift_generated_header_info",
        "//apple/internal/toolchains:apple_toolchains",
        "//apple/internal/utils:clang_rt_dylibs",
        "@bazel_skylib//lib:collections",
        "@bazel_tools//tools/cpp:toolchain_utils",
        "@build_bazel_apple_support//lib:apple_support",
        "@rules_cc//cc/common",
    ],
)

bzl_library(
    name = "linking_support",
    srcs = [
        "linking_support.bzl",
    ],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":compilation_support",
        ":entitlements_support",
        ":intermediates",
        ":outputs",
        ":providers",
        "//apple/internal/providers:apple_dynamic_framework_info",
        "@build_bazel_apple_support//lib:lipo",
        "@rules_cc//cc/common",
        "@rules_cc//cc/private/rules_impl:objc_compilation_support_bzl",
    ],
)

bzl_library(
    name = "macos_rules",
    srcs = ["macos_rules.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":apple_product_type",
        ":bundling_support",
        ":codesigning_support",
        ":entitlements_support",
        ":features_support",
        ":intermediates",
        ":linking_support",
        ":outputs",
        ":partials",
        ":platform_support",
        ":processor",
        ":providers",
        ":resource_actions",
        ":resources",
        ":rule_attrs",
        ":rule_factory",
        ":rule_support",
        ":run_support",
        ":secure_features_support",
        ":swift_support",
        ":transition_support",
        "//apple/internal/aspects:app_intents_aspect",
        "//apple/internal/aspects:framework_provider_aspect",
        "//apple/internal/aspects:resource_aspect",
        "//apple/internal/toolchains:apple_toolchains",
        "//apple/internal/utils:clang_rt_dylibs",
        "@build_bazel_apple_support//lib:apple_support",
        "@rules_cc//cc/common",
    ],
)

bzl_library(
    name = "order_file",
    srcs = ["order_file.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = ["@rules_cc//cc/common"],
)

bzl_library(
    name = "outputs",
    srcs = ["outputs.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":experimental",
        ":fragment_support",
        ":intermediates",
        "@bazel_skylib//lib:paths",
    ],
)

bzl_library(
    name = "partials",
    srcs = ["partials.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        "//apple/internal/partials:app_assets_validation",
        "//apple/internal/partials:app_intents_metadata_bundle",
        "//apple/internal/partials:apple_bundle_info",
        "//apple/internal/partials:apple_symbols_file",
        "//apple/internal/partials:binary",
        "//apple/internal/partials:child_bundle_info_validation",
        "//apple/internal/partials:clang_rt_dylibs",
        "//apple/internal/partials:codesigning_dossier",
        "//apple/internal/partials:debug_symbols",
        "//apple/internal/partials:embedded_bundles",
        "//apple/internal/partials:extension_safe_validation",
        "//apple/internal/partials:framework_header_modulemap",
        "//apple/internal/partials:framework_headers",
        "//apple/internal/partials:framework_import",
        "//apple/internal/partials:framework_provider",
        "//apple/internal/partials:macos_additional_contents",
        "//apple/internal/partials:messages_stub",
        "//apple/internal/partials:provisioning_profile",
        "//apple/internal/partials:resources",
        "//apple/internal/partials:settings_bundle",
        "//apple/internal/partials:swift_dylibs",
        "//apple/internal/partials:swift_framework",
        "//apple/internal/partials:watchos_stub",
        "//apple/internal/providers:apple_dynamic_framework_info",
    ],
)

bzl_library(
    name = "platform_support",
    srcs = ["platform_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":providers",
        "//apple/internal/utils:platform_defaults",
        "@build_bazel_apple_support//lib:apple_support",
    ],
)

bzl_library(
    name = "processor",
    srcs = ["processor.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":bundling_support",
        ":codesigning_support",
        ":experimental",
        ":intermediates",
        ":outputs",
        ":providers",
        "@bazel_skylib//lib:partial",
        "@bazel_skylib//lib:paths",
    ],
)

bzl_library(
    name = "providers",
    srcs = ["providers.bzl"],
    visibility = [
        "//apple:__subpackages__",
        "//test:__subpackages__",
    ],
)

bzl_library(
    name = "resource_actions",
    srcs = ["resource_actions.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        "//apple/internal/resource_actions:actool",
        "//apple/internal/resource_actions:datamodel",
        "//apple/internal/resource_actions:ibtool",
        "//apple/internal/resource_actions:mlmodel",
        "//apple/internal/resource_actions:plist",
        "//apple/internal/resource_actions:png",
        "//apple/internal/resource_actions:realitytool",
        "//apple/internal/resource_actions:texture_atlas",
    ],
)

bzl_library(
    name = "resources",
    srcs = ["resources.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":providers",
        "//apple/internal/partials/support:resources_support",
        "//apple/internal/utils:bundle_paths",
        "@bazel_skylib//lib:partial",
        "@bazel_skylib//lib:paths",
        "@bazel_skylib//lib:types",
        "@rules_cc//cc/common",
    ],
)

bzl_library(
    name = "rule_attrs",
    srcs = ["rule_attrs.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":bundling_support",
        ":providers",
        "//apple:common",
        "//apple/internal/aspects:app_intents_aspect",
        "//apple/internal/aspects:framework_provider_aspect",
        "//apple/internal/aspects:resource_aspect",
        "//apple/internal/aspects:swift_usage_aspect",
        "//apple/internal/testing:apple_test_bundle_support",
        "//apple/internal/toolchains:apple_toolchains",
        "@build_bazel_apple_support//lib:apple_support",
        "@build_bazel_rules_swift//swift:providers",
        "@rules_cc//cc/common",
    ],
)

bzl_library(
    name = "rule_factory",
    srcs = ["rule_factory.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":apple_product_type",
        ":providers",
        ":rule_attrs",
        ":rule_support",
        "//apple:common",
        "//apple/internal/aspects:framework_provider_aspect",
        "//apple/internal/aspects:resource_aspect",
        "//apple/internal/aspects:swift_usage_aspect",
        "//apple/internal/testing:apple_test_bundle_support",
        "//apple/internal/testing:apple_test_rule_support",
        "@bazel_tools//tools/cpp:toolchain_utils",
        "@build_bazel_apple_support//lib:apple_support",
    ],
)

bzl_library(
    name = "rule_support",
    srcs = ["rule_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":apple_product_type",
        ":bundle_package_type",
    ],
)

bzl_library(
    name = "run_support",
    srcs = ["run_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":outputs",
    ],
)

bzl_library(
    name = "secure_features_support",
    srcs = ["secure_features_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":providers",
        "@rules_cc//cc/common",
    ],
)

bzl_library(
    name = "stub_support",
    srcs = ["stub_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":intermediates",
        "@build_bazel_apple_support//lib:apple_support",
        "@build_bazel_apple_support//lib:lipo",
    ],
)

bzl_library(
    name = "swift_info_support",
    srcs = ["swift_info_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":intermediates",
        "@build_bazel_rules_swift//swift:providers",
    ],
)

bzl_library(
    name = "swift_support",
    srcs = ["swift_support.bzl"],
    visibility = ["//apple:__subpackages__"],
    deps = [
        "//apple/internal/aspects:swift_usage_aspect",
        "@build_bazel_rules_swift//swift:providers",
    ],
)

bzl_library(
    name = "required_minimum_os",
    srcs = ["required_minimum_os.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
)

bzl_library(
    name = "transition_support",
    srcs = ["transition_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":secure_features_support",
        "//apple/build_settings",
    ],
)

bzl_library(
    name = "tvos_rules",
    srcs = ["tvos_rules.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":apple_product_type",
        ":bundling_support",
        ":cc_info_support",
        ":entitlements_support",
        ":features_support",
        ":infoplist_support",
        ":linking_support",
        ":outputs",
        ":partials",
        ":platform_support",
        ":processor",
        ":providers",
        ":resources",
        ":rule_attrs",
        ":rule_factory",
        ":rule_support",
        ":run_support",
        ":secure_features_support",
        ":swift_support",
        ":transition_support",
        "//apple/internal/aspects:app_intents_aspect",
        "//apple/internal/aspects:framework_provider_aspect",
        "//apple/internal/aspects:resource_aspect",
        "//apple/internal/aspects:swift_generated_header_aspect",
        "//apple/internal/providers:swift_generated_header_info",
        "//apple/internal/toolchains:apple_toolchains",
        "//apple/internal/utils:clang_rt_dylibs",
        "@bazel_tools//tools/cpp:toolchain_utils",
        "@build_bazel_apple_support//lib:apple_support",
        "@build_bazel_rules_swift//swift:providers",
        "@rules_cc//cc/common",
    ],
)

bzl_library(
    name = "visionos_rules",
    srcs = ["visionos_rules.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":apple_product_type",
        ":bundling_support",
        ":entitlements_support",
        ":features_support",
        ":linking_support",
        ":outputs",
        ":partials",
        ":platform_support",
        ":processor",
        ":providers",
        ":resources",
        ":rule_attrs",
        ":rule_factory",
        ":rule_support",
        ":run_support",
        ":swift_support",
        ":transition_support",
        "//apple/internal/aspects:resource_aspect",
        "//apple/internal/toolchains:apple_toolchains",
        "//apple/internal/utils:clang_rt_dylibs",
        "@build_bazel_apple_support//lib:apple_support",
        "@rules_cc//cc/common",
    ],
)

bzl_library(
    name = "watchos_rules",
    srcs = ["watchos_rules.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":apple_product_type",
        ":bundling_support",
        ":entitlements_support",
        ":features_support",
        ":linking_support",
        ":outputs",
        ":partials",
        ":platform_support",
        ":processor",
        ":providers",
        ":required_minimum_os",
        ":resources",
        ":rule_attrs",
        ":rule_factory",
        ":rule_support",
        ":run_support",
        ":stub_support",
        ":swift_support",
        ":transition_support",
        "//apple/internal/aspects:app_intents_aspect",
        "//apple/internal/aspects:framework_provider_aspect",
        "//apple/internal/aspects:resource_aspect",
        "//apple/internal/toolchains:apple_toolchains",
        "//apple/internal/utils:clang_rt_dylibs",
        "@bazel_tools//tools/cpp:toolchain_utils",
        "@build_bazel_apple_support//lib:apple_support",
    ],
)

bzl_library(
    name = "xcframework_rules",
    srcs = ["xcframework_rules.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":apple_product_type",
        ":bundling_support",
        ":cc_info_support",
        ":experimental",
        ":features_support",
        ":intermediates",
        ":linking_support",
        ":outputs",
        ":partials",
        ":platform_support",
        ":processor",
        ":providers",
        ":resource_actions",
        ":resources",
        ":rule_attrs",
        ":rule_factory",
        ":rule_support",
        ":secure_features_support",
        ":swift_support",
        ":transition_support",
        "//apple/internal:codesigning_support",
        "//apple/internal/aspects:resource_aspect",
        "//apple/internal/aspects:swift_generated_header_aspect",
        "//apple/internal/aspects:swift_usage_aspect",
        "//apple/internal/providers:swift_generated_header_info",
        "//apple/internal/providers:xcframework_deps_info",
        "//apple/internal/toolchains:apple_toolchains",
        "//apple/internal/utils:files",
        "@bazel_skylib//lib:partial",
        "@bazel_skylib//lib:paths",
        "@build_bazel_rules_swift//swift:providers",
        "@rules_cc//cc/common",
    ],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]) + [
        "//apple/internal/aspects:for_bazel_tests",
        "//apple/internal/partials:for_bazel_tests",
        "//apple/internal/providers:for_bazel_tests",
        "//apple/internal/resource_actions:for_bazel_tests",
        "//apple/internal/resource_rules:for_bazel_tests",
        "//apple/internal/templates:for_bazel_tests",
        "//apple/internal/testing:for_bazel_tests",
        "//apple/internal/toolchains:for_bazel_tests",
        "//apple/internal/utils:for_bazel_tests",
    ],
    visibility = [
        "//apple:__subpackages__",
    ],
)

environment_plist(
    name = "environment_plist_ios",
    platform_type = "ios",
    visibility = ["//apple:__subpackages__"],
)

environment_plist(
    name = "environment_plist_macos",
    platform_type = "macos",
    visibility = ["//apple:__subpackages__"],
)

environment_plist(
    name = "environment_plist_visionos",
    platform_type = "visionos",
    visibility = ["//apple:__subpackages__"],
)

environment_plist(
    name = "environment_plist_watchos",
    platform_type = "watchos",
    visibility = ["//apple:__subpackages__"],
)

environment_plist(
    name = "environment_plist_tvos",
    platform_type = "tvos",
    visibility = ["//apple:__subpackages__"],
)
