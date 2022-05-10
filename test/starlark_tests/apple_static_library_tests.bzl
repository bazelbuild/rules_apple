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
    ":rules/analysis_lipo_test.bzl",
    "analysis_lipo_test",
)
load(
    ":rules/analysis_runfiles_test.bzl",
    "analysis_runfiles_test",
)
load(
    ":rules/analysis_symlink_test.bzl",
    "analysis_symlink_test",
)
load(
    ":rules/analysis_target_outputs_test.bzl",
    "analysis_target_outputs_test",
)
load(
    ":rules/common_verification_tests.bzl",
    "binary_contents_test",
)

def apple_static_library_test_suite(name):
    """Test suite for apple_static_library.

    Args:
      name: The base name to be used in things created by this macro.
    """

    # Test that the output library follows a given form of {target name}_lipo.a.
    analysis_target_outputs_test(
        name = "{}_output_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library",
        expected_outputs = ["example_library_lipo.a"],
        tags = [name],
    )

    # Test that the static library output generates a symlink action as one of its output actions
    # for single arch builds.
    analysis_symlink_test(
        name = "{}_ios_symlink_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library",
        tags = [name],
    )

    # Test that the static library output generates a lipo action as one of its output actions for
    # multi arch iOS Simulator builds.
    analysis_lipo_test(
        name = "{}_ios_lipo_test".format(name),
        expected_sdk_platform = "iPhoneSimulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library",
        tags = [name],
    )

    # Test that the static library output generates a lipo action as one of its output actions for
    # multi arch watchOS builds.
    analysis_lipo_test(
        name = "{}_watchos_lipo_test".format(name),
        expected_sdk_platform = "WatchOS",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_watch_library_os8",
        tags = [name],
    )

    # Test that the output library archive is added to the final list of runfiles, as well as any
    # other library archive files that could be required at runtime execution.
    analysis_runfiles_test(
        name = "{}_runfiles_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library",
        expected_runfiles = [
            "test/starlark_tests/targets_under_test/apple/static_library/example_library_lipo.a",
            "test/starlark_tests/targets_under_test/apple/static_library/libmain_lib.a",
        ],
        tags = [name],
    )

    # Verify that this is a "static library" as identified by macOS, which is also known as an
    # archive produced by `ar`.
    binary_contents_test(
        name = "{}_file_info_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library",
        binary_test_file = "$BINARY",
        binary_contains_file_info = ["current ar archive"],
        tags = [name],
    )

    # Test the output binary for minimum OS 8.0, using the old-style load commands that are no
    # longer in binaries built for min OS iOS 14+ which don't explicitly distinguish the simulator.
    binary_contents_test(
        name = "{}_ios_binary_contents_intel_simulator_os8_platform_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library",
        cpus = {
            "ios_multi_cpus": ["x86_64"],
        },
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        macho_load_commands_contain = ["cmd LC_VERSION_MIN_IPHONEOS", "version 8.0"],
        tags = [name],
    )

    # The LC_BUILD_VERSION is always present in binaries built with minimum version >= 2020 Apple
    # OSes, which will have fields of "minos {version number}" and "platform {platform enum}".

    # Test that the output binary is identified as iOS simulator (PLATFORM_IOSSIMULATOR) via the
    # Mach-O load command LC_BUILD_VERSION for an Intel binary.
    binary_contents_test(
        name = "{}_ios_binary_contents_intel_simulator_platform_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library_os14",
        cpus = {
            "ios_multi_cpus": ["x86_64"],
        },
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos 14.0", "platform IOSSIMULATOR"],
        tags = [name],
    )

    # Test that the output binary is identified as iOS simulator (PLATFORM_IOSSIMULATOR) via the
    # Mach-O load command LC_BUILD_VERSION for an Arm binary.
    binary_contents_test(
        name = "{}_ios_binary_contents_arm_simulator_platform_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library_os14",
        cpus = {
            "ios_multi_cpus": ["sim_arm64"],
        },
        binary_test_file = "$BINARY",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos 14.0", "platform IOSSIMULATOR"],
        tags = [name],
    )

    # Test that the output binary is identified as iOS device (PLATFORM_IOS) via the Mach-O load
    # command LC_BUILD_VERSION for an Arm binary.
    binary_contents_test(
        name = "{}_ios_binary_contents_device_platform_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library_os14",
        cpus = {
            "ios_multi_cpus": ["arm64"],
        },
        binary_test_file = "$BINARY",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos 14.0", "platform IOS"],
        tags = [name],
    )

    # Test that the output multi-arch binary is identified as iOS simulator (PLATFORM_IOSSIMULATOR)
    # via the Mach-O load command LC_BUILD_VERSION for the Intel binary slice.
    binary_contents_test(
        name = "{}_ios_simulator_multiarch_intel_platform_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library_os14",
        cpus = {
            "ios_multi_cpus": ["x86_64", "sim_arm64"],
        },
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos 14.0", "platform IOSSIMULATOR"],
        tags = [name],
    )

    # Test that the output multi-arch binary is identified as iOS simulator (PLATFORM_IOSSIMULATOR)
    # via the Mach-O load command LC_BUILD_VERSION for the Arm binary slice.
    binary_contents_test(
        name = "{}_ios_simulator_multiarch_arm_platform_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_library_os14",
        cpus = {
            "ios_multi_cpus": ["x86_64", "sim_arm64"],
        },
        binary_test_file = "$BINARY",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos 14.0", "platform IOSSIMULATOR"],
        tags = [name],
    )

    # Test that the output binary is identified as watchOS simulator (PLATFORM_WATCHOSSIMULATOR) via
    # the Mach-O load command LC_BUILD_VERSION for an Intel binary.
    binary_contents_test(
        name = "{}_watchos_binary_contents_intel_simulator_platform_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_watch_library_os8",
        cpus = {
            "watchos_cpus": ["x86_64"],
        },
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos 8.0", "platform WATCHOSSIMULATOR"],
        tags = [name],
    )

    # Test that the output binary is identified as watchOS device (PLATFORM_WATCHOS) via the Mach-O
    # load command LC_BUILD_VERSION for an Arm 64-on-32 binary.
    binary_contents_test(
        name = "{}_watchos_binary_contents_device_platform_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/apple/static_library:example_watch_library_os8",
        cpus = {
            "watchos_cpus": ["arm64_32"],
        },
        binary_test_file = "$BINARY",
        binary_test_architecture = "arm64_32",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos 8.0", "platform WATCHOS"],
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

    native.test_suite(
        name = name,
        tags = [name],
    )
