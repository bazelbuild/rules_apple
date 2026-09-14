load("@rules_cc//cc:objc_library.bzl", "objc_library")
load("@rules_cc//cc/toolchains:cc_toolchain.bzl", "cc_toolchain")
load("//apple:ios.bzl", "ios_unit_test")
load(":execution_platform_test_toolchains.bzl", "local_xplat_toolchain", "unused_linux_cc_config")

local_xplat_toolchain(name = "local_xplat_tools")

# Python rules analyze Windows launcher and ZIP tools even on macOS. Their
# Linux-configured C++ dependencies must resolve, but must never execute here.
unused_linux_cc_config(name = "unused_linux_cc_config")

filegroup(name = "empty")

cc_toolchain(
    name = "unused_linux_cc",
    all_files = ":empty",
    compiler_files = ":empty",
    dwp_files = ":empty",
    linker_files = ":empty",
    objcopy_files = ":empty",
    strip_files = ":empty",
    toolchain_config = ":unused_linux_cc_config",
    toolchain_identifier = "unused_linux",
)

toolchain(
    name = "unused_linux_cc_toolchain",
    exec_compatible_with = ["@platforms//os:linux"],
    target_compatible_with = ["@platforms//os:linux"],
    toolchain = ":unused_linux_cc",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

toolchain(
    name = "local_xplat_toolchain",
    toolchain = ":local_xplat_tools",
    toolchain_type = "//apple/internal:apple_xplat_toolchain_type",
)

platform(
    name = "linux",
    constraint_values = [
        "@platforms//cpu:x86_64",
        "@platforms//os:linux",
    ],
)

platform(
    name = "macos",
    constraint_values = [
        "@platforms//cpu:aarch64",
        "@platforms//os:macos",
    ],
)

objc_library(
    name = "test_lib",
    testonly = True,
    srcs = ["test.m"],
    sdk_frameworks = ["XCTest"],
    tags = ["manual"],
)

ios_unit_test(
    name = "unit_test",
    families = ["iphone"],
    minimum_os_version = "15.5",
    tags = ["manual"],
    deps = [":test_lib"],
)
