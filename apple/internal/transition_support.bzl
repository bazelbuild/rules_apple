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
        "//command_line_option:fission",
        "//command_line_option:grte_top",
        "//command_line_option:ios_minimum_os",
        "//command_line_option:macos_minimum_os",
        "//command_line_option:tvos_minimum_os",
        "//command_line_option:watchos_minimum_os",
    ],
)

transition_support = struct(
    apple_rule_transition = None,
)
