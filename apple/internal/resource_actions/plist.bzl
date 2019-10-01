# Copyright 2018 The Bazel Authors. All rights reserved.
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

"""Plist related actions."""

load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:bundling_support.bzl",
    "bundling_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/internal:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_support.bzl",
    "rule_support",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleVersionInfo",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

def plisttool_action(ctx, inputs, outputs, control_file, mnemonic = None):
    """Registers an action that invokes `plisttool`.

    This function is a low-level helper that simply invokes `plisttool` with the
    given arguments. It is intended to be called by other functions that register
    actions for more specific resources, like Info.plist files or entitlements.

    Args:
      ctx: The Skylark context.
      inputs: Any `File`s that should be treated as inputs to the underlying
          action.
      outputs: Any `File`s that should be treated as outputs of the underlying
          action.
      control_file: The `File` containing the control struct to be passed to
          plisttool.
      mnemonic: The mnemonic to display when the action executes. Defaults to
          None.
    """
    apple_support.run(
        ctx,
        inputs = inputs + [control_file],
        outputs = outputs,
        executable = ctx.executable._plisttool,
        arguments = [control_file.path],
        mnemonic = mnemonic,
    )

def compile_plist(ctx, input_file, output_file):
    """Creates an action that compiles plist and strings files.

    Args:
      ctx: The Skylark context.
      input_file: The property list file that should be converted.
      output_file: The file reference for the output plist.
    """
    if input_file.basename.endswith(".strings"):
        mnemonic = "CompileStrings"
    else:
        mnemonic = "CompilePlist"

    # This command will check whether the input file is non-empty, and then
    # execute the version of plutil that takes the file directly. If the file is
    # empty, it will echo an new line and then pipe it into plutil. We do this
    # to handle empty files as plutil doesn't handle them very well.
    plutil_command = "plutil -convert binary1 -o %s --" % output_file.path
    complete_command = ("if [[ -s {in_file} ]] ; then {plutil_command} {in_file} ; " +
                        "elif [[ -f {in_file} ]] ; then echo | {plutil_command} - ; " +
                        "else exit 1 ; " +
                        "fi").format(
        in_file = input_file.path,
        plutil_command = plutil_command,
    )
    apple_support.run_shell(
        ctx,
        inputs = [input_file],
        outputs = [output_file],
        command = complete_command,
        mnemonic = mnemonic,
    )

def merge_resource_infoplists(ctx, bundle_name, input_files, output_plist):
    """Merges a list of plist files for resource bundles with substitutions.

    Args:
      ctx: The target's rule context.
      bundle_name: The name of the bundle where the plist will be placed in.
      input_files: The list of plists to merge.
      output_plist: The file reference for the output plist.
    """
    product_name = paths.replace_extension(bundle_name, "")
    substitutions = {
        "BUNDLE_NAME": bundle_name,
        "PRODUCT_NAME": product_name,
        "TARGET_NAME": product_name,
    }

    target = '%s (while bundling under "%s")' % (bundle_name, str(ctx.label))

    control = struct(
        binary = True,
        output = output_plist.path,
        plists = [p.path for p in input_files],
        target = target,
        variable_substitutions = struct(**substitutions),
    )

    control_file = intermediates.file(
        ctx.actions,
        ctx.label.name,
        paths.join(bundle_name, "%s-control" % output_plist.basename),
    )
    ctx.actions.write(
        output = control_file,
        content = control.to_json(),
    )

    plisttool_action(
        ctx,
        inputs = input_files,
        outputs = [output_plist],
        control_file = control_file,
        mnemonic = "CompileInfoPlist",
    )

