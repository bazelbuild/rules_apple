load(
    "//test:configurations.bzl",
    "IOS_CONFIGURATIONS",
    "IOS_TEST_CONFIGURATIONS",
    "MACOS_CONFIGURATIONS",
    "TVOS_CONFIGURATIONS",
    "WATCHOS_CONFIGURATIONS",
)
load(
    "//test:test_rules.bzl",
    "apple_multi_shell_test",
    "apple_shell_test",
)

package(default_visibility = ["//visibility:public"])

licenses(["notice"])

# To enable sharding of the apple_shell_test rules, invoke bazel with
#   '--define bazel_rules_apple.shell_test_sharding=1'
config_setting(
    name = "apple_shell_test_enable_sharding",
    values = {
        "define": "bazel_rules_apple.shell_test_sharding=1",
    },
)

# To disable sharding of the apple_shell_test rules, invoke bazel with
#   '--define bazel_rules_apple.shell_test_sharding=0'
# Note: '--test_sharding_strategy=disabled' also works, but is global,
# the define allows one to disable the sharding on just these tests
# while allowing others to still be sharded.
config_setting(
    name = "apple_shell_test_disable_sharding",
    values = {
        "define": "bazel_rules_apple.shell_test_sharding=0",
    },
)

# Export shell test utilities so that they can be referenced from
# other packages.
filegroup(
    name = "test_utils",
    srcs = ["apple_shell_testutils.sh"],
)

# Gather external dependencies into a target that can be injected
# into the tests. The test runner will then mock out the BUILD files
# required to make these proper WORKSPACES that can be used in tests.
# This enables us to:
#   1. Reuse the download of the external dependencies across all tests.
#   2. Remove the need to update dependency versions in the repo's
#      WORKSPACE and the test WORKSPACE.
filegroup(
    name = "external_deps",
    testonly = 1,
    srcs = [
        "@bazel_skylib//:test_deps",
        "@xctestrunner//file",
    ],
    visibility = ["//visibility:private"],
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
    shard_count = 8,
)

apple_multi_shell_test(
    name = "ios_application_test",
    size = "large",
    src = "ios_application_test.sh",
    configurations = IOS_CONFIGURATIONS,
    data = [
        "//test/testdata/binaries:empty_dylib",
        "//test/testdata/binaries:empty_staticlib",
    ],
    shard_count = 16,
)

apple_multi_shell_test(
    name = "ios_application_resources_test",
    size = "large",
    src = "ios_application_resources_test.sh",
    configurations = IOS_CONFIGURATIONS,
    data = [
        "//test/testdata/resources:resource_data_deps_ios",
        "//test/testdata/resources:resource_data_deps_platform_independent",
    ],
    flaky = 1,
    shard_count = 8,
)

apple_multi_shell_test(
    name = "ios_application_swift_test",
    size = "medium",
    src = "ios_application_swift_test.sh",
    configurations = IOS_CONFIGURATIONS,
    shard_count = 3,
)

apple_multi_shell_test(
    name = "ios_application_swift_resources_test",
    size = "medium",
    src = "ios_application_swift_resources_test.sh",
    configurations = IOS_CONFIGURATIONS,
    data = [
        "//test/testdata/resources:resource_data_deps_ios",
        "//test/testdata/resources:resource_data_deps_platform_independent",
    ],
    flaky = 1,
    shard_count = 4,
)

apple_multi_shell_test(
    name = "ios_extension_test",
    size = "medium",
    src = "ios_extension_test.sh",
    configurations = IOS_CONFIGURATIONS,
    data = [
        "//test/testdata/binaries:empty_dylib",
        "//test/testdata/binaries:empty_staticlib",
    ],
    shard_count = 12,
)

apple_multi_shell_test(
    name = "ios_extension_resources_test",
    size = "medium",
    src = "ios_extension_resources_test.sh",
    configurations = IOS_CONFIGURATIONS,
    data = [
        "//test/testdata/resources:resource_data_deps_ios",
    ],
    flaky = 1,
    shard_count = 5,
    tags = ["exclusive"],
)

apple_multi_shell_test(
    name = "ios_imessage_test",
    size = "medium",
    src = "ios_imessage_test.sh",
    configurations = IOS_CONFIGURATIONS,
    data = [
        "//test/testdata/resources:resource_data_deps_ios",
    ],
    shard_count = 5,
    tags = ["exclusive"],
)

apple_multi_shell_test(
    name = "ios_extension_swift_test",
    size = "medium",
    src = "ios_extension_swift_test.sh",
    configurations = IOS_CONFIGURATIONS,
    shard_count = 2,
)

apple_multi_shell_test(
    name = "ios_framework_test",
    size = "medium",
    src = "ios_framework_test.sh",
    configurations = IOS_CONFIGURATIONS,
    data = [
        "//test/testdata/binaries:empty_dylib",
        "//test/testdata/resources:resource_data_deps_platform_independent",
    ],
    shard_count = 8,
)

apple_multi_shell_test(
    name = "ios_static_framework_test",
    size = "medium",
    src = "ios_static_framework_test.sh",
    configurations = IOS_CONFIGURATIONS,
    shard_count = 3,
)

apple_multi_shell_test(
    name = "ios_static_framework_resources_test",
    size = "medium",
    src = "ios_static_framework_resources_test.sh",
    configurations = IOS_CONFIGURATIONS,
    data = [
        "//test/testdata/resources:resource_data_deps_ios",
        "//test/testdata/resources:resource_data_deps_platform_independent",
    ],
    flaky = 1,
    shard_count = 3,
)

