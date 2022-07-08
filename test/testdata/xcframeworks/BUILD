load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load(
    "//test/testdata/xcframeworks:generate_xcframework.bzl",
    "generate_dynamic_xcframework",
    "generate_static_xcframework",
)

licenses(["notice"])

generate_dynamic_xcframework(
    name = "generated_dynamic_xcframework",
    srcs = ["@bazel_tools//tools/objc:objc_dummy.mm"],
    minimum_os_versions = {
        "ios_simulator": "11.0",
        "ios": "11.0",
    },
    platforms = {
        "ios_simulator": [
            "x86_64",
            "arm64",
        ],
        "ios": ["arm64"],
    },
)

generate_dynamic_xcframework(
    name = "generated_dynamic_xcframework_with_headers",
    srcs = ["//test/testdata/fmwk:objc_source"],
    hdrs = ["//test/testdata/fmwk:objc_headers"],
    minimum_os_versions = {
        "ios_simulator": "11.0",
        "ios": "11.0",
    },
    platforms = {
        "ios_simulator": [
            "x86_64",
            "arm64",
        ],
        "ios": ["arm64"],
    },
)

generate_static_xcframework(
    name = "generated_static_xcframework",
    srcs = ["@bazel_tools//tools/objc:objc_dummy.mm"],
    minimum_os_versions = {
        "ios_simulator": "11.0",
        "ios": "11.0",
    },
    platforms = {
        "ios_simulator": [
            "x86_64",
            "arm64",
        ],
        "ios": ["arm64"],
    },
)

generate_static_xcframework(
    name = "generated_static_xcframework_with_headers",
    srcs = ["//test/testdata/fmwk:objc_source"],
    hdrs = ["//test/testdata/fmwk:objc_headers"],
    minimum_os_versions = {
        "ios_simulator": "11.0",
        "ios": "11.0",
    },
    platforms = {
        "ios_simulator": [
            "x86_64",
            "arm64",
        ],
        "ios": ["arm64"],
    },
)

generate_static_xcframework(
    name = "generated_static_xcframework_with_headers_and_no_modulemap",
    srcs = ["//test/testdata/fmwk:objc_source"],
    hdrs = ["//test/testdata/fmwk:objc_headers"],
    generate_modulemap = False,
    minimum_os_versions = {
        "ios_simulator": "11.0",
        "ios": "11.0",
    },
    platforms = {
        "ios_simulator": [
            "x86_64",
            "arm64",
        ],
        "ios": ["arm64"],
    },
)

bzl_library(
    name = "generate_xcframework_bzl",
    srcs = ["generate_xcframework.bzl"],
    visibility = ["//visibility:private"],
    deps = [
        "//test/testdata/fmwk:generation_support",
        "@bazel_skylib//lib:dicts",
        "@bazel_skylib//lib:paths",
        "@build_bazel_apple_support//lib:apple_support",
    ],
)
