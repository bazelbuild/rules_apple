load("//apple:apple.bzl", "apple_universal_binary")

licenses(["notice"])

# Force an Apple transition on "exec" config, but keep it single arch to avoid invoking lipo on a
# script that's architecture independent. py_binary doesn't support Apple Silicon natively, so this
# is the best we can do right now.
apple_universal_binary(
    name = "codesigningtool",
    binary = ":codesigningtool_binary",
    forced_cpus = [
        "x86_64",
    ],
    minimum_os_version = "13.0",
    platform_type = "macos",
    visibility = [
        "//apple/internal/toolchains:__subpackages__",
    ],
)

py_binary(
    name = "codesigningtool_binary",
    srcs = ["codesigningtool.py"],
    deps = [":codesigningtool_lib"],
)

py_library(
    name = "codesigningtool_lib",
    srcs = ["codesigningtool.py"],
    visibility = [
        "//tools:__subpackages__",
    ],
    deps = ["//tools/wrapper_common:execute"],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = [
        "BUILD",
        "codesigningtool.py",
    ],
    visibility = [
        "//tools:__pkg__",
    ],
)
