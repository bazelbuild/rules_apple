load(
    "//apple:apple.bzl",
    "apple_dynamic_framework_import",
    "apple_static_framework_import",
)
load(
    "//test/testdata/frameworks:generate_framework.bzl",
    "generate_import_framework",
)

# Public only because these are used by the integration tests from generated
# workspaces. Please no not depend on them as they can change at any time.
package(default_visibility = ["//visibility:public"])

licenses(["notice"])

apple_dynamic_framework_import(
    name = "iOSImportedDynamicFramework",
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
    ],
)

py_binary(
    name = "generate_framework",
    srcs = ["generate_framework.py"],
    srcs_version = "PY2AND3",
)

generate_import_framework(
    name = "iOSDynamicFramework",
    archs = ["x86_64"],
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
