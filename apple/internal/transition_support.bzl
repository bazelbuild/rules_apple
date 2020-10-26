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

def _cpu_string(platform_type, settings):
    """Generates a <platform>_<arch> string for the current target based on the given parameters."""
    if platform_type == "ios":
        ios_cpus = settings["//command_line_option:ios_multi_cpus"]
        if ios_cpus:
            return "ios_{}".format(ios_cpus[0])
        cpu_value = settings["//command_line_option:cpu"]
        if cpu_value.startswith("ios_"):
            return cpu_value
        return "ios_x86_64"
    if platform_type == "macos":
        macos_cpus = settings["//command_line_option:macos_cpus"]
        if macos_cpus:
            return "darwin_{}".format(macos_cpus[0])
        return "darwin_x86_64"
    if platform_type == "tvos":
        tvos_cpus = settings["//command_line_option:tvos_cpus"]
        if tvos_cpus:
            return "tvos_{}".format(tvos_cpus[0])
        return "tvos_x86_64"
    if platform_type == "watchos":
        watchos_cpus = settings["//command_line_option:watchos_cpus"]
        if watchos_cpus:
            return "watchos_{}".format(watchos_cpus[0])
        return "watchos_i386"

    fail("ERROR: Unknown platform type: {}".format(platform_type))

def _enable_apple_binary_native_protos(settings, platform_type):
    # NOTE(b/170729565): Even though the value in `settings` for
    # "//command_line_option:enable_apple_binary_native_protos" is a boolean
    # (True/False), if the transition result includes a boolean,
    # FunctionTransitionUtil.java will fail with:
    #   Invalid value type for option 'enable_apple_binary_native_protos'
    # instead one has to return a String and let it be converted.
    _platforms_to_force_starlark_protos = ["macos", "tvos", "watchos"]
    if platform_type in _platforms_to_force_starlark_protos:
        return "false"
    if settings["//command_line_option:enable_apple_binary_native_protos"]:
        return "true"
    return "false"

def _min_os_version_or_none(attr, platform):
    if attr.platform_type == platform:
        return attr.minimum_os_version
    return None

def _apple_rule_transition_impl(settings, attr):
    """Rule transition for Apple rules."""
    return {
        "//command_line_option:apple configuration distinguisher": "applebin_" + attr.platform_type,
        "//command_line_option:apple_platform_type": attr.platform_type,
        "//command_line_option:apple_split_cpu": "",
        "//command_line_option:compiler": settings["//command_line_option:apple_compiler"],
        "//command_line_option:cpu": _cpu_string(attr.platform_type, settings),
        "//command_line_option:crosstool_top": (
            settings["//command_line_option:apple_crosstool_top"]
        ),
        "//command_line_option:enable_apple_binary_native_protos": (
            _enable_apple_binary_native_protos(settings, attr.platform_type)
        ),
        "//command_line_option:fission": [],
        "//command_line_option:grte_top": settings["//command_line_option:apple_grte_top"],
        "//command_line_option:ios_minimum_os": _min_os_version_or_none(attr, "ios"),
        "//command_line_option:macos_minimum_os": _min_os_version_or_none(attr, "macos"),
        "//command_line_option:tvos_minimum_os": _min_os_version_or_none(attr, "tvos"),
        "//command_line_option:watchos_minimum_os": _min_os_version_or_none(attr, "watchos"),
    }

# These flags are a mix of options defined in native Bazel from the following fragments:
# - https://github.com/bazelbuild/bazel/blob/master/src/main/java/com/google/devtools/build/lib/analysis/config/CoreOptions.java
# - https://github.com/bazelbuild/bazel/blob/master/src/main/java/com/google/devtools/build/lib/rules/apple/AppleCommandLineOptions.java
# - https://github.com/bazelbuild/bazel/blob/master/src/main/java/com/google/devtools/build/lib/rules/cpp/CppOptions.java
_apple_rule_transition = transition(
    implementation = _apple_rule_transition_impl,
    inputs = [
        "//command_line_option:apple_compiler",
        "//command_line_option:apple_crosstool_top",
        "//command_line_option:apple_grte_top",
        "//command_line_option:cpu",
        "//command_line_option:enable_apple_binary_native_protos",
        "//command_line_option:ios_multi_cpus",
        "//command_line_option:macos_cpus",
        "//command_line_option:tvos_cpus",
        "//command_line_option:watchos_cpus",
    ],
    outputs = [
        "//command_line_option:apple configuration distinguisher",
        "//command_line_option:apple_platform_type",
        "//command_line_option:apple_split_cpu",
        "//command_line_option:compiler",
        "//command_line_option:cpu",
        "//command_line_option:crosstool_top",
        "//command_line_option:enable_apple_binary_native_protos",
        "//command_line_option:fission",
        "//command_line_option:grte_top",
        "//command_line_option:ios_minimum_os",
        "//command_line_option:macos_minimum_os",
        "//command_line_option:tvos_minimum_os",
        "//command_line_option:watchos_minimum_os",
    ],
)

def _static_framework_transition_impl(settings, attr):
    """Attribute transition for static frameworks to enable swiftinterface generation."""
    return {
        "//command_line_option:enable_apple_binary_native_protos": (
            _enable_apple_binary_native_protos(settings, attr.platform_type)
        ),
        "@build_bazel_rules_swift//swift:emit_swiftinterface": True,
    }

# This transition is used, for now, to enable swiftinterface generation on swift_library targets.
# Once apple_common.split_transition is migrated to Starlark, this transition should be merged into
# that one, being enabled by reading either a private attribute on the static framework rules, or
# some other mechanism, so that it is only enabled on static framework rules and not all Apple
# rules.
_static_framework_transition = transition(
    implementation = _static_framework_transition_impl,
    inputs = [
        "//command_line_option:enable_apple_binary_native_protos",
    ],
    outputs = [
        "//command_line_option:enable_apple_binary_native_protos",
        "@build_bazel_rules_swift//swift:emit_swiftinterface",
    ],
)

transition_support = struct(
    apple_rule_transition = _apple_rule_transition,
    static_framework_transition = _static_framework_transition,
)
