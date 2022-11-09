# Build settings used throughout rules_apple build rules.

load("@bazel_skylib//rules:common_settings.bzl", "bool_flag", "string_flag")
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(default_visibility = ["//visibility:public"])

licenses(["notice"])

# Configuration for enabling XCFramework import rules use the xcframework_processor_tool to
# parse the XCFramework bundle Info.plist file. See apple/internal/apple_xcframework_import.bzl
bool_flag(
    name = "parse_xcframework_info_plist",
    build_setting_default = False,
)

# Declare a code signing identity, to be used in all code signing flows related to the rules.
# TODO(b/252873771): Clean up all usages of --ios_signing_cert_name and replace them with this new
# custom build setting.
string_flag(
    name = "signing_certificate_name",
    build_setting_default = "",
)

bzl_library(
    name = "attrs",
    srcs = ["attrs.bzl"],
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
