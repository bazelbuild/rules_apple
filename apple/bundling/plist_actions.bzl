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

"""Actions that operate on plist files."""

load(
    "@build_bazel_rules_apple//apple/bundling:bundling_support.bzl",
    "bundling_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:file_support.bzl",
    "file_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:plist_support.bzl",
    "plist_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:product_support.bzl",
    "product_support",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleVersionInfo",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "apple_action",
    "merge_dictionaries",
    "remove_extension",
)
load(
    "@build_bazel_rules_apple//common:attrs.bzl",
    "attrs",
)
load(
    "@build_bazel_rules_apple//common:providers.bzl",
    "providers",
)


def _environment_plist_action(ctx):
  """Creates an action that extracts the Xcode environment plist.

  Args:
    ctx: The Skylark context.
  Returns:
    The plist file that contains the extracted environment.
  """
  platform, sdk_version = platform_support.platform_and_sdk_version(ctx)
  platform_with_version = platform.name_in_plist.lower() + str(sdk_version)

  environment_plist = ctx.new_file(ctx.label.name + "_environment.plist")
  platform_support.xcode_env_action(
      ctx,
      outputs=[environment_plist],
      executable=ctx.executable._environment_plist,
      arguments=[
          "--platform",
          platform_with_version,
          "--output",
          environment_plist.path,
      ],
  )

  return environment_plist


def _merge_infoplists(ctx,
                      path_prefix,
                      input_plists,
                      bundle_id=None,
                      executable_bundle=False,
                      exclude_executable_name=False,
                      child_plists=[]):
  """Creates an action that merges Info.plists and converts them to binary.

  This action merges multiple plists by shelling out to plisttool, then
  compiles the final result into a single binary plist file.

  This action also generates a PkgInfo file for the bundle as a side effect
  of processing the appropriate keys in the plist, if the `_needs_pkginfo`
  attribute on the target is True.

  Args:
    ctx: The Skylark context.
    path_prefix: A path prefix to apply in front of any intermediate files.
    input_plists: The plist files to merge.
    bundle_id: The bundle identifier to set in the output plist.
    executable_bundle: If True, this action is intended for an executable
        bundle's Info.plist, which means the development environment and
        platform info should be added to the plist, and a PkgInfo should
        (optionally) be created.
    exclude_executable_name: If True, the executable name will not be added to
        the plist in the `CFBundleExecutable` key. This is mainly intended for
        plists embedded in a command line tool.
    child_plists: A list of plists from child targets (such as extensions
        or Watch apps) whose bundle IDs and version strings should be
        validated against the compiled plist for consistency.
  Returns:
    A struct with two fields: `output_plist`, a File object containing the
    merged binary plist, and `pkginfo`, a File object containing the PkgInfo
    file (or None, if no file was generated).
  """
  output_plist = file_support.intermediate(
      ctx, "%{name}-Info-binary.plist", prefix=path_prefix)

  if executable_bundle and ctx.attr._needs_pkginfo:
    pkginfo = file_support.intermediate(
        ctx, "%{name}-PkgInfo", prefix=path_prefix)
  else:
    pkginfo = None

  forced_plists = []
  additional_plisttool_inputs = []

  launch_storyboard = attrs.get(ctx.file, "launch_storyboard")
  if launch_storyboard:
    short_name = remove_extension(launch_storyboard.basename)
    forced_plists.append(struct(UILaunchStoryboardName=short_name))

  info_plist_options = {
      "apply_default_version": True,
      "bundle_name": bundling_support.bundle_name_with_extension(ctx),
      "pkginfo": pkginfo.path if pkginfo else None,
  }

  version_info = providers.find_one(
      attrs.get(ctx.attr, "version"), AppleBundleVersionInfo)
  if version_info:
    additional_plisttool_inputs.append(version_info.version_file)
    info_plist_options["version_file"] = version_info.version_file.path

  if executable_bundle and bundle_id:
    info_plist_options["bundle_id"] = bundle_id

  # Resource bundles don't need the Xcode environment plist entries;
  # application and extension bundles do.
  if executable_bundle:
    if not exclude_executable_name:
      info_plist_options["executable"] = bundling_support.bundle_name(ctx)

    platform, sdk_version = platform_support.platform_and_sdk_version(ctx)
    platform_with_version = platform.name_in_plist.lower() + str(sdk_version)

    min_os = platform_support.minimum_os(ctx)

    environment_plist = _environment_plist_action(ctx)
    additional_plisttool_inputs.append(environment_plist)

    additional_infoplist_values = {}

    # Convert the device family names to integers used in the plist; the
    # family_plist_number function handles the special case for macOS, which
    # does not use UIDeviceFamily.
    families = []
    for f in platform_support.families(ctx):
      number = platform_support.family_plist_number(f)
      if number:
        families.append(number)
    if families:
      additional_infoplist_values["UIDeviceFamily"] = families

    # Collect any values for special product types that we have to manually put
    # in (duplicating what Xcode apparently does under the hood).
    product_type = product_support.product_type(ctx)
    product_type_descriptor = product_support.product_type_descriptor(
        product_type)
    if product_type_descriptor:
      additional_infoplist_values = merge_dictionaries(
          additional_infoplist_values,
          product_type_descriptor.additional_infoplist_values)

    forced_plists += [
        environment_plist.path,
        struct(
            CFBundleSupportedPlatforms=[platform.name_in_plist],
            DTPlatformName=platform.name_in_plist.lower(),
            DTSDKName=platform_with_version,
            MinimumOSVersion=min_os,
            **additional_infoplist_values
        ),
    ]

  child_plists_for_control = struct(
      **{str(p.owner): p.path for p in child_plists})
  info_plist_options["child_plists"] = child_plists_for_control

  control = struct(
      plists=[p.path for p in input_plists],
      forced_plists=forced_plists,
      output=output_plist.path,
      binary=True,
      info_plist_options=struct(**info_plist_options),
      target=str(ctx.label),
  )
  control_file = file_support.intermediate(
      ctx, "%{name}.plisttool-control", prefix=path_prefix)
  ctx.file_action(
      output=control_file,
      content=control.to_json()
  )

  outputs = [output_plist]
  if pkginfo:
    outputs.append(pkginfo)

  plist_support.plisttool_action(
      ctx,
      inputs=input_plists + child_plists + additional_plisttool_inputs,
      outputs=outputs,
      control_file=control_file,
      mnemonic="CompileInfoPlist",
  )

  return struct(output_plist=output_plist, pkginfo=pkginfo)


# Define the loadable module that lists the exported symbols in this file.
plist_actions = struct(
    merge_infoplists=_merge_infoplists,
)
