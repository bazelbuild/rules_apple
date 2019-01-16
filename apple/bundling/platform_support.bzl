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
      ctx: The Skylark context.

    Returns:
      The list of device families that apply to the target being built.
    """
    rule_descriptor = rule_support.rule_descriptor(ctx)
    return getattr(ctx.attr, "families", rule_descriptor.allowed_device_families)

def _ui_device_family_plist_value(ctx):
    """Returns the value to use for `UIDeviceFamily` in an info.plist.

    This function returns the array of value to use or None if there should be
    no plist entry (currently, only macOS doesn't use UIDeviceFamily).

    Args:
      ctx: The Skylark context.

    Returns:
      A list of integers to use for the `UIDeviceFamily` in an Info.plist
      or None if the key should not be added to the Info.plist.
    """
    families = []
    for f in _families(ctx):
        number = _DEVICE_FAMILY_VALUES[f]
        if number:
            families.append(number)
    if families:
        return families
    return None

def _is_device_build(ctx):
    """Returns True if the target is being built for a device.

    Args:
      ctx: The Skylark context.

    Returns:
      True if this is a device build, or False if it is a simulator build.
    """
    platform = _platform(ctx)
    return platform.is_device

def _minimum_os(ctx):
    """Returns the minimum OS version required for the current target.

    Args:
      ctx: The Skylark context.

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
      ctx: The Skylark context.

    Returns:
      The `PlatformType` for the current target, after being converted from its
      string attribute form.
    """
    platform_type_string = ctx.attr.platform_type
    return getattr(apple_common.platform_type, platform_type_string)

def _platform(ctx):
    """Returns the platform for the current target.

    Args:
      ctx: The Skylark context.

    Returns:
      The Platform object for the target.
    """
    apple = ctx.fragments.apple
    platform = apple.multi_arch_platform(_platform_type(ctx))
    return platform

def _platform_and_sdk_version(ctx):
    """Returns the platform and SDK version for the current target.

    Args:
      ctx: The Skylark context.

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
    platform_type = _platform_type,
    ui_device_family_plist_value = _ui_device_family_plist_value,
)
