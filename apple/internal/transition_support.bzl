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

"""
Starlark transition support for Apple rules.

This module makes the following distinctions around Apple CPU-adjacent values for clarity, based in
part on the language used for XCFramework library identifiers:

- `architecture`s or "arch"s represent the type of binary slice ("arm64", "x86_64").

- `environment`s represent a platform variant ("device", "sim"). These sometimes appear in the "cpu"
    keys out of necessity to distinguish new "cpu"s from an existing Apple "cpu" when a new
    Crosstool-provided toolchain is established.

- `platform_type`s represent the Apple OS being built for ("ios", "macos", "tvos", "visionos",
    "watchos").

- `cpu`s are keys to match a Crosstool-provided toolchain ("ios_sim_arm64", "ios_x86_64").
    Essentially it is a raw key that implicitly references the other three values for the purpose of
    getting the right Apple toolchain to build outputs with from the Apple Crosstool.
"""

load(
    "@build_bazel_rules_apple//apple/build_settings:build_settings.bzl",
    "build_settings_labels",
)
load(
    "@build_bazel_rules_apple//apple/internal:base_transition_support.bzl",
    "base_transition_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:secure_features_support.bzl",
    "secure_features_support",
)

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

def _apple_platform_split_transition_impl(settings, attr):
    """Starlark 1:2+ transition for Apple platform-aware rules"""
    minimum_os_version = attr.minimum_os_version
    platform_type = attr.platform_type
    requested_features = secure_features_support.crosstool_features_from_secure_features(
        features = settings["//command_line_option:features"],
        name = attr.name,
        secure_features = getattr(attr, "secure_features", None),
    )
    resolved_environment_archs = secure_features_support.environment_archs_from_secure_features(
        environment_archs = base_transition_support.environment_archs(
            platform_type = platform_type,
            minimum_os_version = minimum_os_version,
            settings = settings,
        ),
        require_pointer_authentication_attribute = (
            settings[build_settings_labels.require_pointer_authentication_attribute]
        ),
        secure_features = requested_features,
    )

    output_dictionary = {}

    invalid_requested_archs = []

    building_apple_bundle = getattr(attr, "_building_apple_bundle", True)
    force_bundle_outputs = getattr(attr, "_force_bundle_outputs", False)
    for environment_arch in resolved_environment_archs:
        found_cpu = base_transition_support.cpu_string(
            environment_arch = environment_arch,
            minimum_os_version = minimum_os_version,
            platform_type = platform_type,
            settings = settings,
        )
        if found_cpu in output_dictionary:
            continue

        environment_arch_is_supported = base_transition_support.is_arch_supported_for_target_tuple(
            environment_arch = environment_arch,
            minimum_os_version = minimum_os_version,
            platform_type = platform_type,
        )
        if not environment_arch_is_supported:
            invalid_requested_arch = {
                "environment_arch": environment_arch,
                "minimum_os_version": minimum_os_version,
                "platform_type": platform_type,
            }

            # NOTE: This logic to filter unsupported Apple CPUs is not possible to implement on
            # incoming platforms without matching labels. For that reason, custom platforms are
            # not supported for Apple builds. This is a known shortcoming of the Starlark platform
            # transition design.
            #
            # Propagate a warning to the user so that the status of the dropped arch is known.
            # buildifier: disable=print
            print(
                """
WARNING: The architecture {environment_arch} is not valid for {platform_type} with a minimum OS of \
{minimum_os_version}. This architecture has been ignored.""".format(
                    **invalid_requested_arch
                ),
            )
            invalid_requested_archs.append(invalid_requested_arch)
            continue

        output_dictionary[found_cpu] = base_transition_support.command_line_options(
            building_apple_bundle = building_apple_bundle,
            environment_arch = environment_arch,
            features = requested_features,
            force_bundle_outputs = force_bundle_outputs,
            minimum_os_version = minimum_os_version,
            platform_type = platform_type,
            settings = settings,
        )

    if not bool(output_dictionary):
        error_msg = "Could not find any valid architectures to build for the current target.\n\n"
        if invalid_requested_archs:
            error_msg += "Requested the following invalid architectures:\n"
            for invalid_requested_arch in invalid_requested_archs:
                error_msg += (
                    " - {environment_arch} for {platform_type} {minimum_os_version}\n".format(
                        **invalid_requested_arch
                    )
                )
            error_msg += (
                "\nPlease check that the specified architectures are valid for the target's " +
                "specified minimum_os_version.\n"
            )
        fail(error_msg)

    return output_dictionary

_apple_platform_split_transition = transition(
    implementation = _apple_platform_split_transition_impl,
    inputs = base_transition_support.apple_rule_base_transition_inputs,
    outputs = base_transition_support.apple_rule_base_transition_outputs,
)

def _watchos2_app_extension_transition_impl(_, __):
    """Rule transition for watchOS 2 app extensions that forces required linking options."""
    return {
        build_settings_labels.link_watchos_2_app_extension: True,
    }

_watchos2_app_extension_transition = transition(
    implementation = _watchos2_app_extension_transition_impl,
    inputs = [],
    outputs = [build_settings_labels.link_watchos_2_app_extension],
)

transition_support = struct(
    apple_platform_split_transition = _apple_platform_split_transition,
    apple_rule_bundle_output_transition = base_transition_support.apple_rule_bundle_output_transition,
    apple_rule_transition = base_transition_support.apple_rule_base_transition,
    watchos2_app_extension_transition = _watchos2_app_extension_transition,
)
