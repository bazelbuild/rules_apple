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

# Should be kept in sync with constants from AppleCommandLineOptions in Bazel, currently ignoring
# defaults that are dependent on the host arch.
_PLATFORM_TYPE_TO_DEFAULT_CPU = {
    "ios": "x86_64",
    "macos": "x86_64",
    "tvos": "x86_64",
    "watchos": "i386",
}

_32_BIT_APPLE_CPUS = [
    "i386",
    "armv7",
    "armv7s",
    "armv7k",
]

def _platform_specific_cpu_setting_name(platform_type):
    """Returns the name of a platform-specific CPU setting.

    Args:
        platform_type: A string denoting the platform type; `"ios"`, `"macos"`,
            `"tvos"`, or `"watchos"`.

    Returns:
        The `"//command_line_option:..."` string that is used as the key for the CPU flag of the
            given platform in settings dictionaries. This function never returns `None`; if the
            platform type is invalid, the build fails.
    """
    flag = _PLATFORM_TYPE_TO_CPU_FLAG.get(platform_type, None)
    if not flag:
        fail("ERROR: Unknown platform type: {}".format(platform_type))
    return flag

def _platform_specific_default_cpu(platform_type):
    """Returns the default architecture of a platform-specific CPU setting.

    Args:
        platform_type: A string denoting the platform type; `"ios"`, `"macos"`, `"tvos"`, or
            `"watchos"`.

    Returns:
        The architecture string that is considered to be the default architecture for the given
            platform type. This function never returns `None`; if the platform type is invalid, the
            build fails.
    """
    default_cpu = _PLATFORM_TYPE_TO_DEFAULT_CPU.get(platform_type, None)
    if not default_cpu:
        fail("ERROR: Unknown platform type: {}".format(platform_type))
    return default_cpu

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

def _is_cpu_supported_for_target_tuple(*, cpu, minimum_os_version, platform_type):
    """Indicates if the cpu selected is a supported arch for the given platform and min os.

    Args:
        cpu: A valid Apple cpu command line option as a string, or None to infer a value from
            command line options passed through settings.
        minimum_os_version: A string representing the minimum OS version specified for this
            platform, represented as a dotted version number (for example, `"9.0"`).
        platform_type: The Apple platform for which the rule should build its targets (`"ios"`,
            `"macos"`, `"tvos"`, or `"watchos"`).

    Returns:
        True if the cpu is supported for the given config, False otherwise.
    """

    dotted_minimum_os_version = apple_common.dotted_version(minimum_os_version)

    if cpu in _32_BIT_APPLE_CPUS:
        if (platform_type == "ios" and
            dotted_minimum_os_version >= apple_common.dotted_version("11.0")):
            return False
        if (platform_type == "watchos" and
            dotted_minimum_os_version >= apple_common.dotted_version("9.0")):
            return False

    return True

def _command_line_options(
        *,
        apple_platforms = [],
        cpu = None,
        emit_swiftinterface = False,
        minimum_os_version,
        platform_type,
        settings):
    """Generates a dictionary of command line options suitable for the current target.

    Args:
        apple_platforms: A list of labels referencing platforms if any should be set by the current
            rule. This will be applied directly to `apple_platforms` to allow for forwarding
            multiple platforms to rules evaluated after the transition is applied, and only the
            first element will be applied to `platforms` as that will be what is resolved by the
            underlying rule. Defaults to an empty list, which will signal to Bazel that platform
            mapping can take place as a fallback measure.
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
        "//command_line_option:apple_platforms": apple_platforms,
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
        "//command_line_option:grte_top": None,
        "//command_line_option:platforms": [apple_platforms[0]] if apple_platforms else [],
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

    output_dictionary["@build_bazel_rules_swift//swift:emit_swiftinterface"] = emit_swiftinterface

    return output_dictionary

def _xcframework_split_attr_key(*, cpu, environment, platform_type):
    """Return the split attribute key for this target within the XCFramework given linker options.

     Args:
        cpu: The architecture of the target that was built. For example, `x86_64` or `arm64`.
        environment: The environment of the target that was built, which corresponds to the
            toolchain's target triple values as reported by `apple_support.link_multi_arch_binary`
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

