load("@build_bazel_rules_swift//swift:swift_binary.bzl", "swift_binary")
load("@build_bazel_rules_swift//swift:swift_library.bzl", "swift_library")
load("//apple:apple.bzl", "apple_universal_binary")

licenses(["notice"])

apple_universal_binary(
    name = "imported_framework_processor_osx",
    binary = ":imported_framework_processor_swift",
    forced_cpus = [
        "x86_64",
        "arm64",
    ],
    minimum_os_version = "13.0",
    platform_type = "macos",
)

swift_binary(
    name = "imported_framework_processor_swift",
    srcs = [
        "ImportedFrameworkProcessor.swift",
        "ProcessDynamicFramework.swift",
    ],
    tags = [
        "manual",
        "notap",
    ],
    target_compatible_with = ["@platforms//os:macos"],
    deps = [
        ":process_dynamic_framework_options",
        "//tools/codesigningtool:code_sign_process_options",
    ],
)

swift_library(
    name = "process_dynamic_framework_options",
    srcs = [
        "ProcessDynamicFrameworkOptions.swift",
    ],
)

py_binary(
    name = "imported_dynamic_framework_processor",
    srcs = ["imported_dynamic_framework_processor.py"],
    python_version = "PY3",
    srcs_version = "PY3",
    visibility = [
        "//apple/internal/toolchains:__pkg__",
    ],
    deps = [
        "//tools/imported_dynamic_framework_processor:imported_dynamic_framework_processor_lib",
    ],
)

py_library(
    name = "imported_dynamic_framework_processor_lib",
    srcs = ["imported_dynamic_framework_processor.py"],
    srcs_version = "PY3",
    visibility = ["//visibility:private"],
    deps = [
        "//tools/codesigningtool:codesigningtool_lib",
        "//tools/wrapper_common:execute",
        "//tools/wrapper_common:lipo",
    ],
)

py_test(
    name = "imported_dynamic_framework_processor_test",
    srcs = ["imported_dynamic_framework_processor_test.py"],
    python_version = "PY3",
    tags = ["requires-darwin"],
    deps = [":imported_dynamic_framework_processor_lib"],
)
