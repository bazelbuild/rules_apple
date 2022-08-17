# Copyright 2020 The Bazel Authors. All rights reserved.
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

"""ios_static_framework Starlark tests."""

load(
    ":common.bzl",
    "common",
)
load(
    ":rules/analysis_failure_message_test.bzl",
    "analysis_failure_message_test",
)
load(
    ":rules/common_verification_tests.bzl",
    "archive_contents_test",
)

def ios_static_framework_test_suite(name):
    """Test suite for ios_static_framework.

    Args:
      name: the base name to be used in things created by this macro
    """

    # Tests Swift ios_static_framework builds correctly for sim_arm64, and x86_64 cpu's.
    archive_contents_test(
        name = "{}_swift_sim_arm64_builds_using_cpu".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_ios_static_framework",
        apple_cpu = "ios_sim_arm64",
        cpus = {
            "ios_multi_cpus": [],
        },
        binary_test_file = "$BUNDLE_ROOT/SwiftFmwk",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_ios.arm_sim_support, "platform IOSSIMULATOR"],
        macho_load_commands_not_contain = ["cmd LC_VERSION_MIN_IPHONEOS"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_swift_sim_arm64_builds_using_ios_multi_cpus".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_ios_static_framework",
        cpus = {
            "ios_multi_cpus": ["x86_64", "sim_arm64"],
        },
        binary_test_file = "$BUNDLE_ROOT/SwiftFmwk",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_ios.arm_sim_support, "platform IOSSIMULATOR"],
        macho_load_commands_not_contain = ["cmd LC_VERSION_MIN_IPHONEOS"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_swift_x86_64_builds_using_ios_multi_cpus".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_ios_static_framework",
        cpus = {
            "ios_multi_cpus": ["x86_64", "sim_arm64"],
        },
        binary_test_file = "$BUNDLE_ROOT/SwiftFmwk",
        binary_test_architecture = "x86_64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_ios.baseline, "platform IOSSIMULATOR"],
        macho_load_commands_not_contain = ["cmd LC_VERSION_MIN_IPHONEOS"],
        tags = [name],
    )

    # Tests Swift ios_static_framework builds correctly for apple_platforms.
    archive_contents_test(
        name = "{}_swift_sim_arm64_builds_using_apple_platforms".format(name),
        apple_platforms = [
            "//buildenv/platforms/apple/simulator:ios_arm64",
            "//buildenv/platforms/apple/simulator:ios_x86_64",
        ],
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_ios_static_framework",
        binary_test_file = "$BUNDLE_ROOT/SwiftFmwk",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_ios.arm_sim_support, "platform IOSSIMULATOR"],
        macho_load_commands_not_contain = ["cmd LC_VERSION_MIN_IPHONEOS"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_swift_x86_64_builds_using_apple_platforms".format(name),
        apple_platforms = [
            "//buildenv/platforms/apple/simulator:ios_arm64",
            "//buildenv/platforms/apple/simulator:ios_x86_64",
        ],
        build_type = "simulator",
        binary_test_file = "$BUNDLE_ROOT/SwiftFmwk",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:swift_ios_static_framework",
        binary_test_architecture = "x86_64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_ios.baseline, "platform IOSSIMULATOR"],
        macho_load_commands_not_contain = ["cmd LC_VERSION_MIN_IPHONEOS"],
        tags = [name],
    )

    # Test that it's permitted for a static framework to have multiple
    # `swift_library` dependencies if only one module remains after excluding
    # the transitive closure of `avoid_deps`. Likewise, make sure that the
    # symbols from the avoided deps aren't linked in. (In a situation like
    # this, the user must provide those dependencies separately if they are
    # needed.)
    archive_contents_test(
        name = "{}_swift_avoid_deps_test".format(name),
        build_type = "simulator",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:static_fmwk_with_swift_and_avoid_deps",
        contains = [
            "$BUNDLE_ROOT/Modules/SwiftFmwkUpperLib.swiftmodule/x86_64.swiftdoc",
            "$BUNDLE_ROOT/Modules/SwiftFmwkUpperLib.swiftmodule/x86_64.swiftinterface",
        ],
        binary_test_file = "$BUNDLE_ROOT/SwiftFmwkUpperLib",
        binary_test_architecture = "x86_64",
        binary_contains_symbols = ["_$s17SwiftFmwkUpperLib5DummyVMn"],
        binary_not_contains_symbols = [
            "_$s17SwiftFmwkLowerLib5DummyVMn",
            "_$s18SwiftFmwkLowestLib5DummyVMn",
        ],
        tags = [name],
    )

    # Test that the Swift generated header is propagated to the Headers visible
    # within this iOS framework along with the swift interfaces and modulemap.
    archive_contents_test(
        name = "{}_swift_generates_header_test".format(name),
        build_type = "simulator",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/ios:static_framework_with_generated_header",
        contains = [
            "$BUNDLE_ROOT/Headers/SwiftFmwkWithGenHeader.h",
            "$BUNDLE_ROOT/Modules/module.modulemap",
            "$BUNDLE_ROOT/Modules/SwiftFmwkWithGenHeader.swiftmodule/x86_64.swiftdoc",
            "$BUNDLE_ROOT/Modules/SwiftFmwkWithGenHeader.swiftmodule/x86_64.swiftinterface",
        ],
        tags = [name],
    )

    # Test that an actionable error is produced for the user when a header to
    # bundle conflicts with the generated umbrella header.
    analysis_failure_message_test(
        name = "{}_umbrella_header_conflict_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:static_framework_with_umbrella_header_conflict",
        expected_error = "Found imported header file(s) which conflict(s) with the name \"UmbrellaHeaderConflict.h\" of the generated umbrella header for this target. Check input files:\nthird_party/bazel_rules/rules_apple/test/starlark_tests/resources/UmbrellaHeaderConflict.h\n\nPlease remove the references to these files from your rule's list of headers to import or rename the headers if necessary.",
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