def merge_root_infoplists(
        ctx,
        input_plists,
        output_plist,
        output_pkginfo,
        bundle_id = None,
        child_plists = [],
        child_required_values = [],
        include_executable_name = True,
        version_keys_required = False):
    """Creates an action that merges Info.plists and converts them to binary.

    This action merges multiple plists by shelling out to plisttool, then
    compiles the final result into a single binary plist file.

    Args:
      ctx: The target's rule context.
      input_plists: The root plist files to merge.
      output_plist: The file reference for the merged output plist.
      output_pkginfo: The file reference for the PkgInfo file. Can be None if not
        required.
      bundle_id: The bundle identifier to set in the output plist.
      child_plists: A list of plists from child targets (such as extensions
          or Watch apps) whose bundle IDs and version strings should be
          validated against the compiled plist for consistency.
      child_required_values: A list of pairs containing a client target plist
          and the pairs to check. For more information on the second item in the
          pair, see plisttool's `child_plist_required_values`, as this is passed
          straight through to it.
      include_executable_name: If True, the executable name will be added to
          the plist in the `CFBundleExecutable` key. This is mainly intended for
          plists embedded in a command line tool which don't need this value.
      version_keys_required: If True, the merged Info.plist file must include
          entries for CFBundleShortVersionString and CFBundleVersion.
    """
    input_files = list(input_plists + child_plists)

    # plists and forced_plists are lists of plist representations that should be
    # merged into the final Info.plist. Values in plists will be validated to be
    # unique, while values in forced_plists are forced into the final Info.plist,
    # without validation. Each array can contain either a path to a plist file to
    # merge, or a struct that represents the values of the plist to merge.
    plists = [p.path for p in input_plists]
    forced_plists = []

    # plisttool options for merging the Info.plist file.
    info_plist_options = {}

    bundle_name = bundling_support.bundle_name_with_extension(ctx)
    product_name = paths.replace_extension(bundle_name, "")

    # Values for string replacement substitutions to perform in the merged
    # Info.plist
    substitutions = {
        "BUNDLE_NAME": bundle_name,
        "PRODUCT_NAME": product_name,
    }

    # The default in Xcode is for PRODUCT_NAME and TARGET_NAME to be the same.
    # Support TARGET_NAME for substitutions even though it might not be the
    # target name in the BUILD file.
    substitutions["TARGET_NAME"] = product_name

    # The generated Info.plists from Xcode's project templates use
    # DEVELOPMENT_LANGUAGE as the default variable substitution for
    # CFBundleDevelopmentRegion. We substitute this to `en` to support
    # Info.plists out of the box coming from Xcode.
    substitutions["DEVELOPMENT_LANGUAGE"] = "en"

    if include_executable_name:
        substitutions["EXECUTABLE_NAME"] = product_name
        forced_plists.append(struct(CFBundleExecutable = product_name))

    if bundle_id:
        substitutions["PRODUCT_BUNDLE_IDENTIFIER"] = bundle_id

        # Pass the bundle_id as a plist and not a force_plist, this way the
        # merging will validate that any existing value matches. Historically
        # mismatches between the input Info.plist and rules bundle_id have
        # been valid bugs, so this will still catch that.
        plists.append(struct(CFBundleIdentifier = bundle_id))

    if child_plists:
        info_plist_options["child_plists"] = struct(
            **{str(p.owner): p.path for p in child_plists}
        )

    if child_required_values:
        info_plist_options["child_plist_required_values"] = struct(
            **{str(p.owner): v for (p, v) in child_required_values}
        )

    if (hasattr(ctx.attr, "version") and
        ctx.attr.version and
        AppleBundleVersionInfo in ctx.attr.version):
        version_info = ctx.attr.version[AppleBundleVersionInfo]
        input_files.append(version_info.version_file)
        info_plist_options["version_file"] = version_info.version_file.path

    if version_keys_required:
        info_plist_options["version_keys_required"] = True

    # Keys to be forced into the Info.plist file.
    # b/67853874 - move this to the right platform specific rule(s).
    launch_storyboard = getattr(ctx.file, "launch_storyboard", None)
    if launch_storyboard:
        short_name = paths.split_extension(launch_storyboard.basename)[0]
        forced_plists.append(struct(UILaunchStoryboardName = short_name))

    # Add any UIDeviceFamily entry needed.
    families = platform_support.ui_device_family_plist_value(ctx)
    if families:
        forced_plists.append(struct(UIDeviceFamily = families))

    # Collect any values for special product types that we have to manually put
    # in (duplicating what Xcode apparently does under the hood).
    rule_descriptor = rule_support.rule_descriptor(ctx)
    if rule_descriptor.additional_infoplist_values:
        forced_plists.append(
            struct(**rule_descriptor.additional_infoplist_values),
        )

    if platform_support.platform_type(ctx) == apple_common.platform_type.macos:
        plist_key = "LSMinimumSystemVersion"
    else:
        plist_key = "MinimumOSVersion"

    input_files.append(ctx.file._environment_plist)
    platform, sdk_version = platform_support.platform_and_sdk_version(ctx)
    platform_with_version = platform.name_in_plist.lower() + str(sdk_version)
    forced_plists.extend([
        ctx.file._environment_plist.path,
        struct(
            CFBundleSupportedPlatforms = [platform.name_in_plist],
            DTPlatformName = platform.name_in_plist.lower(),
            DTSDKName = platform_with_version,
            **{plist_key: platform_support.minimum_os(ctx)}
        ),
    ])

    output_files = [output_plist]
    if output_pkginfo:
        info_plist_options["pkginfo"] = output_pkginfo.path
        output_files.append(output_pkginfo)

    control = struct(
        binary = rule_descriptor.binary_infoplist,
        forced_plists = forced_plists,
        info_plist_options = struct(**info_plist_options),
        output = output_plist.path,
        plists = plists,
        target = str(ctx.label),
        variable_substitutions = struct(**substitutions),
    )

    control_file = intermediates.file(
        ctx.actions,
        ctx.label.name,
        "%s-root-control" % output_plist.basename,
    )
    ctx.actions.write(
        output = control_file,
        content = control.to_json(),
    )

    plisttool_action(
        ctx,
        inputs = input_files,
        outputs = output_files,
        control_file = control_file,
        mnemonic = "CompileRootInfoPlist",
    )
