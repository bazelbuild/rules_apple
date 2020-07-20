# Internal implementation details of the Apple rules.

load(
    ":environment_plist.bzl",
    "environment_plist",
)
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

licenses(["notice"])

bzl_library(
    name = "apple_framework_import",
    srcs = ["apple_framework_import.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":resources",
        "//apple:utils",
        "@bazel_skylib//lib:dicts",
        "@bazel_skylib//lib:partial",
        "@bazel_skylib//lib:paths",
        "@bazel_skylib//lib:sets",
        "@build_bazel_rules_swift//swift",
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
    name = "binary_support",
    srcs = ["binary_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":apple_product_type",
        ":entitlement_rules",
        ":exported_symbols_lists_rules",
        ":rule_support",
        ":swift_support",
        "@bazel_skylib//lib:collections",
    ],
)

bzl_library(
    name = "bundling_support",
    srcs = ["bundling_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":rule_support",
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
        ":platform_support",
        ":rule_support",
        "//apple/internal/utils:defines",
        "//apple/internal/utils:legacy_actions",
        "@bazel_skylib//lib:paths",
        "@bazel_skylib//lib:shell",
    ],
)

bzl_library(
    name = "entitlement_rules",
    srcs = ["entitlement_rules.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":bundling_support",
        ":linking_support",
        ":platform_support",
        ":resource_actions",
        "//apple:common",
        "//apple/internal/utils:defines",
        "@build_bazel_apple_support//lib:apple_support",
    ],
)

bzl_library(
    name = "entitlements_support",
    srcs = ["entitlements_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":entitlement_rules",
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
        ":rule_factory",
        "//apple/internal/utils:legacy_actions",
        "@bazel_skylib//lib:dicts",
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
    name = "exported_symbols_lists_rules",
    srcs = ["exported_symbols_lists_rules.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":linking_support",
    ],
)

bzl_library(
    name = "intermediates",
    srcs = ["intermediates.bzl"],
    visibility = [
        "//apple:__subpackages__",
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
        ":linking_support",
        ":outputs",
        ":partials",
        ":platform_support",
        ":processor",
        ":rule_factory",
        ":rule_support",
        ":run_support",
        ":stub_support",
        "//apple:providers",
        "//apple/internal/aspects:swift_static_framework_aspect",
    ],
)

bzl_library(
    name = "linking_support",
    srcs = ["linking_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":rule_support",
        "@bazel_skylib//lib:collections",
    ],
)

bzl_library(
    name = "macos_binary_support",
    srcs = ["macos_binary_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":apple_product_type",
        ":intermediates",
        ":linking_support",
        ":resource_actions",
        ":rule_factory",
        "//apple:providers",
        "@bazel_skylib//lib:dicts",
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
        ":codesigning_support",
        ":linking_support",
        ":outputs",
        ":partials",
        ":processor",
        ":rule_factory",
        ":run_support",
        "//apple:providers",
    ],
)

bzl_library(
    name = "outputs",
    srcs = ["outputs.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":bundling_support",
        ":experimental",
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
        "//apple/internal/partials:apple_bundle_info",
        "//apple/internal/partials:binary",
        "//apple/internal/partials:bitcode_symbols",
        "//apple/internal/partials:clang_rt_dylibs",
        "//apple/internal/partials:debug_symbols",
        "//apple/internal/partials:embedded_bundles",
        "//apple/internal/partials:extension_safe_validation",
        "//apple/internal/partials:framework_headers",
        "//apple/internal/partials:framework_import",
        "//apple/internal/partials:framework_provider",
        "//apple/internal/partials:macos_additional_contents",
        "//apple/internal/partials:messages_stub",
        "//apple/internal/partials:provisioning_profile",
        "//apple/internal/partials:resources",
        "//apple/internal/partials:settings_bundle",
        "//apple/internal/partials:static_framework_header_modulemap",
        "//apple/internal/partials:swift_dylibs",
        "//apple/internal/partials:swift_static_framework",
        "//apple/internal/partials:watchos_stub",
    ],
)

bzl_library(
    name = "platform_support",
    srcs = ["platform_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":rule_support",
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
        ":entitlements_support",
        ":experimental",
        ":intermediates",
        ":outputs",
        ":platform_support",
        ":rule_support",
        "//apple/internal/utils:bundle_paths",
        "//apple/internal/utils:defines",
        "@bazel_skylib//lib:dicts",
        "@bazel_skylib//lib:partial",
        "@bazel_skylib//lib:paths",
        "@build_bazel_apple_support//lib:apple_support",
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
        "//apple/internal/resource_actions:texture_atlas",
        "//apple/internal/resource_actions:zip",
    ],
)

bzl_library(
    name = "resources",
    srcs = ["resources.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        "//apple:providers",
        "//apple/internal/partials/support:resources_support",
        "//apple/internal/utils:bundle_paths",
        "@bazel_skylib//lib:partial",
        "@bazel_skylib//lib:paths",
        "@bazel_skylib//lib:types",
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
        ":entitlement_rules",
        ":rule_support",
        "//apple:common",
        "//apple:providers",
        "//apple/internal/aspects:framework_import_aspect",
        "//apple/internal/aspects:resource_aspect",
        "//apple/internal/aspects:swift_static_framework_aspect",
        "//apple/internal/testing:apple_test_bundle_support",
        "//apple/internal/testing:apple_test_rule_support",
        "@bazel_skylib//lib:dicts",
        "@build_bazel_apple_support//lib:apple_support",
        "@build_bazel_rules_swift//swift",
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
        ":transition_support",
    ],
)

bzl_library(
    name = "run_support",
    srcs = ["run_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        ":bundling_support",
        ":outputs",
        ":platform_support",
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
        "//apple/internal/utils:legacy_actions",
    ],
)

bzl_library(
    name = "swift_support",
    srcs = ["swift_support.bzl"],
    visibility = ["//apple:__subpackages__"],
    deps = [
        "@build_bazel_rules_swift//swift",
    ],
)

bzl_library(
    name = "transition_support",
    srcs = ["transition_support.bzl"],
    visibility = [
        "//apple:__subpackages__",
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
        ":linking_support",
        ":outputs",
        ":partials",
        ":platform_support",
        ":processor",
        ":rule_factory",
        ":rule_support",
        ":run_support",
        "//apple:providers",
        "//apple/internal/aspects:swift_static_framework_aspect",
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
        ":linking_support",
        ":outputs",
        ":partials",
        ":platform_support",
        ":processor",
        ":rule_factory",
        ":rule_support",
        ":stub_support",
        "//apple:providers",
        "@build_bazel_apple_support//lib:xcode_support",
    ],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]) + [
        "//apple/internal/aspects:for_bazel_tests",
        "//apple/internal/partials:for_bazel_tests",
        "//apple/internal/resource_actions:for_bazel_tests",
        "//apple/internal/resource_rules:for_bazel_tests",
        "//apple/internal/templates:for_bazel_tests",
        "//apple/internal/testing:for_bazel_tests",
        "//apple/internal/utils:for_bazel_tests",
    ],
    visibility = [
        "//apple:__subpackages__",
    ],
)

environment_plist(
    name = "environment_plist_ios",
    platform_type = "ios",
    # Used by the rule implementations, so it needs to be public; but
    # should be considered an implementation detail of the rules and
    # not used by other things.
    visibility = ["//visibility:public"],
)

environment_plist(
    name = "environment_plist_macos",
    platform_type = "macos",
    # Used by the rule implementations, so it needs to be public; but
    # should be considered an implementation detail of the rules and
    # not used by other things.
    visibility = ["//visibility:public"],
)

environment_plist(
    name = "environment_plist_watchos",
    platform_type = "watchos",
    # Used by the rule implementations, so it needs to be public; but
    # should be considered an implementation detail of the rules and
    # not used by other things.
    visibility = ["//visibility:public"],
)

environment_plist(
    name = "environment_plist_tvos",
    platform_type = "tvos",
    # Used by the rule implementations, so it needs to be public; but
    # should be considered an implementation detail of the rules and
    # not used by other things.
    visibility = ["//visibility:public"],
)