apple_multi_shell_test(
    name = "macos_application_test",
    size = "medium",
    src = "macos_application_test.sh",
    configurations = MACOS_CONFIGURATIONS,
    shard_count = 8,
)

apple_multi_shell_test(
    name = "macos_application_resources_test",
    size = "medium",
    src = "macos_application_resources_test.sh",
    configurations = MACOS_CONFIGURATIONS,
    data = [
        "//test/testdata/resources:resource_data_deps_platform_independent",
    ],
    shard_count = 8,
)

apple_multi_shell_test(
    name = "macos_application_swift_test",
    size = "medium",
    src = "macos_application_swift_test.sh",
    configurations = MACOS_CONFIGURATIONS,
)

apple_multi_shell_test(
    name = "macos_bundle_test",
    size = "medium",
    src = "macos_bundle_test.sh",
    configurations = MACOS_CONFIGURATIONS,
    shard_count = 7,
)

apple_multi_shell_test(
    name = "macos_command_line_application_test",
    size = "medium",
    src = "macos_command_line_application_test.sh",
    configurations = MACOS_CONFIGURATIONS,
    shard_count = 2,
)

apple_multi_shell_test(
    name = "macos_command_line_application_swift_test",
    size = "medium",
    src = "macos_command_line_application_swift_test.sh",
    configurations = MACOS_CONFIGURATIONS,
    shard_count = 2,
)

apple_multi_shell_test(
    name = "macos_dylib_test",
    size = "medium",
    src = "macos_dylib_test.sh",
    configurations = MACOS_CONFIGURATIONS,
    shard_count = 2,
)

apple_multi_shell_test(
    name = "tvos_application_test",
    size = "medium",
    src = "tvos_application_test.sh",
    configurations = TVOS_CONFIGURATIONS,
    shard_count = 8,
)

apple_multi_shell_test(
    name = "tvos_application_swift_test",
    size = "medium",
    src = "tvos_application_swift_test.sh",
    configurations = TVOS_CONFIGURATIONS,
    shard_count = 2,
)

apple_multi_shell_test(
    name = "tvos_extension_test",
    size = "medium",
    src = "tvos_extension_test.sh",
    configurations = TVOS_CONFIGURATIONS,
    shard_count = 4,
)

apple_multi_shell_test(
    name = "tvos_extension_swift_test",
    size = "medium",
    src = "tvos_extension_swift_test.sh",
    configurations = TVOS_CONFIGURATIONS,
    shard_count = 2,
)

apple_multi_shell_test(
    name = "watchos_application_test",
    size = "medium",
    src = "watchos_application_test.sh",
    configurations = WATCHOS_CONFIGURATIONS,
    shard_count = 8,
)

apple_multi_shell_test(
    name = "watchos_application_swift_test",
    size = "medium",
    src = "watchos_application_swift_test.sh",
    configurations = WATCHOS_CONFIGURATIONS,
    shard_count = 3,
)

apple_multi_shell_test(
    name = "ios_unit_test_test",
    size = "medium",
    src = "ios_unit_test_test.sh",
    configurations = IOS_TEST_CONFIGURATIONS,
    data = [
        "//test/testdata/binaries:empty_dylib",
        "//test/testdata/rules:dummy_runner",
    ],
    shard_count = 8,
)

apple_multi_shell_test(
    name = "ios_unit_test_resources_test",
    size = "medium",
    src = "ios_unit_test_resources_test.sh",
    configurations = IOS_TEST_CONFIGURATIONS,
)

apple_multi_shell_test(
    name = "ios_ui_test_test",
    size = "medium",
    src = "ios_ui_test_test.sh",
    configurations = IOS_TEST_CONFIGURATIONS,
    data = [
        "//test/testdata/rules:dummy_runner",
    ],
    shard_count = 7,
)

apple_multi_shell_test(
    name = "ios_application_clang_rt_test",
    size = "medium",
    src = "ios_application_clang_rt_test.sh",
    configurations = IOS_CONFIGURATIONS,
    shard_count = 2,
)

apple_multi_shell_test(
    name = "macos_unit_test_test",
    size = "medium",
    src = "macos_unit_test_test.sh",
    configurations = MACOS_CONFIGURATIONS,
    data = [
        "//test/testdata/rules:dummy_runner",
    ],
    shard_count = 7,
)

apple_multi_shell_test(
    name = "macos_ui_test_test",
    size = "medium",
    src = "macos_ui_test_test.sh",
    configurations = MACOS_CONFIGURATIONS,
    data = [
        "//test/testdata/rules:dummy_runner",
    ],
    shard_count = 7,
)

apple_multi_shell_test(
    name = "dtrace_test",
    size = "medium",
    src = "dtrace_test.sh",
    configurations = MACOS_CONFIGURATIONS,
)

apple_shell_test(
    name = "ios_test_runner_unit_test",
    size = "large",
    src = "ios_test_runner_unit_test.sh",
    args = [
        "--ios_multi_cpus=i386,x86_64",
    ],
    shard_count = 8,
)

apple_shell_test(
    name = "ios_test_runner_ui_test",
    size = "large",
    src = "ios_test_runner_ui_test.sh",
    args = [
        "--ios_multi_cpus=i386,x86_64",
    ],
    shard_count = 4,
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
