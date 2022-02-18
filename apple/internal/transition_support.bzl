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

def _command_line_options_multi_cpu(
        *,
        cpus = None,
        emit_swiftinterface = False,
        minimum_os_version,
        platform_type,
        settings):
    """Generates a dictionary of command line options suitable for a natively linked target.

    Args:
        cpus: A valid series of Apple cpu command line options as a list of strings, or None to
            infer a value from `*_multi_cpus` command line options passed through settings.
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
        # Set apple_split_cpu to the empty string, treating it as though it is not manually set to
        # avoid issues setting `ios_x86_64` as the leading architecture before passing results to
        # the native multi arch split transition.
        #
        # Setting this flag overrides the *_multi_cpus options as far as the native linking is
        # concerned, and it can only handle a single architecture, so it is unnecessary for the
        # purposes of this split.
        "//command_line_option:apple_split_cpu": "",
        "//command_line_option:compiler": settings["//command_line_option:apple_compiler"],
        "//command_line_option:cpu": _cpu_string(
            cpu = cpus[0] if cpus else None,
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
        "//command_line_option:ios_multi_cpus": cpus if platform_type == "ios" else [],
        "//command_line_option:macos_minimum_os": _min_os_version_or_none(
            minimum_os_version = minimum_os_version,
            platform = "macos",
            platform_type = platform_type,
        ),
        "//command_line_option:macos_cpus": cpus if platform_type == "macos" else [],
        "//command_line_option:tvos_minimum_os": _min_os_version_or_none(
            minimum_os_version = minimum_os_version,
            platform = "tvos",
            platform_type = platform_type,
        ),
        "//command_line_option:tvos_cpus": cpus if platform_type == "tvos" else [],
        "//command_line_option:watchos_minimum_os": _min_os_version_or_none(
            minimum_os_version = minimum_os_version,
            platform = "watchos",
            platform_type = platform_type,
        ),
        "//command_line_option:watchos_cpus": cpus if platform_type == "watchos" else [],
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

def _command_line_options_for_platform(
        *,
        emit_swiftinterface = False,
        minimum_os_version,
        platform_attr,
        platform_type,
        settings,
        split_on_cpus,
        target_environments):
    """Generates a dictionary of command line options keyed by 1:2+ transition for this platform.

    Args:
        emit_swiftinterface: Wheither to emit swift interfaces for the given target. Defaults to
            `False`.
        minimum_os_version: A string representing the minimum OS version specified for this
            platform, represented as a dotted version number (for example, `"9.0"`).
        platform_attr: The attribute for the apple platform specifying in dictionary form which
            architectures to build for given a target environment as the key for this platform.
        platform_type: The Apple platform for which the rule should build its targets (`"ios"`,
            `"macos"`, `"tvos"`, or `"watchos"`).
        settings: A dictionary whose set of keys is defined by the inputs parameter, typically from
            the settings argument found on the implementation function of the current Starlark
            transition.
        split_on_cpus: Create a dictionary for each individual architecture for each platform and
            target environment, rather than create a dictionary for each platform and target
            environment which assumes that linking will be done in native code.
        target_environments: A list of strings representing target environments supported by the
            platform. Possible strings include "device" and "simulator".

    Returns:
        A dictionary of keys for each <platform>_<arch>_<target_environment> found with a
            corresponding dictionary of `"//command_line_option"`s as each key's value.
    """
    output_dictionary = {}
    for target_environment in target_environments:
        if platform_attr.get(target_environment):
            cpus = platform_attr[target_environment]
            if split_on_cpus:
                for cpu in cpus:
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
                            emit_swiftinterface = emit_swiftinterface,
                            minimum_os_version = minimum_os_version,
                            platform_type = platform_type,
                            settings = settings,
                        ),
                    }
                    output_dictionary = dicts.add(found_cpu, output_dictionary)
            else:
                resolved_cpus = []
                for cpu in cpus:
                    resolved_cpus.append(
                        _resolved_cpu_for_cpu(
                            cpu = cpu,
                            environment = target_environment,
                        ),
                    )
                found_cpus = {
                    _xcframework_split_attr_key(
                        cpu = "_".join(cpus),
                        environment = target_environment,
                        platform_type = platform_type,
                    ): _command_line_options_multi_cpu(
                        cpus = resolved_cpus,
                        emit_swiftinterface = emit_swiftinterface,
                        minimum_os_version = minimum_os_version,
                        platform_type = platform_type,
                        settings = settings,
                    ),
                }
                output_dictionary = dicts.add(found_cpus, output_dictionary)

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

def _output_dictionary_for_xcframework_transition(
        *,
        attr,
        emit_swiftinterface,
        settings,
        split_on_cpus):
    """Creates the appropriate output dictionary for each split of an XCFramework transition"""
    output_dictionary = {}
    if hasattr(attr, "macos"):
        command_line_options_for_platform = _command_line_options_for_platform(
            emit_swiftinterface = emit_swiftinterface,
            minimum_os_version = attr.minimum_os_versions.get("macos"),
            platform_attr = attr.macos,
            platform_type = "macos",
            settings = settings,
            split_on_cpus = split_on_cpus,
            target_environments = ["device"],
        )
        output_dictionary = dicts.add(command_line_options_for_platform, output_dictionary)
    for platform_type in ["ios", "tvos", "watchos"]:
        if hasattr(attr, platform_type):
            command_line_options_for_platform = _command_line_options_for_platform(
                emit_swiftinterface = emit_swiftinterface,
                minimum_os_version = attr.minimum_os_versions.get(platform_type),
                platform_attr = getattr(attr, platform_type),
                platform_type = platform_type,
                settings = settings,
                split_on_cpus = split_on_cpus,
                target_environments = ["device", "simulator"],
            )
            output_dictionary = dicts.add(command_line_options_for_platform, output_dictionary)
    return output_dictionary

def _xcframework_transition_impl(settings, attr):
    """Starlark 1:2+ transition for generation of multiple frameworks for the current target."""
    return _output_dictionary_for_xcframework_transition(
        attr = attr,
        emit_swiftinterface = True,
        settings = settings,
        split_on_cpus = True,
    )

_xcframework_transition = transition(
    implementation = _xcframework_transition_impl,
    inputs = _apple_rule_common_transition_inputs,
    outputs = _apple_rule_base_transition_outputs + [
        "@build_bazel_rules_swift//swift:emit_swiftinterface",
    ],
)

def _xcframework_native_lipo_transition_impl(settings, attr):
    """Starlark 1:2+ transition for native linking and lipoing of libraries for a given target."""
    return _output_dictionary_for_xcframework_transition(
        attr = attr,
        emit_swiftinterface = False,
        settings = settings,
        split_on_cpus = False,
    )

_xcframework_native_lipo_transition = transition(
    implementation = _xcframework_native_lipo_transition_impl,
    inputs = _apple_rule_common_transition_inputs,
    outputs = _apple_rule_base_transition_outputs + [
        "//command_line_option:ios_multi_cpus",
        "//command_line_option:macos_cpus",
        "//command_line_option:tvos_cpus",
        "//command_line_option:watchos_cpus",
    ],
)

transition_support = struct(
    apple_rule_transition = _apple_rule_base_transition,
    apple_rule_arm64_as_arm64e_transition = _apple_rule_arm64_as_arm64e_transition,
    static_framework_transition = _static_framework_transition,
    xcframework_split_attr_key = _xcframework_split_attr_key,
    xcframework_transition = _xcframework_transition,
    xcframework_native_lipo_transition = _xcframework_native_lipo_transition,
)
