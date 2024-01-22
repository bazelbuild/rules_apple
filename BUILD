load("@bazel_skylib//rules:common_settings.bzl", "bool_flag")

licenses(["notice"])

exports_files(["LICENSE"])

# See the note in __init__.py for why this is needed.
py_library(
    name = "py_init_shim",
    testonly = 1,
    srcs = ["__init__.py"],
    visibility = ["//:__subpackages__"],
)

# Consumed by bazel tests.
filegroup(
    name = "for_bazel_tests",
    testonly = 1,
    srcs = [
        "WORKSPACE",
        "//apple:for_bazel_tests",
        "//tools:for_bazel_tests",
    ],
    visibility = [
        "//test:__subpackages__",
    ],
)

config_setting(
    name = "supports_visionos_setting",
    flag_values = {
        ":supports_visionos": "True",
    },
    visibility = [
        "//examples:__subpackages__",
        "//test:__subpackages__",
    ],
)

bool_flag(
    name = "supports_visionos",
    build_setting_default = False,
    visibility = ["//visibility:private"],
)
