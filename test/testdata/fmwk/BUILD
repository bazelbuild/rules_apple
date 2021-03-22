load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load(
    "//apple:apple.bzl",
    "apple_dynamic_framework_import",
    "apple_static_framework_import",
)
load(
    "//test/testdata/fmwk:generate_framework.bzl",
    "generate_import_framework",
)
load(
    "//test/testdata/fmwk:generate_framework_dsym.bzl",
    "generate_import_framework_dsym",
)

# Public only because these are used by the integration tests from generated
# workspaces. Please no not depend on them as they can change at any time.
package(default_visibility = ["//visibility:public"])

licenses(["notice"])

# Export the script in support of generate_import_framework.bzl.
exports_files(["generate_framework.py"])

apple_dynamic_framework_import(
    name = "iOSImportedDynamicFramework",
    framework_imports = [":iOSDynamicFramework"],
)

apple_dynamic_framework_import(
    name = "iOSImportedDynamicFrameworkWithBitcode",
    framework_imports = [":iOSDynamicFrameworkWithBitcode"],
)

apple_dynamic_framework_import(
    name = "iOSImportedDynamicFrameworkWithDebugInfo",
    framework_imports = [":iOSDynamicFrameworkWithDebugInfo"],
)

apple_dynamic_framework_import(
    name = "iOSImportedDynamicFrameworkWithDsym",
    dsym_imports = [":iOSDynamicFrameworkDsym"],
    framework_imports = [":iOSDynamicFramework"],
)

apple_static_framework_import(
    name = "iOSImportedStaticFramework",
    framework_imports = [":iOSStaticFramework"],
)

filegroup(
    name = "swift_source",
    srcs = [
        "SharedClass.swift",
    ],
)

filegroup(
    name = "objc_source",
    srcs = [
        "SharedClass.m",
    ],
)

filegroup(
    name = "objc_headers",
    srcs = [
        "SharedClass.h",
    ],
)

filegroup(
    name = "ios_framework_generators",
    srcs = [
        "BUILD",
        "generate_framework.bzl",
        "generate_framework.py",
        "generate_framework_dsym.bzl",
    ],
)

generate_import_framework(
    name = "iOSDynamicFramework",
    archs = ["x86_64"],
    libtype = "dynamic",
    minimum_os_version = "11.0",
    sdk = "iphonesimulator",
)

generate_import_framework(
    name = "iOSDynamicFrameworkWithDebugInfo",
    archs = ["x86_64"],
    embed_debug_info = True,
    libtype = "dynamic",
    minimum_os_version = "11.0",
    sdk = "iphonesimulator",
)

generate_import_framework_dsym(
    name = "iOSDynamicFrameworkDsym",
    framework_imports = [":iOSDynamicFramework"],
)

generate_import_framework(
    name = "iOSDynamicFrameworkWithBitcode",
    archs = ["x86_64"],
    embed_bitcode = True,
    libtype = "dynamic",
    minimum_os_version = "11.0",
    sdk = "iphonesimulator",
)

generate_import_framework(
    name = "iOSStaticFramework",
    archs = ["x86_64"],
    libtype = "static",
    minimum_os_version = "11.0",
    sdk = "iphonesimulator",
)

bzl_library(
    name = "generate_framework_bzl",
    srcs = ["generate_framework.bzl"],
    visibility = ["//visibility:private"],
    deps = [
        "@bazel_skylib//lib:dicts",
        "@bazel_skylib//lib:paths",
        "@build_bazel_apple_support//lib:apple_support",
    ],
)