def _resolved_cpu_for_cpu(*, cpu, environment, platform_type):
    # TODO(b/180572694): Remove cpu redirection after supporting platforms based toolchain
    # resolution.
    # TODO: Remove `watchos` after https://github.com/bazelbuild/bazel/pull/16181
    if cpu == "arm64" and environment == "simulator" and platform_type != "watchos":
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
                platform_type = platform_type,
            )

            # TODO(b/237320075): Check that the archs requested are valid for the indicated platform
            # in _command_line_options_for_xcframework_platform via
            # _is_cpu_supported_for_target_tuple and fail the build if the result is an XCFramework
            # with no valid archs to build for the given platform_type and minimum OS.

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
        emit_swiftinterface = hasattr(attr, "_emitswiftinterface"),
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
]
_apple_rule_base_transition_inputs = _apple_rule_common_transition_inputs + [
    "//command_line_option:cpu",
    "//command_line_option:ios_multi_cpus",
    "//command_line_option:macos_cpus",
    "//command_line_option:tvos_cpus",
    "//command_line_option:watchos_cpus",
]
_apple_platform_transition_inputs = _apple_rule_base_transition_inputs + [
    "//command_line_option:apple_platforms",
    "//command_line_option:incompatible_enable_apple_toolchain_resolution",
    "//command_line_option:platforms",
]
_apple_rule_base_transition_outputs = [
    "//command_line_option:apple configuration distinguisher",
    "//command_line_option:apple_platform_type",
    "//command_line_option:apple_platforms",
    "//command_line_option:apple_split_cpu",
    "//command_line_option:compiler",
    "//command_line_option:cpu",
    "//command_line_option:crosstool_top",
    "//command_line_option:fission",
    "//command_line_option:grte_top",
    "//command_line_option:ios_minimum_os",
    "//command_line_option:macos_minimum_os",
    "//command_line_option:platforms",
    "//command_line_option:tvos_minimum_os",
    "//command_line_option:watchos_minimum_os",
    "@build_bazel_rules_swift//swift:emit_swiftinterface",
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

def _apple_platform_split_transition_impl(settings, attr):
    """Starlark 1:2+ transition for Apple platform-aware rules"""
    output_dictionary = {}

    invalid_requested_archs = []

    if settings["//command_line_option:incompatible_enable_apple_toolchain_resolution"]:
        platforms = (
            settings["//command_line_option:apple_platforms"] or
            settings["//command_line_option:platforms"]
        )
        # Currently there is no "default" platform for Apple-based platforms. If necessary, a
        # default platform could be generated for the rule's underlying platform_type, but for now
        # we work with the assumption that all users of the rules should set an appropriate set of
        # platforms when building Apple targets with `apple_platforms`.

        for index, platform in enumerate(platforms):
            # Create a new, reordered list so that the platform we need to resolve is always first,
            # and the other platforms will follow.
            apple_platforms = list(platforms)
            platform_to_resolve = apple_platforms.pop(index)
            apple_platforms.insert(0, platform_to_resolve)

            if str(platform) not in output_dictionary:
                output_dictionary[str(platform)] = _command_line_options(
                    apple_platforms = apple_platforms,
                    minimum_os_version = attr.minimum_os_version,
                    platform_type = attr.platform_type,
                    settings = settings,
                )

    else:
        platform_type = attr.platform_type
        cpus = settings[_platform_specific_cpu_setting_name(platform_type)]
        if not cpus:
            if platform_type == "ios":
                # Legacy exception to interpret the --cpu as an iOS arch.
                cpu_value = settings["//command_line_option:cpu"]
                if cpu_value.startswith("ios_"):
                    cpus = [cpu_value[4:]]
            if not cpus:
                # Set the default cpu for the given platform type.
                cpus = [_platform_specific_default_cpu(platform_type)]
        for cpu in cpus:
            found_cpu = _cpu_string(
                cpu = cpu,
                platform_type = platform_type,
                settings = settings,
            )
            if found_cpu in output_dictionary:
                continue

            minimum_os_version = attr.minimum_os_version
            cpu_is_supported = _is_cpu_supported_for_target_tuple(
                cpu = cpu,
                minimum_os_version = minimum_os_version,
                platform_type = platform_type,
            )
            if not cpu_is_supported:
                invalid_requested_arch = {
                    "cpu": cpu,
                    "minimum_os_version": minimum_os_version,
                    "platform_type": platform_type,
                }

                # NOTE: This logic to filter unsupported Apple CPUs would be good to implement on
                # the platforms side, but it is presently not possible as constraint resolution
                # cannot be performed within a transition.
                #
                # Propagate a warning to the user so that the dropped arch becomes actionable.
                # buildifier: disable=print
                print(
                    ("Warning: The architecture {cpu} is not valid for {platform_type} with a " +
                     "minimum OS of {minimum_os_version}. This architecture will be ignored in " +
                     "this build. This will be an error in a future version of the Apple rules. " +
                     "Please address this in your build invocation.").format(
                        **invalid_requested_arch
                    ),
                )
                invalid_requested_archs.append(invalid_requested_arch)
                continue

            output_dictionary[found_cpu] = _command_line_options(
                cpu = cpu,
                minimum_os_version = minimum_os_version,
                platform_type = platform_type,
                settings = settings,
            )

    if not bool(output_dictionary):
        error_msg = "Could not find any valid architectures to build for the current target.\n\n"
        if invalid_requested_archs:
            error_msg += "Requested the following invalid architectures:\n"
            for invalid_requested_arch in invalid_requested_archs:
                error_msg += " - {cpu} for {platform_type} {minimum_os_version}\n".format(
                    **invalid_requested_arch
                )
            error_msg += (
                "\nPlease check that the specified architectures are valid for the target's " +
                "specified minimum_os_version.\n"
            )
        fail(error_msg)

    return output_dictionary

_apple_platform_split_transition = transition(
    implementation = _apple_platform_split_transition_impl,
    inputs = _apple_platform_transition_inputs,
    outputs = _apple_rule_base_transition_outputs,
)

# TODO(b/230527536): Add support for Bazel platforms on ios/tvos_static_framework transition support method
def _apple_common_multi_arch_split_key(*, cpu, environment, platform_type):
    """Returns split key for the apple_common.multi_arch_split transition based on target triplet.

    See ApplePlatform.cpuStringForTarget for reference on how apple_common.multi_arch_split
    transition key is built.

     Args:
        cpu: The architecture of the target that was built. For example, `x86_64` or
            `arm64`.
        environment: The environment of the target that was built, which corresponds to the
            toolchain's target triple values as reported by `apple_support.link_multi_arch_*`
            for environment. Typically `device` or `simulator`.
        platform_type: The platform of the target that was built, which corresponds to the
            toolchain's target triple values as reported by `apple_common.link_multi_arch_*`
            for platform. For example, `ios`, `macos`, `tvos` or `watchos`.
    """
    cpu = _resolved_cpu_for_cpu(
        cpu = cpu,
        environment = environment,
        platform_type = platform_type,
    )
    return _cpu_string(
        cpu = cpu,
        platform_type = platform_type,
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
    outputs = _apple_rule_base_transition_outputs,
)

transition_support = struct(
    apple_platform_split_transition = _apple_platform_split_transition,
    apple_rule_transition = _apple_rule_base_transition,
    apple_rule_arm64_as_arm64e_transition = _apple_rule_arm64_as_arm64e_transition,
    apple_universal_binary_rule_transition = _apple_universal_binary_rule_transition,
    apple_common_multi_arch_split_key = _apple_common_multi_arch_split_key,
    xcframework_split_attr_key = _xcframework_split_attr_key,
    xcframework_transition = _xcframework_transition,
)
