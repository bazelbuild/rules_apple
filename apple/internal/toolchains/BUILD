load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load(
    "//apple/build_settings:build_settings.bzl",
    "build_settings_labels",
)
load(
    "//apple/internal/toolchains:apple_toolchains.bzl",
    "apple_mac_tools_toolchain",
    "apple_xplat_tools_toolchain",
)

package(
    default_visibility = ["//apple/internal/toolchains:__subpackages__"],
)

licenses(["notice"])

toolchain_type(name = "mac_tools_toolchain_type")

toolchain(
    name = "mac_toolchain_declaration",
    toolchain = ":mac_tools_toolchain",
    toolchain_type = ":mac_tools_toolchain_type",
)

apple_mac_tools_toolchain(
    name = "mac_tools_toolchain",
    bundletool_experimental = "//tools/bundletool:bundletool_experimental",
    clangrttool = "//tools:prebuilt_clangrttool_osx",
    codesigningtool = "//tools:prebuilt_codesigntool_osx",
    dossier_codesigningtool = "//tools/dossier_codesigningtool",
    dsym_info_plist_template = "//apple/internal/templates:dsym_info_plist_template",
    environment_plist_tool = "//tools/environment_plist",
    imported_dynamic_framework_processor = "//tools:prebuilt_imported_framework_processor_osx",
    plisttool = "//tools/plisttool",
    process_and_sign_template = "//tools/bundletool:process_and_sign_template",
    provisioning_profile_tool = "//tools:prebuilt_provisioning_profile_tool_osx",
    signature_tool = "//tools:prebuilt_signature_tool_osx",
    swift_stdlib_tool = "//tools:prebuilt_swift_stdlib_tool_osx",
    xcframework_processor_tool = "//tools:prebuilt_xcframework_processor_tool_osx",
    xctoolrunner = "//tools/xctoolrunner",
)

toolchain_type(name = "apple_xplat_toolchain_type")

toolchain(
    name = "apple_xplat_toolchain",
    toolchain = ":xplat_tools_toolchain",
    toolchain_type = ":apple_xplat_toolchain_type",
)

apple_xplat_tools_toolchain(
    name = "xplat_tools_toolchain",
    build_settings = build_settings_labels.all_labels,
    bundletool = "//tools/bundletool",
    versiontool = "//tools/versiontool",
)

bzl_library(
    name = "apple_toolchains",
    srcs = ["apple_toolchains.bzl"],
    visibility = [
        "//apple:__subpackages__",
    ],
    deps = [
        "//apple/internal/providers:apple_feature_allowlist_info",
        "@bazel_skylib//rules:common_settings",
    ],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = glob(["**"]),
    visibility = [
        "//apple:__subpackages__",
    ],
)
