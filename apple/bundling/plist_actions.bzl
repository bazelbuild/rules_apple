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

load("@build_bazel_rules_apple//apple/bundling:bundling_support.bzl",
     "bundling_support")
load("@build_bazel_rules_apple//apple/bundling:file_support.bzl", "file_support")
load("@build_bazel_rules_apple//apple/bundling:plist_support.bzl", "plist_support")
load("@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
     "platform_support")
load("@build_bazel_rules_apple//apple/bundling:product_support.bzl",
     "product_support")
load("@build_bazel_rules_apple//apple:utils.bzl", "apple_action")
load("@build_bazel_rules_apple//apple:utils.bzl", "remove_extension")


# Command string for "sed" that tries to extract the application version number
# from a larger string provided by the --embed_label flag. For example, from
# "foo_1.2.3_RC00" this would extract "1.2.3". This regex looks for versions of
# the format "x.y" or "x.y.z", which may be preceded and/or followed by other
# text, such as a project name or release candidate number. This command also
# preserves double quotes around the string, if any.
#
# This sed command is not terribly readable because sed requires parens and
# braces to be escaped and it does not support '?' or '+'. So, this command
# corresponds to the following regular expression:
#
# ("){0,1}       # Group 1: optional starting quotes
# (.*_){0,1}     # Group 2: anything (optional) before an underscore
# ([0-9][0-9]*(\.[0-9][0-9]*){1,2})  # Group 3: capture anything that looks
#                                    # like a version number of the form x.y
#                                    # or x.y.z (group 4 is for nesting only)
# (_[^"]*){0,1}  # Group 5: anything (optional) after an underscore
# ("){0,1}       # Group 6: optional closing quotes
#
# Then, the replacement extracts "\1\3\6" -- in other words, the version number
# component, surrounded by quotes if they were present in the original string.
_EXTRACT_VERSION_SED_COMMAND = (
    r's#\("\)\{0,1\}\(.*_\)\{0,1\}\([0-9][0-9]*\(\.[0-9][0-9]*\)' +
    r'\{1,2\}\)\(_[^"]*\)\{0,1\}\("\)\{0,1\}#\1\3\6#')


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


def _version_plist_action(ctx):
  """Creates an action that extracts a version number from the build info.

  The --embed_label flag can be used during the build to embed a string that
  will be inspected for something that looks like a version number (for
  example, "MyApp_1.2.3_prod"). If found, that string ("1.2.3") will be used
  as the CFBundleVersion and CFBundleShortVersionString for the bundle.

  If no version number was found in the label (or if the flag was not
  provided), the returned plist will be empty so that merging it becomes a
  no-op.

  Args:
    ctx: The Skylark context.
  Returns:
    The plist file that contains the extracted version information.
  """
  version_plist = ctx.new_file(ctx.label.name + "_version.plist")
  plist_path = version_plist.path

  info_path = ctx.info_file.path

  ctx.action(
      inputs=[ctx.info_file],
      outputs=[version_plist],
      command=(
          "set -e && " +
          "VERSION=\"$(grep \"^BUILD_EMBED_LABEL\" " + info_path + " | " +
          "cut -d\" \" -f2- | " +
          "sed -e '" + _EXTRACT_VERSION_SED_COMMAND + "' | " +
          "sed -e \"s#\\\"#\\\\\\\"#g\")\" && " +
          "cat >" + plist_path + " <<EOF\n" +
          "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
          "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" " +
          "\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n" +
          "<plist version=\"1.0\">\n" +
          "<dict>\n" +
          "EOF\n" +
          "if [[ -n \"$VERSION\" ]]; then\n" +
          "  for KEY in CFBundleVersion CFBundleShortVersionString; do\n" +
          "    echo \"  <key>$KEY</key>\" >> " + plist_path + "\n" +
          "    echo \"  <string>$VERSION</string>\" >> " + plist_path + "\n" +
          "  done\n" +
          "fi\n" +
          "cat >>" + plist_path + " <<EOF\n" +
          "</dict>\n" +
          "</plist>\n" +
          "EOF\n"
      ),
      mnemonic="VersionPlist",
  )

  return version_plist


def _merge_infoplists(ctx,
                      path_prefix,
                      input_plists,
                      bundle_id=None,
                      executable_bundle=False,
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

  if hasattr(ctx.file, "launch_storyboard") and ctx.file.launch_storyboard:
    launch_storyboard = ctx.file.launch_storyboard
    short_name = remove_extension(launch_storyboard.basename)
    forced_plists.append(struct(UILaunchStoryboardName=short_name))

  info_plist_options = {
      "bundle_name": bundling_support.bundle_name_with_extension(ctx),
      "pkginfo": pkginfo.path if pkginfo else None,
  }

  if executable_bundle and bundle_id:
    info_plist_options["bundle_id"] = bundle_id

  # Resource bundles don't need the Xcode environment plist entries;
  # application and extension bundles do.
  if executable_bundle:
    info_plist_options["executable"] = bundling_support.bundle_name(ctx)

    platform, sdk_version = platform_support.platform_and_sdk_version(ctx)
    platform_with_version = platform.name_in_plist.lower() + str(sdk_version)

    min_os = platform_support.minimum_os(ctx)

    environment_plist = _environment_plist_action(ctx)
    version_plist = _version_plist_action(ctx)
    additional_plisttool_inputs = [environment_plist, version_plist]

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
    product_info = product_support.product_type_info_for_target(ctx)
    if product_info and product_info.additional_infoplist_values:
      additional_infoplist_values = product_info.additional_infoplist_values

    forced_plists += [
        environment_plist.path,
        version_plist.path,
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
