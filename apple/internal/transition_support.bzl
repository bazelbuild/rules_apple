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
            return "ios_{}".format(settings["//command_line_option:ios_multi_cpus"][0])
        if settings["//command_line_option:cpu"].startswith("ios_"):
            return settings["//command_line_option:cpu"]
        return "ios_x86_64"
    elif platform_type == "macos":
        return "darwin_{}".format(settings["//command_line_option:macos_cpus"][0])
    elif platform_type == "tvos":
        return "tvos_{}".format(settings["//command_line_option:tvos_cpus"][0])
    elif platform_type == "watchos":
        return "watchos_{}".format(settings["//command_line_option:watchos_cpus"][0])

    fail("ERROR: Unknown platform type: {}".format(platform_type))

def _apple_rule_transition_impl(settings, attr):
    """Rule transition for Apple rules."""
    attr.platform_type
    return {
        "//command_line_option:apple configuration distinguisher": "applebin_" + attr.platform_type,
        "//command_line_option:apple_platform_type": attr.platform_type,
        "//command_line_option:compiler": settings["//command_line_option:apple_compiler"],
        "//command_line_option:cpu": _cpu_string(attr.platform_type, settings),
        "//command_line_option:crosstool_top": (
            settings["//command_line_option:apple_crosstool_top"]
        ),
        "//command_line_option:fission": [],
        "//command_line_option:grte_top": settings["//command_line_option:apple_grte_top"],
    }

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
        "//command_line_option:compiler",
        "//command_line_option:cpu",
        "//command_line_option:crosstool_top",
        "//command_line_option:fission",
        "//command_line_option:grte_top",
    ],
)

transition_support = struct(
    apple_rule_transition = _apple_rule_transition,
)
