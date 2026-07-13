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

"""Starlark transition support for apple_universal_binary."""

load(
    "@build_bazel_rules_apple//apple/internal:base_transition_support.bzl",
    "base_transition_support",
)

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

_apple_universal_binary_forced_cpus_transition_outputs = [
    "//command_line_option:ios_multi_cpus",
    "//command_line_option:macos_cpus",
    "//command_line_option:tvos_cpus",
    "//command_line_option:visionos_cpus",
    "//command_line_option:watchos_cpus",
]

def _apple_universal_binary_forced_cpus_transition_impl(settings, attr):
    forced_cpus = attr.forced_cpus
    if not forced_cpus:
        return {}  # Keep existing for all flags

    platform_type = attr.platform_type

    target_flag = base_transition_support.platform_specific_cpu_setting_name(platform_type)

    new_settings = {}
    for flag in _apple_universal_binary_forced_cpus_transition_outputs:
        if flag == target_flag:
            new_settings[flag] = sorted(forced_cpus)
        else:
            new_settings[flag] = settings[flag]
    return new_settings

_apple_universal_binary_forced_cpus_transition = transition(
    implementation = _apple_universal_binary_forced_cpus_transition_impl,
    inputs = _apple_universal_binary_forced_cpus_transition_outputs,
    outputs = _apple_universal_binary_forced_cpus_transition_outputs,
)

apple_universal_binary_rule_transition = _apple_universal_binary_forced_cpus_transition.and_then(
    base_transition_support.apple_rule_base_transition,
)
