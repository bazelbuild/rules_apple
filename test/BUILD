load(
    "//test:configurations.bzl",
    "IOS_64BIT_SIMULATOR_FAT_DEVICE_CONFIGURATIONS",
    "IOS_CONFIGURATIONS",
    "MACOS_CONFIGURATIONS",
    "TVOS_CONFIGURATIONS",
    "WATCHOS_CONFIGURATIONS",
)
load(
    "//test/starlark_tests:common.bzl",
    "common",
)
load(
    "//test:test_rules.bzl",
    "apple_multi_shell_test",
    "apple_shell_test",
)
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

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
    # This is required as a default attribute of apple_verification_test but
    # should be considered private for other uses
    visibility = ["//visibility:public"],
)

# Gather external dependencies into a target that can be injected into the
# integration tests. The test script will then mock out the files required
# to make these proper WORKSPACES that can be used in tests.
# This enables us to:
#   1. Reuse the download of the external dependencies across all tests.
#   2. Remove the need to update dependency versions in the repo's
#      WORKSPACE and the test WORKSPACE.
filegroup(
    name = "external_deps",
    testonly = 1,
    srcs = [
        "@bazel_skylib//:test_deps",
        "@xctestrunner//:ios_test_runner",
    ],
)

# ----------------------------------------------------------------------------

# Ballpark number for shared_count:
#  grep -c function\ test test/*_test.sh

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

apple_shell_test(
    name = "apple_core_ml_library_package_test",
    size = "medium",
    src = "apple_core_ml_library_package_test.sh",
    data = [
        "//test/testdata/resources:mlmodel_srcs",
    ],
)

apple_shell_test(
    name = "apple_intent_library_test",
    size = "medium",
    src = "apple_intent_library_test.sh",
    data = [
        "//test/testdata/resources:intent_srcs",
    ],
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
    name = "ios_application_swift_test",
    size = "medium",
    src = "ios_application_swift_test.sh",
    configurations = IOS_64BIT_SIMULATOR_FAT_DEVICE_CONFIGURATIONS,
)

apple_multi_shell_test(
    name = "ios_extension_test",
    size = "medium",
    src = "ios_extension_test.sh",
    configurations = IOS_CONFIGURATIONS,
)

apple_multi_shell_test(
    name = "ios_imessage_test",
    size = "medium",
    src = "ios_imessage_test.sh",
    configurations = IOS_CONFIGURATIONS,
    data = [
        "//test/testdata/resources:resource_data_deps_ios",
    ],
)

apple_multi_shell_test(
    name = "macos_application_test",
    size = "medium",
    src = "macos_application_test.sh",
    configurations = MACOS_CONFIGURATIONS,
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
    name = "tvos_application_swift_test",
    size = "medium",
    src = "tvos_application_swift_test.sh",
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
    src = "watchos_application_test.sh",
    configurations = WATCHOS_CONFIGURATIONS,
)

apple_shell_test(
    name = "ios_coverage_test",
    size = "medium",
    src = "ios_coverage_test.sh",
)

apple_shell_test(
    name = "ios_xctestrun_runner_unit_test",
    size = "large",
    src = "ios_xctestrun_runner_unit_test.sh",
    args = [
        "--ios_multi_cpus=sim_arm64,x86_64",
    ],
    tags = common.skip_ci_tags,
)

apple_shell_test(
    name = "ios_xctestrun_runner_ui_test",
    size = "large",
    src = "ios_xctestrun_runner_ui_test.sh",
    args = [
        "--ios_multi_cpus=sim_arm64,x86_64",
    ],
    tags = common.skip_ci_tags,
)

apple_shell_test(
    name = "ios_test_runner_unit_test",
    size = "large",
    src = "ios_test_runner_unit_test.sh",
    args = [
        "--ios_multi_cpus=sim_arm64,x86_64",
    ],
    flaky = 1,
    tags = common.skip_ci_tags,
)

apple_shell_test(
    name = "ios_test_runner_unit_test_14.x",
    size = "large",
    src = "ios_test_runner_unit_test_14.x.sh",
    args = [
        "--ios_multi_cpus=sim_arm64,x86_64",
    ],
    tags = common.skip_ci_tags,
)

apple_shell_test(
    name = "ios_test_runner_ui_test",
    size = "large",
    src = "ios_test_runner_ui_test.sh",
    args = [
        "--ios_multi_cpus=sim_arm64,x86_64",
    ],
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
