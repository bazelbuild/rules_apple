# Copyright 2022 The Bazel Authors. All rights reserved.
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

"""Support methods for handling CcToolchainInfo providers."""

# Apple cpu name -> (architecture, normalized os, environment). Used to
# recover the target platform for cc_toolchains built with rules_cc's
# rule-based toolchain configuration, whose generated CcToolchainConfigInfo
# hardcodes an empty target_system_name (see rules_cc
# cc/toolchains/impl/toolchain_config.bzl).
_APPLE_CPU_TRIPLETS = {
    "darwin_arm64": ("arm64", "macos", "device"),
    "darwin_arm64e": ("arm64e", "macos", "device"),
    "darwin_x86_64": ("x86_64", "macos", "device"),
    "ios_arm64": ("arm64", "ios", "device"),
    "ios_arm64e": ("arm64e", "ios", "device"),
    "ios_sim_arm64": ("arm64", "ios", "simulator"),
    "ios_x86_64": ("x86_64", "ios", "simulator"),
    "tvos_arm64": ("arm64", "tvos", "device"),
    "tvos_sim_arm64": ("arm64", "tvos", "simulator"),
    "tvos_x86_64": ("x86_64", "tvos", "simulator"),
    "visionos_arm64": ("arm64", "visionos", "device"),
    "visionos_sim_arm64": ("arm64", "visionos", "simulator"),
    "watchos_arm64": ("arm64", "watchos", "simulator"),
    "watchos_device_arm64": ("arm64", "watchos", "device"),
    "watchos_device_arm64e": ("arm64e", "watchos", "device"),
    "watchos_arm64_32": ("arm64_32", "watchos", "device"),
    "watchos_armv7k": ("armv7k", "watchos", "device"),
    "watchos_x86_64": ("x86_64", "watchos", "simulator"),
}

def _triplet_from_rule_based_config(cc_toolchain):
    """Recovers the Apple platform from a rule-based cc_toolchain's config label.

    rules_cc's rule-based toolchain configuration reports an empty
    `target_system_name`. The generated config target is named
    `_<toolchain name>_config`, so match the toolchain name's suffix against
    the conventional Apple cpu names to recover the platform.

    Args:
        cc_toolchain: CcToolchainInfo provider with no target triplet.
    Returns:
        A normalized Clang target triplet struct, or None if the config label
        does not end in a recognized Apple cpu name.
    """
    config_name = cc_toolchain.toolchain_id.split(":")[-1]
    toolchain_name = config_name.removeprefix("_").removesuffix("_config")
    for cpu in sorted(_APPLE_CPU_TRIPLETS, key = len, reverse = True):
        if toolchain_name == cpu or toolchain_name.endswith("_" + cpu):
            architecture, os, environment = _APPLE_CPU_TRIPLETS[cpu]
            return struct(
                architecture = architecture,
                vendor = "apple",
                os = os,
                environment = environment,
            )
    return None

def _get_apple_clang_triplet(cc_toolchain):
    """Parses and performs normalization on Clang target triplet string reference.

    The C++ ToolchainInfo provider `target_gnu_system_name` field references an LLVM target triple.
    This support method parses this target triplet and normalizes information for Apple targets.

    See: https://clang.llvm.org/docs/CrossCompilation.html#target-triple

    Args:
        cc_toolchain: CcToolchainInfo provider.
    Returns:
        A normalized Clang target triplet struct for Apple targets.
    """
    if "-" not in cc_toolchain.target_gnu_system_name:
        rule_based_triplet = _triplet_from_rule_based_config(cc_toolchain)
        if rule_based_triplet:
            return rule_based_triplet
        fail(("Cannot determine the Apple target triplet: cc_toolchain '{}' " +
              "has no target_system_name and its config label does not end " +
              "in a recognized Apple cpu name.").format(
            cc_toolchain.toolchain_id,
        ))

    components = cc_toolchain.target_gnu_system_name.split("-")
    raw_triplet = struct(
        architecture = components[0],
        vendor = components[1],
        os = components[2],
        environment = components[3] if len(components) > 3 else None,
    )

    if raw_triplet.vendor != "apple":
        return raw_triplet

    environment = "device" if (raw_triplet.environment == None) else "simulator"

    # strip version from Apple platforms
    os = raw_triplet.os
    for index in range(len(raw_triplet.os)):
        if raw_triplet.os[index].isdigit():
            os = raw_triplet.os[:index]
            break

    # normalize MacOS names
    if os in ("macos", "macosx", "darwin"):
        os = "macos"

    return struct(
        architecture = raw_triplet.architecture,
        vendor = raw_triplet.vendor,
        os = os,
        environment = environment,
    )

cc_toolchain_info_support = struct(
    get_apple_clang_triplet = _get_apple_clang_triplet,
)
