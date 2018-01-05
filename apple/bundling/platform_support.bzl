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
    "@build_bazel_rules_apple//apple:utils.bzl",
    "apple_action",
    "get_environment_supplier",
)
load(
    "@build_bazel_rules_apple//common:attrs.bzl",
    "attrs",
)


# Maps the strings passed in to the "families" attribute to the numerical
# representation in the UIDeviceFamily plist entry.
_DEVICE_FAMILY_VALUES = {
    "iphone": 1,
    "ipad": 2,
    "tv": 3,
    "watch": 4,
    # We want _family_plist_number to return None for the valid "mac" family
    # since macOS doesn't use the UIDeviceFamily Info.plist key, but we still
    # want to catch invalid families with a KeyError.
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
  return attrs.get(ctx.attr, "families", ctx.attr._allowed_families)


def _family_plist_number(family_name):
  """Returns the `UIDeviceFamily` integer for a device family.

  This function returns None for valid device families that do not use the
  `UIDeviceFamily` Info.plist key (currently, only `mac`).

  Args:
    family_name: The device family name, as given in the `families` attribute
        of an Apple bundle target.
  Returns:
    The integer to use in the `UIDeviceFamily` key of an Info.plist file, or
    None if the key should not be added to the Info.plist.
  """
  return _DEVICE_FAMILY_VALUES[family_name]


def _is_device_build(ctx):
  """Returns True if the target is being built for a device.

  Args:
    ctx: The Skylark context.
  Returns:
    True if this is a device build, or False if it is a simulator build.
  """
  platform, _ = _platform_and_sdk_version(ctx)
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
    min_os = str(ctx.attr._xcode_config[apple_common.XcodeVersionConfig]
                 .minimum_os_for_platform_type(_platform_type(ctx)))
  return min_os


def _platform_type(ctx):
  """Returns the platform type for the current target.

  Args:
    ctx: The Skylark context.
  Returns:
    The `PlatformType` for the current target, after being converted from its
    string attribute form.
  """
  platform_type_string = attrs.get(ctx.attr, "platform_type",
                                   default=attrs.private_fallback)
  return getattr(apple_common.platform_type, platform_type_string)


def _platform_and_sdk_version(ctx):
  """Returns the platform and SDK version for the current target.

  Args:
    ctx: The Skylark context.
  Returns:
    A tuple containing the Platform object for the target and the SDK version
    to build against for that platform.
  """
  apple = ctx.fragments.apple
  platform = apple.multi_arch_platform(_platform_type(ctx))
  sdk_version = (ctx.attr._xcode_config[apple_common.XcodeVersionConfig]
                 .sdk_version_for_platform(platform))

  return platform, sdk_version


def _xcode_env_action(ctx, **kwargs):
  """Executes a Darwin-only action with the necessary platform environment.

  This rule is intended to be used by actions that invoke scripts like
  actoolwrapper and ibtoolwrapper that need to pass the Xcode and target
  platform versions into the environment but don't need to be wrapped by
  xcrunwrapper because they already invoke it internally.

  Rules using this action must require the "apple" configuration fragment.

  Args:
    ctx: The Skylark context.
    **kwargs: Arguments to be passed into apple_action.
  """
  platform, _ = _platform_and_sdk_version(ctx)
  environment_supplier = get_environment_supplier()
  action_env = environment_supplier.target_apple_env(ctx, platform)
  action_env.update(environment_supplier.apple_host_system_env(ctx))

  kwargs["env"] = dict(kwargs.get("env", {}))
  kwargs["env"].update(action_env)

  apple_action(ctx, **kwargs)


# Define the loadable module that lists the exported symbols in this file.
platform_support = struct(
    families=_families,
    family_plist_number=_family_plist_number,
    is_device_build=_is_device_build,
    minimum_os=_minimum_os,
    platform_and_sdk_version=_platform_and_sdk_version,
    platform_type=_platform_type,
    xcode_env_action=_xcode_env_action,
)
