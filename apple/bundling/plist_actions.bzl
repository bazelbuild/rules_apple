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
    "@bazel_skylib//lib:paths.bzl",
    "paths"
)
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


def _infoplist_minimum_os_pair(ctx):
  """Returns a info.plist entry of the min OS version for the current target.

  Args:
    ctx: The Skylark context.

  Returns:
    A dictionary containing the key/value pair to use in the targets Info.plist
    to set the minimum OS version supported.
  """
  if platform_support.platform_type(ctx) == apple_common.platform_type.macos:
    plist_key = "LSMinimumSystemVersion"
  else:
    plist_key = "MinimumOSVersion"

  return {plist_key: platform_support.minimum_os(ctx)}


def _merge_infoplists(ctx,
                      path_prefix,
                      input_plists,
                      bundle_id=None,
                      child_plists=[],
                      child_required_values=[],
                      exclude_executable_name=False,
                      extract_from_ctxt=False,
                      include_xcode_env=False,
                      resource_bundle_target_data=None,
                      version_keys_required=False):
  """Creates an action that merges Info.plists and converts them to binary.

  This action merges multiple plists by shelling out to plisttool, then
  compiles the final result into a single binary plist file.

  Args:
    ctx: The Skylark context.
    path_prefix: A path prefix to apply in front of any intermediate files.
    input_plists: The plist files to merge.
    bundle_id: The bundle identifier to set in the output plist.
    child_plists: A list of plists from child targets (such as extensions
        or Watch apps) whose bundle IDs and version strings should be
        validated against the compiled plist for consistency.
    child_required_values: A list of pair containing a client target plist
        and the pairs to check. For more information on the second item in the
        pair, see plisttool's `child_plist_required_values`, as this is passed
        straight throught to it.
    exclude_executable_name: If True, the executable name will not be added to
        the plist in the `CFBundleExecutable` key. This is mainly intended for
        plists embedded in a command line tool.
    extract_from_ctxt: If True, the ctx will also be inspect for additional
        information values to be added into the final Info.plist. The ctxt
        will also be checked to see if a PkgInfo file should be created.
    include_xcode_env: If True, add the development environment and platform
        platform info should be added to the plist (just like Xcode does).
    resource_bundle_target_data: If the is for a resource bundle, the
        AppleResourceBundleTargetData of the target that defined it. Will be
        used to provide substitution values.
    version_keys_required: If True, the merged Info.plist file must include
        entries for CFBundleShortVersionString and CFBundleVersion.

  Returns:
    A struct with two fields: `output_plist`, a File object containing the
    merged binary plist, and `pkginfo`, a File object containing the PkgInfo
    file (or None, if no file was generated).
  """
  if exclude_executable_name and not extract_from_ctxt:
    fail('exclude_executable_name has no meaning without extract_from_ctxt.')
  if resource_bundle_target_data and extract_from_ctxt:
    fail("resource_bundle_target_data doesn't work with extract_from_ctxt.")

  outputs = []
  plists = [p.path for p in input_plists]
  forced_plists = []
  additional_plisttool_inputs = []
  pkginfo = None
  info_plist_options = {}
  substitutions = {}

  if version_keys_required:
    info_plist_options["version_keys_required"] = True

  if bundle_id:
    substitutions["PRODUCT_BUNDLE_IDENTIFIER"] = bundle_id
    # Pass the bundle_id as a plist and not a force_plist, this way the
    # merging will validate that any existing value matches. Historically
    # mismatches between the input Info.plist and rules bundle_id have
    # been valid bugs, so this will still catch that.
    plists.append(struct(CFBundleIdentifier=bundle_id))

  output_plist = file_support.intermediate(
      ctx, "%{name}-Info-binary.plist", prefix=path_prefix)
  outputs.append(output_plist)

  if child_plists:
    for_control = struct(
        **{str(p.owner): p.path for p in child_plists})
    info_plist_options["child_plists"] = for_control
  if child_required_values:
    for_control = struct(
        **{str(p.owner): v for (p, v) in child_required_values})
    info_plist_options["child_plist_required_values"] = for_control

  if resource_bundle_target_data:
    substitutions["PRODUCT_NAME"] = resource_bundle_target_data.product_name
    substitutions["BUNDLE_NAME"] = resource_bundle_target_data.bundle_name

  if extract_from_ctxt:
    # Extra things for info_plist_options

    name = bundling_support.bundle_name(ctx)
    substitutions["PRODUCT_NAME"] = name
    if not exclude_executable_name:
      substitutions["EXECUTABLE_NAME"] = name
      forced_plists.append(struct(CFBundleExecutable=name))

    if ctx.attr._needs_pkginfo:
      pkginfo = file_support.intermediate(
          ctx, "%{name}-PkgInfo", prefix=path_prefix)
      outputs.append(pkginfo)
      info_plist_options["pkginfo"] = pkginfo.path

    bundle_name = bundling_support.bundle_name_with_extension(ctx)
    substitutions["BUNDLE_NAME"] = bundle_name

    version_info = providers.find_one(
        attrs.get(ctx.attr, "version"), AppleBundleVersionInfo)
    if version_info:
      additional_plisttool_inputs.append(version_info.version_file)
      info_plist_options["version_file"] = version_info.version_file.path

    # Keys to be forced into the Info.plist file.

    # b/67853874 - move this to the right platform specific rule(s).
    launch_storyboard = attrs.get(ctx.file, "launch_storyboard")
    if launch_storyboard:
      short_name = paths.split_extension(launch_storyboard.basename)[0]
      forced_plists.append(struct(UILaunchStoryboardName=short_name))

    # Add any UIDeviceFamily entry needed.
    families = platform_support.ui_device_family_plist_value(ctx)
    if families:
      forced_plists.append(struct(UIDeviceFamily=families))

    # Collect any values for special product types that we have to manually put
    # in (duplicating what Xcode apparently does under the hood).
    product_type = product_support.product_type(ctx)
    product_type_descriptor = product_support.product_type_descriptor(
        product_type)
    if product_type_descriptor:
      if product_type_descriptor.additional_infoplist_values:
        forced_plists.append(
            struct(**product_type_descriptor.additional_infoplist_values)
        )

  if include_xcode_env:
    environment_plist = _environment_plist_action(ctx)
    additional_plisttool_inputs.append(environment_plist)

    platform, sdk_version = platform_support.platform_and_sdk_version(ctx)
    platform_with_version = platform.name_in_plist.lower() + str(sdk_version)
    min_os_pair = _infoplist_minimum_os_pair(ctx)

    forced_plists += [
        environment_plist.path,
        struct(
            CFBundleSupportedPlatforms=[platform.name_in_plist],
            DTPlatformName=platform.name_in_plist.lower(),
            DTSDKName=platform_with_version,
            **min_os_pair
        ),
    ]

  # The default in Xcode is for PRODUCT_NAME and TARGET_NAME to be the same.
  # Support TARGET_NAME for substitutions even though it might not be the
  # target name in the BUILD file.
  product_name = substitutions.get("PRODUCT_NAME")
  if product_name:
    substitutions["TARGET_NAME"] = product_name

  # Tweak what is passed for 'target' to provide more more comment messages if
  # something does go wrong.
  if resource_bundle_target_data:
    target = '%s (while bundling under "%s")' % (
        str(resource_bundle_target_data.label), str(ctx.label))
  else:
    target = str(ctx.label)

  control = struct(
      plists=plists,
      forced_plists=forced_plists,
      output=output_plist.path,
      binary=True,
      info_plist_options=struct(**info_plist_options),
      variable_substitutions=struct(**substitutions),
      target=target,
  )
  control_file = file_support.intermediate(
      ctx, "%{name}.plisttool-control", prefix=path_prefix)
  ctx.file_action(
      output=control_file,
      content=control.to_json()
  )

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
