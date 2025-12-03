# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""tvos_framework Starlark tests."""

load(
    "//test/starlark_tests/rules:analysis_failure_message_test.bzl",
    "analysis_failure_message_test",
)
load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "archive_contents_test",
)
load(
    ":common.bzl",
    "common",
)

visibility("private")

def tvos_static_framework_test_suite(name):
    """Test suite for tvos_static_framework.

    Args:
      name: the base name to be used in things created by this macro
    """
    archive_contents_test(
        name = "{}_contents_test".format(name),
        build_type = "simulator",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/tvos:static_fmwk",
        contains = [
            "$BUNDLE_ROOT/Headers/static_fmwk.h",
            "$BUNDLE_ROOT/Headers/shared.h",
            "$BUNDLE_ROOT/Modules/module.modulemap",
        ],
        tags = [name],
    )

    # Tests Swift tvos_static_framework builds correctly for sim_arm64, and x86_64 cpu's.
    archive_contents_test(
        name = "{}_swift_sim_arm64_builds_using_tvos_cpus".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/tvos:swift_static_fmwk",
        cpus = {
            "tvos_cpus": ["x86_64", "sim_arm64"],
        },
        binary_test_file = "$BUNDLE_ROOT/swift_static_fmwk",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_tvos.arm_sim_support, "platform TVOSSIMULATOR"],
        macho_load_commands_not_contain = ["cmd LC_VERSION_MIN_TVOS"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_swift_x86_64_builds_using_tvos_cpus".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/tvos:swift_static_fmwk",
        cpus = {
            "tvos_cpus": ["x86_64", "sim_arm64"],
        },
        binary_test_file = "$BUNDLE_ROOT/swift_static_fmwk",
        binary_test_architecture = "x86_64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos " + common.min_os_tvos.baseline, "platform TVOSSIMULATOR"],
        macho_load_commands_not_contain = ["cmd LC_VERSION_MIN_TVOS"],
        tags = [name],
    )

    # Tests secure features support for pointer authentication retains both the arm64 and arm64e
    # slices.
    archive_contents_test(
        name = "{}_pointer_authentication_arm64_slice_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/tvos:pointer_authentication_static_fmwk",
        cpus = {
            "tvos_cpus": ["arm64", "arm64e"],
        },
        binary_test_file = "$BUNDLE_ROOT/pointer_authentication_static_fmwk",
        binary_test_architecture = "arm64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform TVOS"],
        tags = [name],
    )
    archive_contents_test(
        name = "{}_pointer_authentication_arm64e_slice_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/tvos:pointer_authentication_static_fmwk",
        cpus = {
            "tvos_cpus": ["arm64", "arm64e"],
        },
        binary_test_file = "$BUNDLE_ROOT/pointer_authentication_static_fmwk",
        binary_test_architecture = "arm64e",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform TVOS"],
        tags = [name],
    )

    # Tests secure features support for validating features at the rule level.
    analysis_failure_message_test(
        name = "{}_secure_features_disabled_at_rule_level_should_fail_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/tvos:enhanced_security_static_fmwk_with_rule_level_disabled_features",
        expected_error = "Attempted to enable the secure feature `trivial_auto_var_init` for the target at `//test/starlark_tests/targets_under_test/tvos:enhanced_security_static_fmwk_with_rule_level_disabled_features`",
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
