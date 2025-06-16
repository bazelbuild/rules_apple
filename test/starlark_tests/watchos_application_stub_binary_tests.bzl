# Copyright 2025 The Bazel Authors. All rights reserved.
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

"""watchos_application stub binary Starlark tests."""

load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "binary_contents_test",
)

visibility("private")

def watchos_application_stub_binary_test_suite(name):
    """Test suite for watchos_application stub binary artifacts.

    Args:
      name: the base name to be used in things created by this macro
    """

    # Test that the output stub binary is identified as watchOS simulator via the Mach-O load
    # command LC_VERSION_MIN_WATCHOS for the x86_64 binary slice when only iOS cpus are defined, and
    # that 32-bit archs are eliminated.
    binary_contents_test(
        name = "{}_simulator_ios_cpus_intel_platform_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_companion",
        cpus = {
            "ios_multi_cpus": ["x86_64", "sim_arm64"],
            "watchos_cpus": [""],
        },
        binary_test_file = "$BUNDLE_ROOT/Watch/app.app/_WatchKitStub/WK",
        binary_test_architecture = "x86_64",
        binary_not_contains_architectures = ["i386", "arm64e"],
        macho_load_commands_contain = ["cmd LC_VERSION_MIN_WATCHOS"],
        tags = [name],
    )

    # Test that the output application binary is identified as watchOS simulator via the Mach-O
    # load command LC_BUILD_VERSION for the arm64 binary slice when only iOS cpus are defined, and
    # that 32-bit archs are eliminated.
    binary_contents_test(
        name = "{}_simulator_ios_cpus_arm_platform_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_companion",
        cpus = {
            "ios_multi_cpus": ["x86_64", "sim_arm64"],
            "watchos_cpus": [""],
        },
        binary_test_file = "$BUNDLE_ROOT/Watch/app.app/_WatchKitStub/WK",
        binary_test_architecture = "arm64",
        binary_not_contains_architectures = ["i386", "arm64e"],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform WATCHOSSIMULATOR"],
        tags = [name],
    )

    # Test that the output stub binary is identified as watchOS simulator via the Mach-O load
    # command LC_VERSION_MIN_WATCHOS for the arm64 binary slice when only iOS cpus are defined, and
    # that it defaults to armv7k.
    binary_contents_test(
        name = "{}_device_ios_cpus_arm64_platform_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_companion",
        cpus = {
            "ios_multi_cpus": ["arm64"],
            "watchos_cpus": [""],
        },
        binary_test_file = "$BUNDLE_ROOT/Watch/app.app/_WatchKitStub/WK",
        binary_test_architecture = "armv7k",
        binary_not_contains_architectures = ["arm64_32", "arm64", "arm64e"],
        macho_load_commands_contain = ["cmd LC_VERSION_MIN_WATCHOS"],
        tags = [name],
    )

    # Test that the output stub binary is identified as watchOS simulator via the Mach-O load
    # command LC_VERSION_MIN_WATCHOS for the arm64e binary slice when only iOS cpus are defined, and
    # that it defaults to armv7k.
    binary_contents_test(
        name = "{}_device_ios_cpus_arm64e_platform_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_companion",
        cpus = {
            "ios_multi_cpus": ["arm64e"],
            "watchos_cpus": [""],
        },
        binary_test_file = "$BUNDLE_ROOT/Watch/app.app/_WatchKitStub/WK",
        binary_test_architecture = "armv7k",
        binary_not_contains_architectures = ["arm64_32", "arm64", "arm64e"],
        macho_load_commands_contain = ["cmd LC_VERSION_MIN_WATCHOS"],
        tags = [name],
    )

    # Test that the output multi-arch stub binary is identified as watchOS simulator via the Mach-O
    # load command LC_BUILD_VERSION for the arm64 binary slice, and that 32-bit archs are
    # eliminated.
    binary_contents_test(
        name = "{}_simulator_multiarch_platform_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_companion",
        cpus = {
            "watchos_cpus": ["x86_64", "arm64"],
        },
        binary_test_file = "$BUNDLE_ROOT/Watch/app.app/_WatchKitStub/WK",
        binary_test_architecture = "arm64",
        binary_not_contains_architectures = ["i386", "arm64e"],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform WATCHOSSIMULATOR"],
        tags = [name],
    )

    # Test that the output multi-arch stub binary is identified as watchOS device via the Mach-O
    # load command LC_VERSION_MIN_WATCHOS for the arm64_32 binary slice, and that 64-bit archs are
    # eliminated.
    binary_contents_test(
        name = "{}_device_multiarch_arm32_platform_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_companion",
        cpus = {
            "watchos_cpus": ["armv7k", "arm64_32"],
        },
        binary_test_file = "$BUNDLE_ROOT/Watch/app.app/_WatchKitStub/WK",
        binary_not_contains_architectures = ["arm64e", "arm64"],
        binary_test_architecture = "arm64_32",
        macho_load_commands_contain = ["cmd LC_VERSION_MIN_WATCHOS"],
        tags = [name],
    )

    # Test that the output binary for a single arch build is identified as watchOS device via the
    # Mach-O load command LC_VERSION_MIN_WATCHOS for the arm64_32 binary slice, and that the 64-bit
    # archs and the armv7k arch are eliminated.
    binary_contents_test(
        name = "{}_device_arm64_32_platform_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_companion",
        cpus = {
            "watchos_cpus": ["arm64_32"],
        },
        binary_test_file = "$BUNDLE_ROOT/Watch/app.app/_WatchKitStub/WK",
        binary_not_contains_architectures = ["armv7k", "arm64e", "arm64"],
        binary_test_architecture = "arm64_32",
        macho_load_commands_contain = ["cmd LC_VERSION_MIN_WATCHOS"],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
