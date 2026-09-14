load("@rules_cc//cc:objc_library.bzl", "objc_library")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load("//apple:ios.bzl", "ios_test_runner", "ios_unit_test", "ios_xctestrun_runner")

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

# These dependencies must be configured for macOS, even though Linux is the
# preferred execution platform. An incorrect cfg = "exec" makes the tests
# incompatible rather than silently accepting a platform-independent script.
sh_binary(
    name = "macos_action",
    srcs = ["macos_action.sh"],
    tags = ["manual"],
    target_compatible_with = ["@platforms//os:macos"],
)

alias(
    name = "macos_simulator_creator",
    actual = "//apple/testing/default_runner:simulator_creator",
    target_compatible_with = ["@platforms//os:macos"],
)

alias(
    name = "macos_simulator_cleanup",
    actual = "//apple/testing/default_runner:simulator_cleanup",
    target_compatible_with = ["@platforms//os:macos"],
)

ios_test_runner(
    name = "legacy_runner",
    create_simulator_action = ":macos_simulator_creator",
    post_action = ":macos_action",
    pre_action = ":macos_action",
    tags = ["manual"],
)

ios_xctestrun_runner(
    name = "custom_xctestrun_runner",
    clean_up_simulator_action = ":macos_simulator_cleanup",
    create_simulator_action = ":macos_simulator_creator",
    post_action = ":macos_action",
    pre_action = ":macos_action",
    tags = ["manual"],
)

ios_unit_test(
    name = "legacy_runner_test",
    families = ["iphone"],
    minimum_os_version = "15.5",
    runner = ":legacy_runner",
    tags = ["manual"],
    deps = [":test_lib"],
)

ios_unit_test(
    name = "custom_xctestrun_runner_test",
    families = ["iphone"],
    minimum_os_version = "15.5",
    runner = ":custom_xctestrun_runner",
    tags = ["manual"],
    deps = [":test_lib"],
)
