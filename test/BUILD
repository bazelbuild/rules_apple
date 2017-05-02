package(default_visibility = ["//visibility:public"])

licenses(["notice"])

load(
    "//test:configurations.bzl",
    "IOS_CONFIGURATIONS",
    "TVOS_CONFIGURATIONS",
    "WATCHOS_CONFIGURATIONS",
)
load("//test:test_rules.bzl", "apple_shell_test")

config_setting(
    name = "darwin",
    values = {"host_cpu": "darwin_x86_64"},
)

apple_shell_test(
    name = "ios_application_test",
    size = "medium",
    src = "ios_application_test.sh",
    configurations = IOS_CONFIGURATIONS,
    data = [
        "//test/testdata/binaries:empty_dylib",
        "//test/testdata/binaries:empty_staticlib",
    ],
)

apple_shell_test(
    name = "ios_application_resources_test",
    size = "medium",
    src = "ios_application_resources_test.sh",
    configurations = IOS_CONFIGURATIONS,
    data = [
        "//test/testdata/resources:resource_data_deps_ios",
        "//test/testdata/resources:resource_data_deps_platform_independent",
    ],
)

apple_shell_test(
    name = "ios_application_swift_test",
    size = "medium",
    src = "ios_application_swift_test.sh",
    configurations = IOS_CONFIGURATIONS,
    data = [
        "//test/testdata/resources:resource_data_deps_ios",
        "//test/testdata/resources:resource_data_deps_platform_independent",
    ],
)

apple_shell_test(
    name = "ios_extension_test",
    size = "medium",
    src = "ios_extension_test.sh",
    configurations = IOS_CONFIGURATIONS,
    data = [
        "//test/testdata/binaries:empty_dylib",
        "//test/testdata/binaries:empty_staticlib",
        "//test/testdata/resources:resource_data_deps_ios",
    ],
)

apple_shell_test(
    name = "ios_extension_swift_test",
    size = "medium",
    src = "ios_extension_swift_test.sh",
    configurations = IOS_CONFIGURATIONS,
)

# The swift_library test does not use any canned configurations; it controls
# options manually for various tests.
apple_shell_test(
    name = "swift_library_test",
    size = "medium",
    src = "swift_library_test.sh",
    configurations = {"default": []},
)

apple_shell_test(
    name = "tvos_application_test",
    size = "medium",
    src = "tvos_application_test.sh",
    configurations = TVOS_CONFIGURATIONS,
)

apple_shell_test(
    name = "tvos_application_swift_test",
    size = "medium",
    src = "tvos_application_swift_test.sh",
    configurations = TVOS_CONFIGURATIONS,
)

apple_shell_test(
    name = "tvos_extension_test",
    size = "medium",
    src = "tvos_extension_test.sh",
    configurations = TVOS_CONFIGURATIONS,
)

apple_shell_test(
    name = "tvos_extension_swift_test",
    size = "medium",
    src = "tvos_extension_swift_test.sh",
    configurations = TVOS_CONFIGURATIONS,
)

apple_shell_test(
    name = "watchos_application_test",
    size = "medium",
    src = "watchos_application_test.sh",
    configurations = WATCHOS_CONFIGURATIONS,
)

apple_shell_test(
    name = "watchos_application_swift_test",
    size = "medium",
    src = "watchos_application_swift_test.sh",
    configurations = WATCHOS_CONFIGURATIONS,
)
