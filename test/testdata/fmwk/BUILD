load(
    "//test/testdata/fmwk:generate_framework.bzl",
    "generate_import_framework",
)
load(
    "//test/testdata/fmwk:generate_framework_dsym.bzl",
    "generate_import_framework_dsym",
)
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

# Public only because these are used by the integration tests from generated
# workspaces. Please no not depend on them as they can change at any time.
package(default_visibility = ["//visibility:public"])

licenses(["notice"])

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
        "generate_framework_dsym.bzl",
        "generation_support.bzl",
    ],
)

# ------------------------------- iOS Framework ------------------------------------------

generate_import_framework(
    name = "iOSDynamicFramework",
    archs = ["x86_64"],
    include_resource_bundle = True,
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
    include_resource_bundle = True,
    libtype = "static",
    minimum_os_version = "11.0",
    sdk = "iphonesimulator",
)

swift_library(
    name = "swift_framework_lib",
    srcs = ["SharedClass.swift"],
    generates_header = True,
    module_name = "iOSSwiftStaticFramework",
)

generate_import_framework(
    name = "iOSSwiftStaticFramework",
    archs = ["x86_64"],
    libtype = "static",
    minimum_os_version = "11.0",
    sdk = "iphonesimulator",
    swift_library = ":swift_framework_lib",
)

generate_import_framework(
    name = "iOSSwiftStaticFrameworkWithoutModuleInterfaces",
    archs = ["x86_64"],
    include_module_interface_files = False,
    libtype = "static",
    minimum_os_version = "11.0",
    sdk = "iphonesimulator",
    swift_library = ":swift_framework_lib",
)

# ------------------------------- macOS Framework ------------------------------------------

generate_import_framework(
    name = "macOSDynamicFramework",
    archs = ["x86_64"],
    include_resource_bundle = True,
    libtype = "dynamic",
    minimum_os_version = "11.11",
    sdk = "macosx",
)

generate_import_framework(
    name = "macOSDynamicFrameworkWithDebugInfo",
    archs = ["x86_64"],
    embed_debug_info = True,
    libtype = "dynamic",
    minimum_os_version = "11.11",
    sdk = "macosx",
)

generate_import_framework_dsym(
    name = "macOSDynamicFrameworkDsym",
    framework_imports = [":macOSDynamicFramework"],
)

generate_import_framework(
    name = "macOSDynamicFrameworkWithBitcode",
    src = "SharedClass.m",
    archs = ["x86_64"],
    embed_bitcode = True,
    libtype = "dynamic",
    minimum_os_version = "11.11",
    sdk = "macosx",
)

generate_import_framework(
    name = "macOSStaticFramework",
    src = "SharedClass.m",
    archs = ["x86_64"],
    include_resource_bundle = True,
    libtype = "static",
    minimum_os_version = "11.11",
    sdk = "macosx",
)

generate_import_framework(
    name = "macOSSwiftStaticFramework",
    archs = ["x86_64"],
    libtype = "static",
    minimum_os_version = "11.11",
    sdk = "macosx",
    swift_library = ":swift_framework_lib",
)

generate_import_framework(
    name = "macOSSwiftStaticFrameworkWithoutModuleInterfaces",
    archs = ["x86_64"],
    include_module_interface_files = False,
    libtype = "static",
    minimum_os_version = "11.11",
    sdk = "macosx",
    swift_library = ":swift_framework_lib",
)

bzl_library(
    name = "generate_framework_bzl",
    srcs = ["generate_framework.bzl"],
    visibility = ["//visibility:private"],
    deps = [
        ":generation_support",
        "@bazel_skylib//lib:dicts",
        "@bazel_skylib//lib:paths",
        "@build_bazel_apple_support//lib:apple_support",
        "@build_bazel_rules_swift//swift",
    ],
)

bzl_library(
    name = "generation_support",
    srcs = ["generation_support.bzl"],
    visibility = ["//test:__subpackages__"],
    deps = [
        "@bazel_skylib//lib:paths",
        "@build_bazel_apple_support//lib:apple_support",
    ],
)
