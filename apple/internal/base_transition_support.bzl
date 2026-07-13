# Copyright 2026 The Bazel Authors. All rights reserved.
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
Starlark transition helpers and base transitions for Apple rules.
"""

load(
    "@build_bazel_rules_apple//apple/build_settings:build_settings.bzl",
    "build_settings_labels",
)
load(
    "@build_bazel_rules_apple//apple/internal:secure_features_support.bzl",
    "secure_features_support",
)

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

_PLATFORM_TYPE_TO_CPUS_FLAG = {
    "ios": "//command_line_option:ios_multi_cpus",
    "macos": "//command_line_option:macos_cpus",
    "tvos": "//command_line_option:tvos_cpus",
    "visionos": "//command_line_option:visionos_cpus",
    "watchos": "//command_line_option:watchos_cpus",
}

_IOS_ARCH_TO_EARLIEST_WATCHOS = {
    "x86_64": "x86_64",
    "sim_arm64": "arm64",
    "arm64": "arm64_32",
    "arm64e": "arm64_32",
}

_IOS_ARCH_TO_64_BIT_WATCHOS = {
    "x86_64": "x86_64",
    "sim_arm64": "arm64",
    "arm64": "arm64_32",
    "arm64e": "arm64_32",
}

# Following map provides and ad-hoc platform mapping
_CPU_TO_PLATFORM = {
    "darwin_x86_64": "//buildenv/platforms/apple:darwin_x86_64",
    "darwin_arm64": "//buildenv/platforms/apple:darwin_arm64",
    "darwin_arm64e": "//buildenv/platforms/apple:darwin_arm64e",
    "ios_x86_64": "//buildenv/platforms/apple/simulator:ios_x86_64",
    "ios_arm64": "//buildenv/platforms/apple:ios_arm64",
    "ios_sim_arm64": "//buildenv/platforms/apple/simulator:ios_arm64",
    "ios_arm64e": "//buildenv/platforms/apple:ios_arm64e",
    "tvos_sim_arm64": "//buildenv/platforms/apple/simulator:tvos_arm64",
    "tvos_sim_arm64e": "//buildenv/platforms/apple/simulator:tvos_arm64e",
    "tvos_arm64": "//buildenv/platforms/apple:tvos_arm64",
    "tvos_arm64e": "//buildenv/platforms/apple:tvos_arm64e",
    "tvos_x86_64": "//buildenv/platforms/apple/simulator:tvos_x86_64",
    "visionos_arm64": "//buildenv/platforms/apple:visionos_arm64",
    "visionos_arm64e": "//buildenv/platforms/apple:visionos_arm64e",
    "visionos_sim_arm64": "//buildenv/platforms/apple/simulator:visionos_arm64",
    "visionos_sim_arm64e": "//buildenv/platforms/apple/simulator:visionos_arm64e",
    "watchos_armv7k": "//buildenv/platforms/apple:watchos_armv7k",
    "watchos_arm64": "//buildenv/platforms/apple/simulator:watchos_arm64",
    "watchos_sim_arm64e": "//buildenv/platforms/apple/simulator:watchos_arm64e",
    "watchos_device_arm64": "//buildenv/platforms/apple:watchos_arm64",
    "watchos_device_arm64e": "//buildenv/platforms/apple:watchos_arm64e",
    "watchos_arm64_32": "//buildenv/platforms/apple:watchos_arm64_32",
    "watchos_x86_64": "//buildenv/platforms/apple/simulator:watchos_x86_64",
}

_IOS_PLATFORM_TO_ENV_ARCH = {
    Label("//buildenv/platforms/apple/simulator:ios_x86_64"): "x86_64",
    Label("//buildenv/platforms/apple:ios_arm64"): "arm64",
    Label("//buildenv/platforms/apple/simulator:ios_arm64"): "sim_arm64",
    Label("//buildenv/platforms/apple:ios_arm64e"): "arm64e",
}

_WATCHOS_PLATFORM_TO_ENV_ARCH = {
    Label("//buildenv/platforms/apple:watchos_armv7k"): "armv7k",
    Label("//buildenv/platforms/apple/simulator:watchos_arm64"): "arm64",
    Label("//buildenv/platforms/apple/simulator:watchos_arm64e"): "sim_arm64e",
    Label("//buildenv/platforms/apple:watchos_arm64"): "device_arm64",
    Label("//buildenv/platforms/apple:watchos_arm64e"): "device_arm64e",
    Label("//buildenv/platforms/apple:watchos_arm64_32"): "arm64_32",
    Label("//buildenv/platforms/apple/simulator:watchos_x86_64"): "x86_64",
}

_DEFAULT_ARCH = {
    "ios": "sim_arm64",
    "macos": "arm64",  # There is no Intel version of macOS 27.
    "tvos": "sim_arm64",
    "visionos": "sim_arm64",
    "watchos": "arm64",
}

def _default_arch(*, platform_type, minimum_os_version):
    if (platform_type == "macos" and
        apple_common.dotted_version(minimum_os_version) < apple_common.dotted_version("27.0")):
        # Fall back to the Intel default architecture if the minimum OS version is less than 27.0,
        # until we're ready to switch the default for all macOS builds to Apple Silicon (arm64).
        #
        return "x86_64"
    return _DEFAULT_ARCH[platform_type]

def _platform_specific_cpu_setting_name(platform_type):
    """Returns the name of a platform-specific CPU setting.

    Args:
        platform_type: A string denoting the platform type; `"ios"`, `"macos"`, `"tvos"`,
            "visionos", or `"watchos"`.

    Returns:
        The `"//command_line_option:..."` string that is used as the key for the CPUs flag of the
            given platform in settings dictionaries. This function never returns `None`; if the
            platform type is invalid, the build fails.
    """
    flag = _PLATFORM_TYPE_TO_CPUS_FLAG.get(platform_type, None)
    if not flag:
        fail("ERROR: Unknown platform type: {}".format(platform_type))
    return flag

def _watchos_environment_archs_from_ios(*, platform, minimum_os_version, settings):
    """Returns a set of watchOS environment archs based on incoming iOS archs.

    Args:
        platform: Value of the `--platforms` flag.
        minimum_os_version: A string coming directly from a rule's `minimum_os_version` attribute.
        settings: A dictionary whose set of keys is defined by the inputs parameter, typically from
            the settings argument found on the implementation function of the current Starlark
            transition.

    Returns:
        A list of watchOS environment archs if any were found from the iOS environment archs, or an
            empty list if none were found.
    """
    environment_archs = []
    ios_archs = settings[_platform_specific_cpu_setting_name("ios")]
    if not ios_archs:
        ios_arch = _IOS_PLATFORM_TO_ENV_ARCH.get(platform, None)
        if ios_arch:
            ios_archs = [ios_arch]
        elif (platform == Label("//buildenv/platforms/apple:darwin_arm64") or
              platform == Label("//buildenv/platforms/apple:darwin_arm64e")):
            ios_archs = ["sim_arm64"]
    if ios_archs:
        # Make sure to return a fallback compatible with the rule's assigned minimum OS.
        ios_to_watchos_arch_dict = _IOS_ARCH_TO_64_BIT_WATCHOS
        if apple_common.dotted_version(minimum_os_version) < apple_common.dotted_version("9.0"):
            ios_to_watchos_arch_dict = _IOS_ARCH_TO_EARLIEST_WATCHOS
        environment_archs = [
            ios_to_watchos_arch_dict[arch]
            for arch in ios_archs
            if ios_to_watchos_arch_dict.get(arch)
        ]
    return environment_archs

def _environment_archs(*, platform_type, minimum_os_version, settings):
    """Returns a full set of environment archs from the incoming command line options.

    Args:
        platform_type: A string denoting the platform type; `"ios"`, `"macos"`,
            `"tvos"`, `"visionos"`, or `"watchos"`.
        minimum_os_version: A string coming directly from a rule's `minimum_os_version` attribute.
        settings: A dictionary whose set of keys is defined by the inputs parameter, typically from
            the settings argument found on the implementation function of the current Starlark
            transition.

    Returns:
        A list of valid Apple environments with its architecture as a string (for example
        `sim_arm64` from `ios_sim_arm64`, or `arm64` from `ios_arm64`).
    """
    environment_archs = settings[_platform_specific_cpu_setting_name(platform_type)]
    if not environment_archs:
        platform = settings["//command_line_option:platforms"][0]
        if platform_type == "ios":
            # Get the iOS environment arch based on the --platforms flag.
            ios_arch = _IOS_PLATFORM_TO_ENV_ARCH.get(platform, None)
            if ios_arch:
                environment_archs = [ios_arch]
            elif (platform == Label("//buildenv/platforms/apple:darwin_arm64") or
                  platform == Label("//buildenv/platforms/apple:darwin_arm64e")):
                environment_archs = ["sim_arm64"]
        if platform_type == "watchos":
            # Use --platforms to determine the watchOS environment arch; often will be set by
            # a transition.
            watchos_arch = _WATCHOS_PLATFORM_TO_ENV_ARCH.get(platform, None)
            if watchos_arch:
                environment_archs = [watchos_arch]
            else:
                # If not found, generate watchOS archs via incoming iOS environment arch(s).
                environment_archs = _watchos_environment_archs_from_ios(
                    platform = platform,
                    minimum_os_version = minimum_os_version,
                    settings = settings,
                )
        if not environment_archs:
            environment_archs = [_default_arch(
                platform_type = platform_type,
                minimum_os_version = minimum_os_version,
            )]
    return environment_archs

def _cpu_string(*, environment_arch, minimum_os_version, platform_type, settings = {}):
    """Generates a <platform>_<environment?>_<arch> string for the current target based on args.

    Args:
        environment_arch: A valid Apple environment when applicable with its architecture as a
            string (for example `sim_arm64` from `ios_sim_arm64`, or `arm64` from `ios_arm64`), or
            None to infer a value from command line options passed through settings.
        minimum_os_version: A string representing the minimum OS version specified for this
            platform, represented as a dotted version number (for example, `"9.0"`).
        platform_type: The Apple platform for which the rule should build its targets (`"ios"`,
            `"macos"`, `"tvos"`, `"visionos"`, or `"watchos"`).
        settings: A dictionary whose set of keys is defined by the inputs parameter, typically from
            the settings argument found on the implementation function of the current Starlark
            transition. If not defined, defaults to an empty dictionary. Used as a fallback if the
            `environment_arch` argument is None.

    Returns:
        A <platform>_<arch> string defined for the current target.
    """
    if platform_type == "ios":
        if environment_arch:
            return "ios_{}".format(environment_arch)
        ios_cpus = settings["//command_line_option:ios_multi_cpus"]
        if ios_cpus:
            return "ios_{}".format(ios_cpus[0])
        env_arch = _IOS_PLATFORM_TO_ENV_ARCH.get(
            settings["//command_line_option:platforms"][0],
            None,
        )
        if env_arch:
            return "ios_{}".format(env_arch)
        return "ios_{}".format(_default_arch(
            platform_type = platform_type,
            minimum_os_version = minimum_os_version,
        ))
    if platform_type == "macos":
        if environment_arch:
            return "darwin_{}".format(environment_arch)
        macos_cpus = settings["//command_line_option:macos_cpus"]
        if macos_cpus:
            return "darwin_{}".format(macos_cpus[0])
        return "darwin_{}".format(_default_arch(
            platform_type = platform_type,
            minimum_os_version = minimum_os_version,
        ))
    if platform_type == "tvos":
        if environment_arch:
            return "tvos_{}".format(environment_arch)
        tvos_cpus = settings["//command_line_option:tvos_cpus"]
        if tvos_cpus:
            return "tvos_{}".format(tvos_cpus[0])
        return "tvos_{}".format(_default_arch(
            platform_type = platform_type,
            minimum_os_version = minimum_os_version,
        ))
    if platform_type == "visionos":
        if environment_arch:
            return "visionos_{}".format(environment_arch)
        visionos_cpus = settings["//command_line_option:visionos_cpus"]
        if visionos_cpus:
            return "visionos_{}".format(visionos_cpus[0])
        return "visionos_{}".format(_default_arch(
            platform_type = platform_type,
            minimum_os_version = minimum_os_version,
        ))
    if platform_type == "watchos":
        if environment_arch:
            return "watchos_{}".format(environment_arch)
        watchos_cpus = settings["//command_line_option:watchos_cpus"]
        if watchos_cpus:
            return "watchos_{}".format(watchos_cpus[0])
        return "watchos_{}".format(_default_arch(
            platform_type = platform_type,
            minimum_os_version = minimum_os_version,
        ))

    fail("ERROR: Unknown platform type: {}".format(platform_type))

def _min_os_version_or_none(*, minimum_os_version, platform, platform_type):
    if platform_type == platform:
        return minimum_os_version
    return None

def _is_arch_supported_for_target_tuple(*, environment_arch, minimum_os_version, platform_type):
    """Indicates if the environment_arch selected is supported for the given platform and min os.

    Args:
        environment_arch: A valid Apple environment when applicable with its architecture as a
            string (for example `sim_arm64` from `ios_sim_arm64`, or `arm64` from `ios_arm64`), or
            None to infer a value from command line options passed through settings.
        minimum_os_version: A string representing the minimum OS version specified for this
            platform, represented as a dotted version number (for example, `"9.0"`).
        platform_type: The Apple platform for which the rule should build its targets (`"ios"`,
            `"macos"`, `"tvos"`, `"visionos"`, or `"watchos"`).

    Returns:
        True if the architecture is supported for the given config, False otherwise.
    """

    dotted_minimum_os_version = apple_common.dotted_version(minimum_os_version)

    if (environment_arch == "armv7k" and platform_type == "watchos" and
        dotted_minimum_os_version >= apple_common.dotted_version("9.0")):
        return False

    return True

def _command_line_options(
        *,
        building_apple_bundle,
        environment_arch,
        features,
        force_bundle_outputs,
        minimum_os_version,
        platform_type,
        settings):
    """Generates a dictionary of command line options suitable for the current target.

    Args:
        building_apple_bundle: Indicates if the rule is building a bundle (rather than a
            standalone executable or library).
        environment_arch: A valid Apple environment when applicable with its architecture as a
            string (for example `sim_arm64` from `ios_sim_arm64`, or `arm64` from `ios_arm64`), or
            None to infer a value from command line options passed through settings.
        features: A list of features to enable for this target.
        force_bundle_outputs: Indicates if the rule should always emit tree artifact outputs, which
            are effectively bundles that aren't enclosed within a zip file (ipa).
        minimum_os_version: A string representing the minimum OS version specified for this
            platform, represented as a dotted version number (for example, `"9.0"`).
        platform_type: The Apple platform for which the rule should build its targets (`"ios"`,
            `"macos"`, `"tvos"`, `"visionos"`, or `"watchos"`).
        settings: A dictionary whose set of keys is defined by the inputs parameter, typically from
            the settings argument found on the implementation function of the current Starlark
            transition.

    Returns:
        A dictionary of `"//command_line_option"`s defined for the current target.
    """
    cpu = _cpu_string(
        environment_arch = environment_arch,
        minimum_os_version = minimum_os_version,
        platform_type = platform_type,
        settings = settings,
    )
    return {
        build_settings_labels.building_apple_bundle: building_apple_bundle,
        build_settings_labels.use_tree_artifacts_outputs: force_bundle_outputs if force_bundle_outputs else settings[build_settings_labels.use_tree_artifacts_outputs],
        # apple_split_cpu is still needed for Bazel built-in objc_library transition logic and Apple
        # fragment APIs, and it's also required to keep Bazel from optimizing away splits when deps
        # are identical between platforms.
        "//command_line_option:apple_split_cpu": environment_arch if environment_arch else "",
        "//command_line_option:compiler": None,
        "//command_line_option:features": (
            secure_features_support.environment_arch_specific_features(
                environment_arch = environment_arch,
                features = features,
            )
        ),
        "//command_line_option:fission": [],
        "//command_line_option:grte_top": None,
        "//command_line_option:platforms": [_CPU_TO_PLATFORM[cpu]],
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
        "//command_line_option:minimum_os_version": minimum_os_version,
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

def _apple_rule_base_transition_impl(settings, attr):
    """Rule transition for Apple rules using Bazel CPUs and a valid Apple split transition."""
    minimum_os_version = attr.minimum_os_version
    platform_type = attr.platform_type
    building_apple_bundle = getattr(attr, "_building_apple_bundle", True)
    force_bundle_outputs = getattr(attr, "_force_bundle_outputs", False)
    requested_features = secure_features_support.crosstool_features_from_secure_features(
        features = settings["//command_line_option:features"],
        name = attr.name,
        secure_features = getattr(attr, "secure_features", None),
    )
    resolved_environment_archs = secure_features_support.environment_archs_from_secure_features(
        environment_archs = _environment_archs(
            platform_type = platform_type,
            minimum_os_version = minimum_os_version,
            settings = settings,
        ),
        require_pointer_authentication_attribute = (
            settings[build_settings_labels.require_pointer_authentication_attribute]
        ),
        secure_features = requested_features,
    )
    if not resolved_environment_archs:
        fail("""
