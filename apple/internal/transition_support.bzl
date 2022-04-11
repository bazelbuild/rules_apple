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

"""Starlark transition support for Apple rules."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")

_PLATFORM_TYPE_TO_CPU_FLAG = {
    "ios": "//command_line_option:ios_multi_cpus",
    "macos": "//command_line_option:macos_cpus",
    "tvos": "//command_line_option:tvos_cpus",
    "watchos": "//command_line_option:watchos_cpus",
}

def _platform_specific_cpu_setting_name(platform_type):
    """Returns the name of a platform-specific CPU setting.

    Args:
        platform_type: A string denoting the platform type; `"ios"`, `"macos"`,
            `"tvos"`, or `"watchos"`.

    Returns:
        The `"//command_line_option:..."` string that is used as the key for the
        CPU flag of the given platform in settings dictionaries. This function
        never returns `None`; if the platform type is invalid, the build fails.
    """
    flag = _PLATFORM_TYPE_TO_CPU_FLAG.get(platform_type, None)
    if not flag:
        fail("ERROR: Unknown platform type: {}".format(platform_type))
    return flag

def _cpu_string(*, cpu, platform_type, settings = {}):
    """Generates a <platform>_<arch> string for the current target based on the given parameters.

    Args:
        cpu: A valid Apple cpu command line option as a string, or None to infer a value from
            command line options passed through settings.
        platform_type: The Apple platform for which the rule should build its targets (`"ios"`,
            `"macos"`, `"tvos"`, or `"watchos"`).
        settings: A dictionary whose set of keys is defined by the inputs parameter, typically from
            the settings argument found on the implementation function of the current Starlark
            transition. If not defined, defaults to an empty dictionary. Used as a fallback if the
            `cpu` argument is None.

    Returns:
        A <platform>_<arch> string defined for the current target.
    """
    if platform_type == "ios":
        if cpu:
            return "ios_{}".format(cpu)
        ios_cpus = settings["//command_line_option:ios_multi_cpus"]
        if ios_cpus:
            return "ios_{}".format(ios_cpus[0])
        cpu_value = settings["//command_line_option:cpu"]
        if cpu_value.startswith("ios_"):
            return cpu_value
        if cpu_value == "darwin_arm64":
            return "ios_sim_arm64"
        return "ios_x86_64"
    if platform_type == "macos":
        if cpu:
            return "darwin_{}".format(cpu)
        macos_cpus = settings["//command_line_option:macos_cpus"]
        if macos_cpus:
            return "darwin_{}".format(macos_cpus[0])
        cpu_value = settings["//command_line_option:cpu"]
        if cpu_value.startswith("darwin_"):
            return cpu_value
        return "darwin_x86_64"
    if platform_type == "tvos":
        if cpu:
            return "tvos_{}".format(cpu)
        tvos_cpus = settings["//command_line_option:tvos_cpus"]
        if tvos_cpus:
            return "tvos_{}".format(tvos_cpus[0])
        return "tvos_x86_64"
    if platform_type == "watchos":
        if cpu:
            return "watchos_{}".format(cpu)
        watchos_cpus = settings["//command_line_option:watchos_cpus"]
        if watchos_cpus:
            return "watchos_{}".format(watchos_cpus[0])
        return "watchos_i386"

    fail("ERROR: Unknown platform type: {}".format(platform_type))

def _min_os_version_or_none(*, minimum_os_version, platform, platform_type):
    if platform_type == platform:
        return minimum_os_version
    return None

def _command_line_options(
        *,
        cpu = None,
        emit_swiftinterface = False,
        minimum_os_version,
        platform_type,
        settings):
    """Generates a dictionary of command line options suitable for the current target.

    Args:
        cpu: A valid Apple cpu command line option as a string, or None to infer a value from
            command line options passed through settings.
        emit_swiftinterface: Wheither to emit swift interfaces for the given target. Defaults to
            `False`.
        minimum_os_version: A string representing the minimum OS version specified for this
            platform, represented as a dotted version number (for example, `"9.0"`).
        platform_type: The Apple platform for which the rule should build its targets (`"ios"`,
            `"macos"`, `"tvos"`, or `"watchos"`).
        settings: A dictionary whose set of keys is defined by the inputs parameter, typically from
            the settings argument found on the implementation function of the current Starlark
            transition.

    Returns:
        A dictionary of `"//command_line_option"`s defined for the current target.
    """

    output_dictionary = {
        "//command_line_option:apple configuration distinguisher": "applebin_" + platform_type,
        "//command_line_option:apple_platform_type": platform_type,
        "//command_line_option:apple_split_cpu": cpu if cpu else "",
        "//command_line_option:compiler": settings["//command_line_option:apple_compiler"],
        "//command_line_option:cpu": _cpu_string(
            cpu = cpu,
            platform_type = platform_type,
            settings = settings,
        ),
        "//command_line_option:crosstool_top": (
            settings["//command_line_option:apple_crosstool_top"]
        ),
        "//command_line_option:fission": [],
        "//command_line_option:grte_top": settings["//command_line_option:apple_grte_top"],
        "//command_line_option:ios_minimum_os": _min_os_version_or_none(
            minimum_os_version = minimum_os_version,
            platform = "ios",
            platform_type = platform_type,
        ),
        "//command_line_option:macos_minimum_os": _min_os_version_or_none(
            minimum_os_version = minimum_os_version,
            platform = "macos",
            platform_type = platform_type,
        ),
        "//command_line_option:tvos_minimum_os": _min_os_version_or_none(
            minimum_os_version = minimum_os_version,
            platform = "tvos",
            platform_type = platform_type,
        ),
        "//command_line_option:watchos_minimum_os": _min_os_version_or_none(
            minimum_os_version = minimum_os_version,
            platform = "watchos",
            platform_type = platform_type,
        ),
    }

    if emit_swiftinterface:
        output_dictionary["@build_bazel_rules_swift//swift:emit_swiftinterface"] = True

    return output_dictionary

def _xcframework_split_attr_key(*, cpu, environment, platform_type):
    """Return the split attribute key for this target within the XCFramework given linker options.

     Args:
        cpu: The architecture of the target that was built. For example, `x86_64` or `arm64`.
        environment: The environment of the target that was built, which corresponds to the
            toolchain's target triple values as reported by `apple_support.link_multi_arch_binary`.
            for environment. Typically `device` or `simulator`.
        platform_type: The platform of the target that was built, which corresponds to the
            toolchain's target triple values as reported by `apple_support.link_multi_arch_binary`
            for platform. For example, `ios`, `macos`, `tvos` or `watchos`.

    Returns:
        A string representing the key for this target build found within the XCFramework with a
            format of <platform>_<arch>_<target_environment>, for example `darwin_arm64_device`.
    """
    return _cpu_string(
        cpu = cpu,
        platform_type = platform_type,
    ) + "_" + environment

def _resolved_cpu_for_cpu(*, cpu, environment):
    # TODO(b/180572694): Remove cpu redirection after supporting platforms based toolchain
    # resolution.
    if cpu == "arm64" and environment == "simulator":
        return "sim_arm64"
    return cpu

def _command_line_options_for_xcframework_platform(
        *,
        minimum_os_version,
        platform_attr,
        platform_type,
        settings,
        target_environments):
    """Generates a dictionary of command line options keyed by 1:2+ transition for this platform.

    Args:
        minimum_os_version: A string representing the minimum OS version specified for this
            platform, represented as a dotted version number (for example, `"9.0"`).
        platform_attr: The attribute for the apple platform specifying in dictionary form which
            architectures to build for given a target environment as the key for this platform.
        platform_type: The Apple platform for which the rule should build its targets (`"ios"`,
            `"macos"`, `"tvos"`, or `"watchos"`).
        settings: A dictionary whose set of keys is defined by the inputs parameter, typically from
            the settings argument found on the implementation function of the current Starlark
            transition.
        target_environments: A list of strings representing target environments supported by the
            platform. Possible strings include "device" and "simulator".

    Returns:
        A dictionary of keys for each <platform>_<arch>_<target_environment> found with a
            corresponding dictionary of `"//command_line_option"`s as each key's value.
    """
    output_dictionary = {}
    for target_environment in target_environments:
        if not platform_attr.get(target_environment):
            continue
        for cpu in platform_attr[target_environment]:
            resolved_cpu = _resolved_cpu_for_cpu(
                cpu = cpu,
                environment = target_environment,
            )
            found_cpu = {
                _xcframework_split_attr_key(
                    cpu = cpu,
                    environment = target_environment,
                    platform_type = platform_type,
                ): _command_line_options(
                    cpu = resolved_cpu,
                    emit_swiftinterface = True,
                    minimum_os_version = minimum_os_version,
                    platform_type = platform_type,
                    settings = settings,
                ),
            }
            output_dictionary = dicts.add(found_cpu, output_dictionary)

    return output_dictionary

def _apple_rule_base_transition_impl(settings, attr):
    """Rule transition for Apple rules."""
    return _command_line_options(
        minimum_os_version = attr.minimum_os_version,
        platform_type = attr.platform_type,
        settings = settings,
    )

# These flags are a mix of options defined in native Bazel from the following fragments:
# - https://github.com/bazelbuild/bazel/blob/master/src/main/java/com/google/devtools/build/lib/analysis/config/CoreOptions.java
# - https://github.com/bazelbuild/bazel/blob/master/src/main/java/com/google/devtools/build/lib/rules/apple/AppleCommandLineOptions.java
# - https://github.com/bazelbuild/bazel/blob/master/src/main/java/com/google/devtools/build/lib/rules/cpp/CppOptions.java
_apple_rule_common_transition_inputs = [
    "//command_line_option:apple_compiler",
    "//command_line_option:apple_crosstool_top",
    "//command_line_option:apple_grte_top",
]
_apple_rule_base_transition_inputs = _apple_rule_common_transition_inputs + [
    "//command_line_option:cpu",
    "//command_line_option:ios_multi_cpus",
    "//command_line_option:macos_cpus",
    "//command_line_option:tvos_cpus",
    "//command_line_option:watchos_cpus",
]
_apple_rule_base_transition_outputs = [
    "//command_line_option:apple configuration distinguisher",
    "//command_line_option:apple_platform_type",
    "//command_line_option:apple_split_cpu",
    "//command_line_option:compiler",
    "//command_line_option:cpu",
    "//command_line_option:crosstool_top",
    "//command_line_option:fission",
    "//command_line_option:grte_top",
    "//command_line_option:ios_minimum_os",
    "//command_line_option:macos_minimum_os",
    "//command_line_option:tvos_minimum_os",
    "//command_line_option:watchos_minimum_os",
]
_apple_universal_binary_rule_transition_outputs = _apple_rule_base_transition_outputs + [
    "//command_line_option:ios_multi_cpus",
    "//command_line_option:macos_cpus",
    "//command_line_option:tvos_cpus",
    "//command_line_option:watchos_cpus",
]

_apple_rule_base_transition = transition(
    implementation = _apple_rule_base_transition_impl,
    inputs = _apple_rule_base_transition_inputs,
    outputs = _apple_rule_base_transition_outputs,
)

def _apple_rule_arm64_as_arm64e_transition_impl(settings, attr):
    """Rule transition for Apple rules that map arm64 to arm64e."""
    key = "//command_line_option:macos_cpus"

    # These additional settings are sent to both the base implementation and the final transition.
    additional_settings = {key: [cpu if cpu != "arm64" else "arm64e" for cpu in settings[key]]}
    return dicts.add(
        _apple_rule_base_transition_impl(dicts.add(settings, additional_settings), attr),
        additional_settings,
    )

_apple_rule_arm64_as_arm64e_transition = transition(
    implementation = _apple_rule_arm64_as_arm64e_transition_impl,
    inputs = _apple_rule_base_transition_inputs,
    outputs = _apple_rule_base_transition_outputs + ["//command_line_option:macos_cpus"],
)

def _apple_universal_binary_rule_transition_impl(settings, attr):
    """Rule transition for `apple_universal_binary` supporting forced CPUs."""
    forced_cpus = attr.forced_cpus
    platform_type = attr.platform_type
    new_settings = dict(settings)

    # If forced CPUs were given, first we overwrite the existing CPU settings
    # for the target's platform type with those CPUs. We do this before applying
    # the base rule transition in case it wants to read that setting.
    if forced_cpus:
        new_settings[_platform_specific_cpu_setting_name(platform_type)] = forced_cpus

    # Next, apply the base transition and get its output settings.
    new_settings = _apple_rule_base_transition_impl(new_settings, attr)

    # The output settings from applying the base transition won't have the
    # platform-specific CPU flags, so we need to re-apply those before returning
    # our result. For the target's platform type, use the forced CPUs if they
    # were given or use the original value otherwise. For every other platform
    # type, re-propagate the original input.
    #
    # Note that even if we don't have `forced_cpus`, we must provide values for
    # all of the platform-specific CPU flags because they are declared outputs
    # of the transition; the build will fail at analysis time if any are
    # missing.
    for other_type, flag in _PLATFORM_TYPE_TO_CPU_FLAG.items():
        if forced_cpus and platform_type == other_type:
            new_settings[flag] = forced_cpus
        else:
            new_settings[flag] = settings[flag]

    return new_settings

_apple_universal_binary_rule_transition = transition(
    implementation = _apple_universal_binary_rule_transition_impl,
    inputs = _apple_rule_base_transition_inputs,
    outputs = _apple_universal_binary_rule_transition_outputs,
)

def _static_framework_transition_impl(_settings, _attr):
    """Attribute transition for static frameworks to enable swiftinterface generation."""
    return {
        "@build_bazel_rules_swift//swift:emit_swiftinterface": True,
    }

# This transition is used, for now, to enable swiftinterface generation on swift_library targets.
# Once apple_common.split_transition is migrated to Starlark, this transition should be merged into
# that one, being enabled by reading either a private attribute on the static framework rules, or
# some other mechanism, so that it is only enabled on static framework rules and not all Apple
# rules.
_static_framework_transition = transition(
    implementation = _static_framework_transition_impl,
    inputs = [],
    outputs = [
        "@build_bazel_rules_swift//swift:emit_swiftinterface",
    ],
)

def _xcframework_transition_impl(settings, attr):
    """Starlark 1:2+ transition for generation of multiple frameworks for the current target."""
    output_dictionary = {}

    for platform_type in ["ios", "tvos", "watchos", "macos"]:
        if not hasattr(attr, platform_type):
            continue
        target_environments = ["device"]
        if platform_type != "macos":
            target_environments.append("simulator")

        command_line_options = _command_line_options_for_xcframework_platform(
            minimum_os_version = attr.minimum_os_versions.get(platform_type),
            platform_attr = getattr(attr, platform_type),
            platform_type = platform_type,
            settings = settings,
            target_environments = target_environments,
        )
        output_dictionary = dicts.add(command_line_options, output_dictionary)
    return output_dictionary

_xcframework_transition = transition(
    implementation = _xcframework_transition_impl,
    inputs = _apple_rule_common_transition_inputs,
    outputs = _apple_rule_base_transition_outputs + [
        "@build_bazel_rules_swift//swift:emit_swiftinterface",
    ],
)

transition_support = struct(
    apple_rule_transition = _apple_rule_base_transition,
    apple_rule_arm64_as_arm64e_transition = _apple_rule_arm64_as_arm64e_transition,
    apple_universal_binary_rule_transition = _apple_universal_binary_rule_transition,
    static_framework_transition = _static_framework_transition,
    xcframework_split_attr_key = _xcframework_split_attr_key,
    xcframework_transition = _xcframework_transition,
)
