# Copyright 2017 The Bazel Authors. All rights reserved.
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

"""Support functions for working with Apple platforms and device families."""

load("@build_bazel_rules_apple//apple/internal:providers.bzl", "new_appleplatforminfo")

visibility([
    "//apple/...",
    "//test/...",
])

# Maps the strings passed in to the "families" attribute to the numerical
# representation in the UIDeviceFamily plist entry.
# @unsorted-dict-items
_DEVICE_FAMILY_VALUES = {
    "iphone": 1,
    "ipad": 2,
    "tv": 3,
    "watch": 4,
    "reality": 7,
    # We want _ui_device_family_plist_value to find None for the valid "mac"
    # family since macOS doesn't use the UIDeviceFamily Info.plist key, but we
    # still want to catch invalid families with a KeyError.
    "mac": None,
}

def _ui_device_family_plist_value(*, platform_prerequisites):
    """Returns the value to use for `UIDeviceFamily` in an info.plist.

    This function returns the array of value to use or None if there should be
    no plist entry (currently, only macOS doesn't use UIDeviceFamily).

    Args:
      platform_prerequisites: The platform prerequisites.

    Returns:
      A list of integers to use for the `UIDeviceFamily` in an Info.plist
      or None if the key should not be added to the Info.plist.
    """
    family_ids = []
    families = platform_prerequisites.device_families

    for f in families:
        number = _DEVICE_FAMILY_VALUES.get(f, -1)
        if number == -1:
            fail("Unknown family value:`{}`. Valid values are:{}".format(
                f,
                _DEVICE_FAMILY_VALUES.keys(),
            ))
        elif number:
            family_ids.append(number)

    if family_ids:
        return family_ids
    return None

def _get_apple_common_platform(*, apple_platform_info):
    """Returns an apple_common.platform given the contents of an ApplePlatformInfo provider"""
    if apple_platform_info.target_os == "ios":
        if apple_platform_info.target_environment == "device":
            return apple_common.platform.ios_device
        elif apple_platform_info.target_environment == "simulator":
            return apple_common.platform.ios_simulator
    elif apple_platform_info.target_os == "macos":
        return apple_common.platform.macos
    elif apple_platform_info.target_os == "tvos":
        if apple_platform_info.target_environment == "device":
            return apple_common.platform.tvos_device
        elif apple_platform_info.target_environment == "simulator":
            return apple_common.platform.tvos_simulator
    elif apple_platform_info.target_os == "visionos":
        if apple_platform_info.target_environment == "device":
            return apple_common.platform.visionos_device
        elif apple_platform_info.target_environment == "simulator":
            return apple_common.platform.visionos_simulator
    elif apple_platform_info.target_os == "watchos":
        if apple_platform_info.target_environment == "device":
            return apple_common.platform.watchos_device
        elif apple_platform_info.target_environment == "simulator":
            return apple_common.platform.watchos_simulator
    else:
        fail("Internal Error: Found unrecognized target os of " + apple_platform_info.target_os)
    fail(
        """
Internal Error: Found unrecognized target environment of {target_environment} for os {target_os}
""".format(
            target_environment = apple_platform_info.target_environment,
            target_os = apple_platform_info.target_os,
        ),
    )

def _target_arch_from_rule_ctx(ctx):
    """Returns a `String` representing the selected target architecture or cpu type."""
    arm64_constraint = ctx.attr._arm64_constraint[platform_common.ConstraintValueInfo]
    arm64e_constraint = ctx.attr._arm64e_constraint[platform_common.ConstraintValueInfo]
    arm64_32_constraint = ctx.attr._arm64_32_constraint[platform_common.ConstraintValueInfo]
    armv7k_constraint = ctx.attr._armv7k_constraint[platform_common.ConstraintValueInfo]
    x86_64_constraint = ctx.attr._x86_64_constraint[platform_common.ConstraintValueInfo]

    if ctx.target_platform_has_constraint(arm64_constraint):
        return "arm64"
    elif ctx.target_platform_has_constraint(arm64e_constraint):
        return "arm64e"
    elif ctx.target_platform_has_constraint(arm64_32_constraint):
        return "arm64_32"
    elif ctx.target_platform_has_constraint(armv7k_constraint):
        return "armv7k"
    elif ctx.target_platform_has_constraint(x86_64_constraint):
        return "x86_64"
    fail("ERROR: A valid Apple cpu constraint could not be found from the resolved toolchain.")