ERROR: Target {target} requested to build for {platform_type}, but no architectures were \
requested for that platform.

Set of environment architectures found: {environment_archs}
""".format(
            target = str(attr.name),
            environment_archs = str(_environment_archs(
                platform_type = platform_type,
                minimum_os_version = minimum_os_version,
                settings = settings,
            )),
            platform_type = platform_type,
        ))

    # Rule-level transition always gets the first architecture, which needs to match exactly one of
    # the attribute level split transition's architectures in order to take advantage of caching.
    return _command_line_options(
        building_apple_bundle = building_apple_bundle,
        environment_arch = resolved_environment_archs[0],
        features = requested_features,
        force_bundle_outputs = force_bundle_outputs,
        minimum_os_version = minimum_os_version,
        platform_type = platform_type,
        settings = settings,
    )

# These flags are a mix of options defined in native Bazel from the following fragments:
# - https://github.com/bazelbuild/bazel/blob/master/src/main/java/com/google/devtools/build/lib/analysis/config/CoreOptions.java
# - https://github.com/bazelbuild/bazel/blob/master/src/main/java/com/google/devtools/build/lib/rules/apple/AppleCommandLineOptions.java
# - https://github.com/bazelbuild/bazel/blob/master/src/main/java/com/google/devtools/build/lib/rules/cpp/CppOptions.java
_apple_rule_common_transition_inputs = [
    build_settings_labels.require_pointer_authentication_attribute,
    build_settings_labels.use_tree_artifacts_outputs,
    "//command_line_option:features",
]
_apple_rule_base_transition_inputs = _apple_rule_common_transition_inputs + [
    "//command_line_option:platforms",
    "//command_line_option:ios_multi_cpus",
    "//command_line_option:macos_cpus",
    "//command_line_option:tvos_cpus",
    "//command_line_option:visionos_cpus",
    "//command_line_option:watchos_cpus",
]
_apple_rule_base_transition_outputs = [
    build_settings_labels.building_apple_bundle,
    build_settings_labels.use_tree_artifacts_outputs,
    "//command_line_option:apple_split_cpu",
    "//command_line_option:compiler",
    "//command_line_option:features",
    "//command_line_option:fission",
    "//command_line_option:grte_top",
    "//command_line_option:ios_minimum_os",
    "//command_line_option:macos_minimum_os",
    "//command_line_option:minimum_os_version",
    "//command_line_option:platforms",
    "//command_line_option:tvos_minimum_os",
    "//command_line_option:watchos_minimum_os",
]

_apple_rule_base_transition = transition(
    implementation = _apple_rule_base_transition_impl,
    inputs = _apple_rule_base_transition_inputs,
    outputs = _apple_rule_base_transition_outputs,
)

def _apple_rule_bundle_output_transition_impl(_, __):
    """Rule transition for Apple rules that always sets the "tree artifact" bundle outputs."""
    return {
        build_settings_labels.use_tree_artifacts_outputs: True,
    }

_apple_rule_bundle_output_transition = transition(
    implementation = _apple_rule_bundle_output_transition_impl,
    inputs = [],
    outputs = [build_settings_labels.use_tree_artifacts_outputs],
)

base_transition_support = struct(
    apple_rule_base_transition = _apple_rule_base_transition,
    apple_rule_base_transition_impl = _apple_rule_base_transition_impl,
    apple_rule_base_transition_inputs = _apple_rule_base_transition_inputs,
    apple_rule_base_transition_outputs = _apple_rule_base_transition_outputs,
    apple_rule_bundle_output_transition = _apple_rule_bundle_output_transition,
    apple_rule_bundle_output_transition_impl = _apple_rule_bundle_output_transition_impl,
    apple_rule_common_transition_inputs = _apple_rule_common_transition_inputs,
    command_line_options = _command_line_options,
    cpu_string = _cpu_string,
    environment_archs = _environment_archs,
    is_arch_supported_for_target_tuple = _is_arch_supported_for_target_tuple,
    min_os_version_or_none = _min_os_version_or_none,
    platform_specific_cpu_setting_name = _platform_specific_cpu_setting_name,
)
