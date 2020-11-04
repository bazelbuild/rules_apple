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

load(
    "@build_bazel_rules_apple//apple/internal:rule_support.bzl",
    "rule_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:swift_support.bzl",
    "swift_support",
)

# Maps the strings passed in to the "families" attribute to the numerical
# representation in the UIDeviceFamily plist entry.
# @unsorted-dict-items
_DEVICE_FAMILY_VALUES = {
    "iphone": 1,
    "ipad": 2,
    "tv": 3,
    "watch": 4,
    # We want _ui_device_family_plist_value to find None for the valid "mac"
    # family since macOS doesn't use the UIDeviceFamily Info.plist key, but we
    # still want to catch invalid families with a KeyError.
    "mac": None,
}

def _families(ctx):
    """Returns the device families that apply to the target being built.

    Some platforms, such as iOS, support multiple device families (iPhone and
    iPad) and provide a `families` attribute that lets the user specify which
    to use. Other platforms, like tvOS, only support one family, so they do not
    provide the public attribute and instead we implicitly get the supported
    families from the private attribute instead.

    Args:
      ctx: The Starlark context.

    Returns:
      The list of device families that apply to the target being built.
    """
    rule_descriptor = rule_support.rule_descriptor(ctx)
    return getattr(ctx.attr, "families", rule_descriptor.allowed_device_families)

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
        number = _DEVICE_FAMILY_VALUES[f]
        if number:
            family_ids.append(number)
    if family_ids:
        return family_ids
    return None

def _is_device_build(ctx):
    """Returns True if the target is being built for a device.

    Args:
      ctx: The Starlark context.

    Returns:
      True if this is a device build, or False if it is a simulator build.
    """
    platform = _platform(ctx)
    return platform.is_device

def _platform_prerequisites(
        *,
        apple_fragment,
        config_vars,
        device_families,
        explicit_minimum_os = None,
        objc_fragment = None,
        platform_type_string,
        uses_swift,
        xcode_path_wrapper,
        xcode_version_config):
    """Returns a struct containing information on the platform being targeted.

    Args:
      apple_fragment: An Apple fragment (ctx.fragments.apple).
      config_vars: A reference to configuration variables, typically from `ctx.var`.
      device_families: The list of device families that apply to the target being built.
      explicit_minimum_os: A dotted version string indicating minimum OS desired. Optional.
      objc_fragment: An Objective-C fragment (ctx.fragments.objc), if it is present. Optional.
      platform_type_string: The platform type for the current target as a string.
      uses_swift: Boolean value to indicate if this target uses Swift.
      xcode_path_wrapper: The Xcode path wrapper script. Can be none if and only we don't need to
          resolve __BAZEL_XCODE_SDKROOT__ and other placeholders in environment arguments.
      xcode_version_config: The `apple_common.XcodeVersionConfig` provider from the current context.

    Returns:
      A struct representing the collected platform information.
    """
    platform_type_attr = getattr(apple_common.platform_type, platform_type_string)
    platform = apple_fragment.multi_arch_platform(platform_type_attr)

    if explicit_minimum_os:
        minimum_os = explicit_minimum_os
    else:
        # TODO(b/38006810): Use the SDK version instead of the flag value as a soft default.
        minimum_os = str(xcode_version_config.minimum_os_for_platform_type(platform_type_attr))

    sdk_version = xcode_version_config.sdk_version_for_platform(platform)

    return struct(
        apple_fragment = apple_fragment,
        config_vars = config_vars,
        device_families = device_families,
        minimum_os = minimum_os,
        platform = platform,
        platform_type = platform_type_attr,
        objc_fragment = objc_fragment,
        sdk_version = sdk_version,
        uses_swift = uses_swift,
        xcode_path_wrapper = xcode_path_wrapper,
        xcode_version_config = xcode_version_config,
    )

def _platform_prerequisites_from_rule_ctx(ctx):
    """Returns a struct containing information on the platform being targeted from a rule context.

    Args:
      ctx: The Starlark context for a rule.

    Returns:
      A struct representing the default collected platform information for that rule context.
    """
    device_families = getattr(ctx.attr, "families", None)
    if not device_families:
        rule_descriptor = rule_support.rule_descriptor(ctx)
        device_families = rule_descriptor.allowed_device_families

    deps = getattr(ctx.attr, "deps", None)
    uses_swift = swift_support.uses_swift(deps) if deps else False

    return _platform_prerequisites(
        apple_fragment = ctx.fragments.apple,
        config_vars = ctx.var,
        device_families = device_families,
        explicit_minimum_os = ctx.attr.minimum_os_version,
        objc_fragment = ctx.fragments.objc,
        platform_type_string = ctx.attr.platform_type,
        uses_swift = uses_swift,
        xcode_path_wrapper = ctx.executable._xcode_path_wrapper,
        xcode_version_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
    )

def _minimum_os(ctx):
    """Returns the minimum OS version required for the current target.

    Args:
      ctx: The Starlark context.

    Returns:
      A string containing the dotted minimum OS version.
    """
    min_os = ctx.attr.minimum_os_version
    if not min_os:
        # TODO(b/38006810): Use the SDK version instead of the flag value as a soft
        # default.
        min_os = str(ctx.attr._xcode_config[apple_common.XcodeVersionConfig].minimum_os_for_platform_type(_platform_type(ctx)))
    return min_os

def _platform_type(ctx):
    """Returns the platform type for the current target.

    Args:
      ctx: The Starlark context.

    Returns:
      The `PlatformType` for the current target, after being converted from its
      string attribute form.
    """
    platform_type_string = ctx.attr.platform_type
    return getattr(apple_common.platform_type, platform_type_string)

def _platform(ctx):
    """Returns the platform for the current target.

    Args:
      ctx: The Starlark context.

    Returns:
      The Platform object for the target.
    """
    apple = ctx.fragments.apple
    platform = apple.multi_arch_platform(_platform_type(ctx))
    return platform

def _platform_and_sdk_version(ctx):
    """Returns the platform and SDK version for the current target.

    Args:
      ctx: The Starlark context.

    Returns:
      A tuple containing the Platform object for the target and the SDK version
      to build against for that platform.
    """
    platform = _platform(ctx)
    sdk_version = (ctx.attr._xcode_config[apple_common.XcodeVersionConfig].sdk_version_for_platform(platform))

    return platform, sdk_version

# Define the loadable module that lists the exported symbols in this file.
platform_support = struct(
    families = _families,
    is_device_build = _is_device_build,
    minimum_os = _minimum_os,
    platform = _platform,
    platform_and_sdk_version = _platform_and_sdk_version,
    platform_prerequisites = _platform_prerequisites,
    platform_prerequisites_from_rule_ctx = _platform_prerequisites_from_rule_ctx,
    platform_type = _platform_type,
    ui_device_family_plist_value = _ui_device_family_plist_value,
)