def _target_environment_from_rule_ctx(ctx):
    """Returns a `String` representing the selected environment (e.g. "device", "simulator")."""
    device_constraint = ctx.attr._apple_device_constraint[platform_common.ConstraintValueInfo]
    simulator_constraint = ctx.attr._apple_simulator_constraint[platform_common.ConstraintValueInfo]

    if ctx.target_platform_has_constraint(device_constraint):
        return "device"
    elif ctx.target_platform_has_constraint(simulator_constraint):
        return "simulator"
    fail("ERROR: A valid Apple environment (device, simulator) constraint could not be found from" +
         " the resolved toolchain.")

def _target_os_from_rule_ctx(ctx):
    """Returns a `String` representing the selected Apple OS."""
    ios_constraint = ctx.attr._ios_constraint[platform_common.ConstraintValueInfo]
    macos_constraint = ctx.attr._macos_constraint[platform_common.ConstraintValueInfo]
    tvos_constraint = ctx.attr._tvos_constraint[platform_common.ConstraintValueInfo]
    visionos_constraint = ctx.attr._visionos_constraint[platform_common.ConstraintValueInfo]
    watchos_constraint = ctx.attr._watchos_constraint[platform_common.ConstraintValueInfo]

    if ctx.target_platform_has_constraint(ios_constraint):
        return str(apple_common.platform_type.ios)
    elif ctx.target_platform_has_constraint(macos_constraint):
        return str(apple_common.platform_type.macos)
    elif ctx.target_platform_has_constraint(tvos_constraint):
        return str(apple_common.platform_type.tvos)
    elif ctx.target_platform_has_constraint(visionos_constraint):
        return str(apple_common.platform_type.visionos)
    elif ctx.target_platform_has_constraint(watchos_constraint):
        return str(apple_common.platform_type.watchos)
    fail("ERROR: A valid Apple platform constraint could not be found from the resolved toolchain.")

def _apple_platform_info_from_rule_ctx(ctx):
    """Returns an ApplePlatformInfo provider from a rule context, needed to resolve constraints."""
    return new_appleplatforminfo(
        target_arch = _target_arch_from_rule_ctx(ctx),
        target_environment = _target_environment_from_rule_ctx(ctx),
        target_os = _target_os_from_rule_ctx(ctx),
    )

def _platform_prerequisites(
        *,
        apple_fragment,
        apple_platform_info,
        build_settings,
        config_vars,
        cpp_fragment = None,
        device_families,
        explicit_minimum_os,
        objc_fragment = None,
        platform_type_string,
        uses_swift,
        xcode_version_config):
    """Returns a struct containing information on the platform being targeted.

    Args:
      apple_fragment: An Apple fragment (ctx.fragments.apple).
      apple_platform_info: An ApplePlatformInfo provider from the cc_toolchain_forwarder to
          determine the platform.
      build_settings: A struct with build settings info from AppleXplatToolsToolchainInfo.
      config_vars: A reference to configuration variables, typically from `ctx.var`.
      cpp_fragment: An cpp fragment (ctx.fragments.cpp), if it is present. Optional.
      device_families: The list of device families that apply to the target being built.
      explicit_minimum_os: A dotted version string indicating minimum OS desired.
      objc_fragment: An Objective-C fragment (ctx.fragments.objc), if it is present. Optional.
      platform_type_string: The platform type for the current target as a string.
      uses_swift: Boolean value to indicate if this target uses Swift.
      xcode_version_config: The `apple_common.XcodeVersionConfig` provider from the current context.

    Returns:
      A struct representing the collected platform information.
    """
    platform_type_attr = getattr(apple_common.platform_type, platform_type_string)
    platform = _get_apple_common_platform(apple_platform_info = apple_platform_info)
    sdk_version = xcode_version_config.sdk_version_for_platform(platform)

    return struct(
        apple_fragment = apple_fragment,
        build_settings = build_settings,
        config_vars = config_vars,
        cpp_fragment = cpp_fragment,
        device_families = device_families,
        minimum_os = explicit_minimum_os,
        platform = platform,
        platform_type = platform_type_attr,
        objc_fragment = objc_fragment,
        sdk_version = sdk_version,
        uses_swift = uses_swift,
        xcode_version_config = xcode_version_config,
    )

# Define the loadable module that lists the exported symbols in this file.
platform_support = struct(
    apple_platform_info_from_rule_ctx = _apple_platform_info_from_rule_ctx,
    platform_prerequisites = _platform_prerequisites,
    ui_device_family_plist_value = _ui_device_family_plist_value,
)
