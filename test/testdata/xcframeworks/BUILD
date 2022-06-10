load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("//test/starlark_tests:common.bzl", "FIXTURE_TAGS")
load(
    "//test/testdata/xcframeworks:generate_xcframework.bzl",
    "generate_dynamic_xcframework",
    "generate_static_xcframework",
)
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

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

swift_library(
    name = "swift_lib_for_static_xcframework",
    srcs = ["//test/testdata/fmwk:swift_source"],
    features = [
        "swift.emit_swiftinterface",
        "swift.enable_library_evolution",
    ],
    generates_header = True,
    module_name = "swift_lib_for_static_xcframework",
    tags = FIXTURE_TAGS,
)

generate_static_xcframework(
    name = "generated_swift_static_xcframework",
    platforms = {"ios_simulator": ["x86_64"]},
    swift_library = ":swift_lib_for_static_xcframework",
    tags = FIXTURE_TAGS,
)

generate_static_xcframework(
    name = "generated_swift_static_xcframework_without_swiftmodule",
    include_module_interface_files = False,
    platforms = {"ios_simulator": ["x86_64"]},
    swift_library = ":swift_lib_for_static_xcframework",
    tags = FIXTURE_TAGS,
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
        "@build_bazel_rules_swift//swift",
    ],
)
