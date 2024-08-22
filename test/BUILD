load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load(
    "//test:configurations.bzl",
    "IOS_CONFIGURATIONS",
    "MACOS_CONFIGURATIONS",
    "TVOS_CONFIGURATIONS",
    "WATCHOS_CONFIGURATIONS",
)
load(
    "//test:test_rules.bzl",
    "apple_multi_shell_test",
    "apple_shell_test",
)

licenses(["notice"])

bzl_library(
    name = "configurations",
    srcs = ["configurations.bzl"],
)

bzl_library(
    name = "test_rules",
    srcs = ["test_rules.bzl"],
)

# Export shell test utilities so can can be pulled in as data to the tests.
exports_files(["apple_shell_testutils.sh"])

# List of dependencies to be used in Starlark verifier tests.
filegroup(
    name = "apple_verification_test_deps",
    testonly = 1,
    srcs = [
        "apple_shell_testutils.sh",
        "unittest.bash",
    ],
    visibility = [
        "//test/starlark_tests:__subpackages__",
    ],
)

# ----------------------------------------------------------------------------

# Tests that end up needing things like ibtool or actool run under the hood
# are better off as a dedicated *_resources_test.sh that can then be marked
# with `flaky = 1`. When building for some Apple platforms, the tools can end
# up talking to other services running on the machine (CoreSimulator) during
# the build and flake/fail. So by grouping them and marking them as flaky, it
# allows bazel to auto retry them and help minimize the unreliability in those
# tools.

apple_shell_test(
    name = "apple_bundle_version_test",
    size = "medium",
    src = "apple_bundle_version_test.sh",
)

apple_multi_shell_test(
    name = "ios_application_test",
    size = "large",
    src = "ios_application_test.sh",
    configurations = IOS_CONFIGURATIONS,
)

apple_multi_shell_test(
    name = "ios_application_resources_test",
    size = "large",
    src = "ios_application_resources_test.sh",
    configurations = IOS_CONFIGURATIONS,
    data = [
        "//test/testdata/resources:resource_data_deps_ios",
        "//test/testdata/resources:resource_data_deps_platform_independent",
        "//test/testdata/resources:texture_atlas_data_deps",
    ],
    flaky = 1,
)

apple_multi_shell_test(
    name = "ios_extension_test",
    size = "medium",
    src = "ios_extension_test.sh",
    configurations = IOS_CONFIGURATIONS,
)

apple_multi_shell_test(
    name = "macos_application_test",
    size = "medium",
    src = "macos_application_test.sh",
    configurations = MACOS_CONFIGURATIONS,
    data = [
    ],
)

apple_multi_shell_test(
    name = "macos_application_resources_test",
    size = "medium",
    src = "macos_application_resources_test.sh",
    configurations = MACOS_CONFIGURATIONS,
    data = [
        "//test/testdata/resources:resource_data_deps_platform_independent",
    ],
)

apple_multi_shell_test(
    name = "macos_bundle_test",
    size = "medium",
    src = "macos_bundle_test.sh",
    configurations = MACOS_CONFIGURATIONS,
)

apple_multi_shell_test(
    name = "macos_quick_look_plugin_test",
    size = "medium",
    src = "macos_quick_look_plugin_test.sh",
    configurations = MACOS_CONFIGURATIONS,
)

apple_multi_shell_test(
    name = "tvos_application_test",
    size = "medium",
    src = "tvos_application_test.sh",
    configurations = TVOS_CONFIGURATIONS,
)

apple_multi_shell_test(
    name = "tvos_extension_test",
    size = "medium",
    src = "tvos_extension_test.sh",
    configurations = TVOS_CONFIGURATIONS,
)

apple_multi_shell_test(
    name = "watchos_application_test",
    size = "medium",
    timeout = "long",
    src = "watchos_application_test.sh",
    configurations = WATCHOS_CONFIGURATIONS,
)

apple_shell_test(
    name = "smart_resource_deduplication_test",
    size = "large",
    src = "smart_resource_deduplication_test.sh",
    data = [
        "//test/testdata/resources:resource_data_deps_ios",
        "//test/testdata/resources:resource_data_deps_platform_independent",
    ],
)
