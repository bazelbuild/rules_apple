# Copyright 2022 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""apple_static_library Starlark tests."""

load(
    "//apple/build_settings:build_settings.bzl",
    "build_settings_labels",
)
load(
    "//test/starlark_tests/rules:analysis_runfiles_test.bzl",
    "analysis_runfiles_test",
)
load(
    "//test/starlark_tests/rules:analysis_target_actions_test.bzl",
    "analysis_target_actions_test",
    "make_analysis_target_actions_test",
)
load(
    "//test/starlark_tests/rules:analysis_target_outputs_test.bzl",
    "analysis_target_outputs_test",
)
load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "binary_contents_test",
)
load(
    ":common.bzl",
    "common",
)

analysis_target_actions_with_multi_cpus_test = make_analysis_target_actions_test(
    config_settings = {
        build_settings_labels.require_pointer_authentication_attribute: True,
        "//command_line_option:macos_cpus": "arm64,x86_64",
        "//command_line_option:ios_multi_cpus": "sim_arm64,x86_64",
        "//command_line_option:tvos_cpus": "sim_arm64,x86_64",
        "//command_line_option:watchos_cpus": "arm64,x86_64",
    },
)

def apple_static_library_test_suite(name):
    """Test suite for apple_static_library.

    Args:
      name: The base name to be used in things created by this macro.
    """

    # Test that the output library follows a given form of {target name}_lipo.a.
    analysis_target_outputs_test(
        name = "{}_output_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library_arm_sim_support",
        expected_outputs = ["example_library_arm_sim_support_lipo.a"],
        tags = [name],
    )

    # Test that the static library output generates a symlink action as one of its output actions
    # for single arch builds.
    analysis_target_actions_test(
        name = "{}_ios_symlink_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library_arm_sim_support",
        target_mnemonic = "Symlink",
        not_expected_mnemonic = ["AppleLipo"],
        tags = [name],
    )

    # Test that the static library output generates a lipo action as one of its output actions for
    # multi arch iOS Simulator builds.
    analysis_target_actions_with_multi_cpus_test(
        name = "{}_ios_lipo_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library_arm_sim_support",
        target_mnemonic = "AppleLipo",
        expected_env = {
            "APPLE_SDK_PLATFORM": "iPhoneSimulator",
        },
        tags = [name],
    )

    # Test that the static library output generates a lipo action as one of its output actions for
    # multi arch watchOS builds.
    analysis_target_actions_with_multi_cpus_test(
        name = "{}_watchos_lipo_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_watch_library_arm_sim_support",
        target_mnemonic = "AppleLipo",
        expected_env = {
            "APPLE_SDK_PLATFORM": "WatchSimulator",
        },
        tags = [name],
    )

    # Test that the output library archive is added to the final list of runfiles, as well as any
    # other library archive files that could be required at runtime execution.
    analysis_runfiles_test(
        name = "{}_runfiles_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library_arm_sim_support",
        expected_runfiles = [
            "test/starlark_tests/targets_under_test/apple/static_library/example_library_arm_sim_support_lipo.a",
            "test/starlark_tests/targets_under_test/apple/static_library/libmain_lib.a",
        ],
        tags = [name],
    )

    # Verify that this is a "static library" as identified by macOS, which is also known as an
    # archive produced by `ar`.
    binary_contents_test(
        name = "{}_file_info_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library_arm_sim_support",
        binary_test_file = "$BINARY",
        binary_contains_file_info = ["current ar archive"],
        tags = [name],
    )

    # The LC_BUILD_VERSION is always present in binaries built with minimum version >= 2020 Apple
    # OSes, which will have fields of "minos {version number}" and "platform {platform enum}".

    # Test that the output binary is identified as iOS simulator (PLATFORM_IOSSIMULATOR) via the
    # Mach-O load command LC_BUILD_VERSION for an Intel binary.
    binary_contents_test(
        name = "{}_ios_binary_contents_intel_simulator_platform_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library_arm_sim_support",
        cpus = {
            "ios_multi_cpus": ["x86_64"],
        },
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_ios.baseline, "platform IOSSIMULATOR"],
        tags = [name],
    )

    # Test that the output binary is identified as iOS simulator (PLATFORM_IOSSIMULATOR) via the
    # Mach-O load command LC_BUILD_VERSION for an Arm binary.
    binary_contents_test(
        name = "{}_ios_binary_contents_arm_simulator_platform_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library_arm_sim_support",
        cpus = {
            "ios_multi_cpus": ["sim_arm64"],
        },
        binary_test_file = "$BINARY",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_ios.baseline, "platform IOSSIMULATOR"],
        tags = [name],
    )

    # Test that the output binary is identified as iOS device (PLATFORM_IOS) via the Mach-O load
    # command LC_BUILD_VERSION for an Arm binary when specifying the outputs via the platforms
    # command line option.
    binary_contents_test(
        name = "{}_ios_binary_contents_device_apple_platforms_test".format(name),
        cpus = {
            "platforms": ["@build_bazel_apple_support//platforms:ios_arm64"],
            "ios_multi_cpus": [],
        },
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library_arm_sim_support",
        binary_test_file = "$BINARY",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_ios.baseline, "platform IOS"],
        tags = [name],
    )

    # Test that the output binary is identified as iOS device (PLATFORM_IOS) arm64e static library
    # archive via the Mach-O load command LC_BUILD_VERSION for an Arm binary when specifying the
    # outputs via the platforms command line option.
    binary_contents_test(
        name = "{}_ios_binary_contents_device_arm64e_apple_platforms_test".format(name),
        cpus = {
            "platforms": ["@build_bazel_apple_support//platforms:ios_arm64e"],
            "ios_multi_cpus": [],
        },
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library_arm_sim_support",
        binary_test_file = "$BINARY",
        binary_test_architecture = "arm64e",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_ios.baseline, "platform IOS"],
        tags = [name],
    )

    # Test that the output binary is identified as iOS device (PLATFORM_IOS) via the Mach-O load
    # command LC_BUILD_VERSION for an Arm binary.
    binary_contents_test(
        name = "{}_ios_binary_contents_device_arm64_platform_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library_arm_sim_support",
        cpus = {
            "ios_multi_cpus": ["arm64"],
        },
        binary_test_file = "$BINARY",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_ios.baseline, "platform IOS"],
        tags = [name],
    )

    # Test that the output binary is identified as iOS device (PLATFORM_IOS) via the Mach-O load
    # command LC_BUILD_VERSION for an arm64 + arm64e binary on the arm64 slice.
    binary_contents_test(
        name = "{}_ios_binary_contents_device_multiarch_arm64_platform_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library_arm_sim_support",
        cpus = {
            "ios_multi_cpus": ["arm64", "arm64e"],
        },
        binary_test_file = "$BINARY",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_ios.baseline, "platform IOS"],
        tags = [name],
    )

    # Test that the output binary is identified as iOS device (PLATFORM_IOS) via the Mach-O load
    # command LC_BUILD_VERSION for an arm64 + arm64e binary on the arm64e slice.
    binary_contents_test(
        name = "{}_ios_binary_contents_device_multiarch_arm64e_platform_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library_arm_sim_support",
        cpus = {
            "ios_multi_cpus": ["arm64", "arm64e"],
        },
        binary_test_file = "$BINARY",
        binary_test_architecture = "arm64e",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_ios.baseline, "platform IOS"],
        tags = [name],
    )

    # Test that the output multi-arch binary is identified as iOS simulator (PLATFORM_IOSSIMULATOR)
    # via the Mach-O load command LC_BUILD_VERSION for the Intel binary slice.
    binary_contents_test(
        name = "{}_ios_simulator_multiarch_intel_platform_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library_arm_sim_support",
        cpus = {
            "ios_multi_cpus": ["x86_64", "sim_arm64"],
        },
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_ios.baseline, "platform IOSSIMULATOR"],
        tags = [name],
    )

    # Test that the output multi-arch binary is identified as iOS simulator (PLATFORM_IOSSIMULATOR)
    # via the Mach-O load command LC_BUILD_VERSION for the Arm binary slice.
    binary_contents_test(
        name = "{}_ios_simulator_multiarch_arm_platform_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library_arm_sim_support",
        cpus = {
            "ios_multi_cpus": ["x86_64", "sim_arm64"],
        },
        binary_test_file = "$BINARY",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_ios.baseline, "platform IOSSIMULATOR"],
        tags = [name],
    )

    # Test that the output binary is identified as watchOS simulator (PLATFORM_WATCHOSSIMULATOR) via
    # the Mach-O load command LC_BUILD_VERSION for an Intel binary.
    binary_contents_test(
        name = "{}_watchos_binary_contents_intel_simulator_platform_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_watch_library_arm_sim_support",
        cpus = {
            "watchos_cpus": ["x86_64"],
        },
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_watchos.baseline, "platform WATCHOSSIMULATOR"],
        tags = [name],
    )

    # Test that the output binary is identified as watchOS device (PLATFORM_WATCHOS) via the Mach-O
    # load command LC_BUILD_VERSION for an Arm 64-on-32 binary.
    binary_contents_test(
        name = "{}_watchos_binary_contents_device_platform_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_watch_library_arm_sim_support",
        cpus = {
            "watchos_cpus": ["arm64_32"],
        },
        binary_test_file = "$BINARY",
        binary_test_architecture = "arm64_32",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_watchos.baseline, "platform WATCHOS"],
        tags = [name],
    )

    # Test that avoid_deps works on an apple_static_library target with objc_library deps.
    binary_contents_test(
        name = "{}_ios_avoid_deps_test".format(name),
        build_type = "simulator",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library_with_avoid_deps",
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_doStuff"],
        binary_not_contains_symbols = ["_frameworkDependent"],
        tags = [name],
    )

    # Test that avoid_deps works on an apple_static_library target with cc_library deps.
    binary_contents_test(
        name = "{}_ios_cc_avoid_deps_test".format(name),
        build_type = "simulator",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library_with_cc_avoid_deps",
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_doStuff"],
        binary_not_contains_symbols = ["_frameworkDependent"],
        tags = [name],
    )

    # Test that the output binary is identified as visionOS simulator (PLATFORM_VISIONOSSIMULATOR) via
    # the Mach-O load command LC_BUILD_VERSION for an arm64 binary.
    binary_contents_test(
        name = "{}_visionos_binary_contents_arm_simulator_platform_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_vision_library",
        cpus = {
            "visionos_cpus": ["sim_arm64"],
        },
        binary_test_file = "$BINARY",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_visionos.baseline, "platform VISIONOSSIMULATOR"],
        tags = [
            name,
        ],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
