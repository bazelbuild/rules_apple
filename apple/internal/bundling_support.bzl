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

"""Low-level bundling name helpers."""

load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "AppleBaseBundleIdInfo",
    "AppleSharedCapabilityInfo",
)

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

# Predeclared defaults for the suffix of a given bundle ID.
#
# These values are used internally for the rules that support the `bundle_id_suffix` attribute to
# set the desired behavior, allowing for complex scenarios like allowing users to set empty strings
# as the suffix without tripping over "falsey" values in Starlark, or sourcing the bundle_name
# attribute.
#
# * `bundle_name`: Source the default bundle ID suffix from the evaluated bundle name.
# * `no_suffix`: Derive the bundle ID entirely from the base bundle ID, omitting the suffix.
# * `watchos_app`: Predeclared string for watchOS applications. This suffix is required.
# * `watchos2_app_extension`: Predeclared string for watchOS 2 application extensions. This suffix
#   is required.
bundle_id_suffix_default = struct(
    bundle_name = "bundle_name",  # Predeclared string with invalid bundle ID characters.
    no_suffix = "_",  # Predeclared string with invalid bundle ID characters.
    watchos_app = "watchkitapp",
    watchos2_app_extension = "watchkitapp.watchkitextension",
)

def _bundle_full_name(
        *,
        custom_bundle_extension = None,
        custom_bundle_name = None,
        label_name,
        rule_descriptor):
    """Returns a tuple containing information on the bundle file name.

    Args:
      custom_bundle_extension: A custom bundle extension. If one is not provided, the default
          bundle extension from the `rule_descriptor` will be used instead. Optional.
      custom_bundle_name: A custom bundle name. If one is not provided, the name of the target as
          given by `label_name` will be used instead. Optional.
      label_name: The name of the target.
      rule_descriptor: The rule descriptor for the given rule.

    Returns:
      A tuple representing the default bundle file name and extension for that rule context.
    """
    bundle_name = custom_bundle_name
    if not bundle_name:
        bundle_name = label_name

    bundle_extension = custom_bundle_extension
    if bundle_extension:
        # When the *user* specifies the bundle extension in a public attribute, we
        # do *not* require them to include the leading dot, so we add it here.
        bundle_extension = "." + bundle_extension
    else:
        bundle_extension = rule_descriptor.bundle_extension

    return (bundle_name, bundle_extension)

def _preferred_bundle_suffix(*, bundle_id_suffix, bundle_name, suffix_default):
    """Returns the preferred bundle_id_suffix from all sources of truth.

    Args:
      bundle_id_suffix: String. A target-provided suffix for the base bundle ID.
      bundle_name: The preferred name of the bundle. Will be used to determine the suffix, if the
          suffix_default is `bundle_id_suffix_default.bundle_name`.
      suffix_default: String. A rule-specified string to indicate what the bundle ID suffix was on
          the rule attribute by default. This is to allow the user a full degree of customization
          depending on the value for bundle_id_suffix they wish to specify.

    Returns:
      A string representing the bundle ID suffix determined for the target that can be appended to
      the target's base bundle ID.
    """
    if suffix_default == bundle_id_suffix:
        if suffix_default == bundle_id_suffix_default.bundle_name:
            return bundle_name
        elif suffix_default == bundle_id_suffix_default.no_suffix:
            return ""
        else:
            return suffix_default
    else:
        return bundle_id_suffix

def _preferred_full_bundle_id(*, base_bundle_id, bundle_id_suffix, bundle_name, suffix_default):
    """Returns the full bundle ID from a known base_bundle_id and other source of truth.

    Args:
      base_bundle_id: The `apple_base_bundle_id` target to dictate the form that a given bundle
          rule's bundle ID prefix should take. Use this for rules that don't support capabilities
          or entitlements. Optional.
      bundle_id_suffix: String. A target-provided suffix for the base bundle ID.
      bundle_name: The preferred name of the bundle. Will be used to determine the suffix, if the
          suffix_default is `bundle_id_suffix_default.bundle_name`.
      suffix_default: String. A rule-specified string to indicate what the bundle ID suffix was on
          the rule attribute by default. This is to allow the user a full degree of customization
          depending on the value for bundle_id_suffix they wish to specify.

    Returns:
      A string representing the bundle ID determined for the target.
    """
    preferred_bundle_suffix = _preferred_bundle_suffix(
        bundle_id_suffix = bundle_id_suffix,
        bundle_name = bundle_name,
        suffix_default = suffix_default,
    )
    if preferred_bundle_suffix:
        return base_bundle_id + "." + preferred_bundle_suffix
    else:
        return base_bundle_id

def _base_bundle_id_from_shared_capabilities(shared_capabilities):
    """Returns the base_bundle_id found from a list of providers from apple_capability_set rules.

    Args:
      shared_capabilities: A list of shared `apple_capability_set` targets to represent the
          capabilities that a code sign aware Apple bundle rule output should have. Use this for
          rules that support capabilities and entitlements. Optional.

    Returns:
      A string representing the base bundle ID determined for the target.
    """
    base_bundle_id = ""
    for capability_set in shared_capabilities:
        capability_info = capability_set[AppleSharedCapabilityInfo]
        if capability_info.base_bundle_id:
            if not base_bundle_id:
                base_bundle_id = capability_info.base_bundle_id
            elif capability_info.base_bundle_id != base_bundle_id:
                fail("""
Error: Received conflicting base bundle IDs from more than one assigned Apple shared capability.

Found \"{conflicting_base}\" which does not match previously defined \"{base_bundle_id}\".

See https://github.com/bazelbuild/rules_apple/blob/master/doc/shared_capabilities.md for more information.
""".format(
                    base_bundle_id = base_bundle_id,
                    conflicting_base = capability_info.base_bundle_id,
                ))

    return base_bundle_id

def _bundle_full_id(
        *,
        base_bundle_id = None,
        bundle_id,
        bundle_id_suffix,
        bundle_name,
        suffix_default,
        shared_capabilities = None):
    """Returns the full bundle ID for a bundle rule output given all possible sources of truth.

    Args:
        base_bundle_id: The `apple_base_bundle_id` target to dictate the form that a given bundle
            rule's bundle ID prefix should take. Use this for rules that don't support capabilities
            or entitlements. Optional.
        bundle_id: String. The full bundle ID to configure for this target. This will be used if the
            target does not have a base_bundle_id or shared_capabilities set.
        bundle_id_suffix: String. A target-provided suffix for the base bundle ID.
        bundle_name: The preferred name of the bundle. Will be used to determine the suffix, if the
            suffix_default is `bundle_id_suffix_default.bundle_name`.
        suffix_default: String. A rule-specified string to indicate what the bundle ID suffix was on
            the rule attribute by default. This is to allow the user a full degree of customization
            depending on the value for bundle_id_suffix they wish to specify.
        shared_capabilities: A list of shared `apple_capability_set` targets to represent the
            capabilities that a code sign aware Apple bundle rule output should have. Use this for
            rules that support capabilities and entitlements. Optional.

    Returns:
        A string representing the full bundle ID that has been determined for the target.
    """
    if base_bundle_id and shared_capabilities:
        fail("""
Internal Error: base_bundle_id should not be provided with shared_capabilities. Please file an issue
on the Apple BUILD Rules.
""")

    if not base_bundle_id and not shared_capabilities:
        # If there's no base_bundle_id or shared_capabilities, we must rely on bundle_id.
        if bundle_id:
            return bundle_id

        fail("""
Error: There are no attributes set on this target that can be used to determine a bundle ID.

Need a `bundle_id` or a reference to an `apple_base_bundle_id` target coming from the rule or (when
applicable) exactly one of the `apple_capability_set` targets found within `shared_capabilities`.

See https://github.com/bazelbuild/rules_apple/blob/master/doc/shared_capabilities.md for more information.
""")

    if base_bundle_id:
        if bundle_id:
            fail("""
Error: Found a `bundle_id` provided with `base_bundle_id`. This is ambiguous.

Please remove one of the two from your rule definition.

See https://github.com/bazelbuild/rules_apple/blob/master/doc/shared_capabilities.md for more information.
""")

        return _preferred_full_bundle_id(
            base_bundle_id = base_bundle_id[AppleBaseBundleIdInfo].base_bundle_id,
            bundle_id_suffix = bundle_id_suffix,
            bundle_name = bundle_name,
            suffix_default = suffix_default,
        )

    capability_base_bundle_id = _base_bundle_id_from_shared_capabilities(shared_capabilities)

    if not capability_base_bundle_id:
        fail("""
Error: Expected to find a base_bundle_id from exactly one of the assigned shared_capabilities.
Found none.

See https://github.com/bazelbuild/rules_apple/blob/master/doc/shared_capabilities.md for more information.
""")

    if bundle_id:
        fail("""
Error: Found a `bundle_id` on the rule along with `shared_capabilities` defining a `base_bundle_id`.

This is ambiguous. Please remove the `bundle_id` from your rule definition, or reference
`shared_capabilities` without a `base_bundle_id`.

See https://github.com/bazelbuild/rules_apple/blob/master/doc/shared_capabilities.md for more information.
""")

    return _preferred_full_bundle_id(
        base_bundle_id = capability_base_bundle_id,
        bundle_id_suffix = bundle_id_suffix,
        bundle_name = bundle_name,
        suffix_default = suffix_default,
    )

def _ensure_asset_catalog_files_not_in_xcassets(
        *,
        extension,
        files,
        message = None):
    """Validates that a subset of asset catalog files are not within an xcassets directory.

    Args:
      extension: The extension that should be used for the this particular asset that should never
          be found within the xcassets directory.
      files: An iterable of files to use.
      message: A custom error message to use, the list of found files that were found in xcassets
          directories will be printed afterwards.
    """
    _ensure_path_format(
        files = files,
        allowed_path_fragments = [],
        denied_path_fragments = ["xcassets", extension],
        message = message,
    )

def _ensure_single_xcassets_type(
        *,
        extension,
        files,
        message = None):
    """Validates that asset catalog files are nested within an xcassets directory.

    Args:
      extension: The extension that should be used for the this particular asset within the xcassets
          directory.
      files: An iterable of files to use.
      message: A custom error message to use, the list of found files that
          didn't match will be printed afterwards.
    """
    if not message:
        message = ("Expected the xcassets directory to only contain files " +
                   "are in sub-directories with the extension %s") % extension
    _ensure_path_format(
        files = files,
        allowed_path_fragments = ["xcassets", extension],
        denied_path_fragments = [],
        message = message,
    )

def _generate_bundle_archive_action(
        *,
        actions,
        apple_xplat_toolchain_info,
        bundletool_inputs,
        control_file_name,
        control_merge_files = [],
        control_merge_zips = [],
        max_cumulative_uncompressed_size = None,
        mnemonic,
        output_archive,
        output_discriminator,
        progress_message,
        label_name,
        test_output_zip_crc32 = True,
        xplat_exec_group):
    """Generates an action that creates a archive for a bundle rule output.

    Args:
      actions: The actions provider from `ctx.actions`.
      apple_xplat_toolchain_info: An AppleXPlatToolsToolchainInfo provider.
      bundletool_inputs: A depset of files to pass to the bundletool.
      control_file_name: The name of the control file to generate.
      control_merge_files: A list of structs representing files that should be merged into the
          bundle. Each struct contains two fields: "src", the path of the file that should be merged
          into the bundle; and "dest", the path inside the bundle where the file should be placed.
          The destination path is relative to the bundle root.
      control_merge_zips: A list of structs representing ZIP archives whose contents should be
          merged into the bundle. Each struct contains two fields: "src", the path of the archive
          whose contents should be merged into the bundle; and "dest", the path inside the bundle
          where the ZIPs contents should be placed. The destination path is relative to the bundle
          root.
      label_name: Name of the target being built.
      max_cumulative_uncompressed_size: The maximum cumulative uncompressed size of the bundle in
          bytes. If "None", no limit will be enforced.
      mnemonic: A String. The mnemonic to use for the action.
      output_archive: A File referencing the output archive.
      output_discriminator: A string to differentiate between different target intermediate files
          or `None`.
      progress_message: A String. The progress message to use for the action.
      test_output_zip_crc32: A boolean. Whether to perform an extra validation pass on the output
          archive to ensure that all uncompressed files within in match the CRC32 checksums in the
          archive file (PKZIP validation).
      xplat_exec_group: A String. The exec_group for actions using the xplat toolchain.
    """
    force_python_bundletool = False
    if apple_xplat_toolchain_info.build_settings.force_python_bundletool:
        force_python_bundletool = True

    args = actions.args()
    if not force_python_bundletool:
        args.add("archive")

    control_file = intermediates.file(
        actions = actions,
        target_name = label_name,
        output_discriminator = output_discriminator,
        file_name = control_file_name,
    )
    args.add(control_file.path)

    additional_control_options = {}
    if force_python_bundletool:
        executable = apple_xplat_toolchain_info.bundletool
        if max_cumulative_uncompressed_size and max_cumulative_uncompressed_size > 0:
            additional_control_options["enable_zip64_support"] = False
        else:
            additional_control_options["enable_zip64_support"] = True
    else:
        executable = apple_xplat_toolchain_info.bundletool_swift
        if max_cumulative_uncompressed_size:
            additional_control_options["max_cumulative_uncompressed_size"] = (
                max_cumulative_uncompressed_size
            )
        additional_control_options["test_output_zip_crc32"] = test_output_zip_crc32

    control = struct(
        bundle_merge_files = control_merge_files,
        bundle_merge_zips = control_merge_zips,
        output = output_archive.path,
        **additional_control_options
    )
    actions.write(
        output = control_file,
        content = json.encode(control),
    )

    bundletool_final_inputs = depset([control_file], transitive = [bundletool_inputs])
    actions.run(
        arguments = [args],
        executable = executable.files_to_run,
        exec_group = xplat_exec_group,
        inputs = bundletool_final_inputs,
        mnemonic = mnemonic,
        outputs = [output_archive],
        progress_message = progress_message,
    )

def _generate_tree_artifact_bundle_action(
        *,
        actions,
        additional_bundling_tools,
        apple_fragment,
        apple_mac_toolchain_info,
        bundletool_control_file,
        bundletool_inputs,
        mac_exec_group,
        mnemonic,
        output_archive,
        progress_message,
        xcode_config):
    """Generates an action that creates a tree artifact for a bundle rule output.

    Args:
      actions: The actions provider from `ctx.actions`.
      additional_bundling_tools: A list of additional tools to make available to the action.
      apple_fragment: An Apple fragment (ctx.fragments.apple).
      apple_mac_toolchain_info: A AppleMacToolsToolchainInfo provider.
      bundletool_control_file: A File referencing the control file for the bundletool.
      bundletool_inputs: A depset of files to pass to the bundletool.
      mac_exec_group: A String. The exec_group for actions using the mac toolchain.
      mnemonic: A String. The mnemonic to use for the action.
      output_archive: A File referencing the output tree artifact.
      progress_message: A String. The progress message to use for the action.
      xcode_config: The `apple_common.XcodeVersionConfig` provider from the context.
    """
    apple_support.run(
        actions = actions,
        apple_fragment = apple_fragment,
        arguments = [
            bundletool_control_file.path,
        ],
        exec_group = mac_exec_group,
        executable = apple_mac_toolchain_info.bundletool_mac,
        execution_requirements = {
            # Added so that the output of this action is not cached remotely, in case multiple
            # developers sign the same artifact with different identities.
            "no-remote": "1",
            # Unsure, but may be needed for keychain access, especially for files that live in
            # $HOME.
            "no-sandbox": "1",
        },
        inputs = bundletool_inputs,
        mnemonic = mnemonic,
        outputs = [output_archive],
        progress_message = progress_message,
        tools = additional_bundling_tools,
        xcode_config = xcode_config,
    )

def _path_is_under_fragments(path, path_fragments):
    """Helper for _ensure_asset_types().

    Checks that the given path is under the given set of path fragments.

    Args:
      path: String of the path to check.
      path_fragments: List of string to check for in the path (in order).

    Returns:
      True/False for if the path includes the ordered fragments.
    """
    start_offset = 0
    for suffix in path_fragments:
        offset = path.find(suffix, start_offset)
        if offset != -1:
            start_offset = offset + len(suffix)
            continue

        if start_offset and path[start_offset:] == "Contents.json":
            # After the first segment was found, always accept a Contents.json file.
            return True

        return False

    return True

def _ensure_path_format(
        *,
        files,
        allowed_path_fragments,
        denied_path_fragments,
        message = None):
    """Ensure the files match the required path fragments.

    Args:
      files: An iterable of files to use.
      allowed_path_fragments: A list representing a sequence of extensions where each file path
          passed in MUST MATCH the sequence to ensure proper nesting. If this is provided,
          denied_path_fragments must be empty.
      denied_path_fragments: A list representing a sequence of extensions where each file path
          passed in MUST NOT MATCH the sequence to ensure proper nesting. If this is provided,
          allowed_path_fragments must be empty.
      message: A custom error message to use, the list of found files that
          didn't match will be printed afterwards.
    """

    if allowed_path_fragments and denied_path_fragments:
        fail("""
Internal Error: Both allowed_path_fragments and denied_path_fragments were provided, but only one \
of them should be provided.

Please file an issue on the Apple BUILD Rules.
""")

    formatted_path_fragments = []
    for x in allowed_path_fragments + denied_path_fragments:
        formatted_path_fragments.append(".%s/" % x)
    allow_path_under_fragments = bool(allowed_path_fragments)

    bad_paths = set()
    for f in files:
        path = f.path
        if _path_is_under_fragments(path, formatted_path_fragments) != allow_path_under_fragments:
            bad_paths.add(path)

    if len(bad_paths):
        if not message:
            message_prefix = (
                "Expected only " if allow_path_under_fragments else "Did not expect any "
            )
            as_path = "*" + "*".join(formatted_path_fragments) + "..."
            message = message_prefix + "files inside directories named '*.%s'" % (as_path)

        formatted_paths = "[\n  %s\n]" % ",\n  ".join(bad_paths)
        fail("%s, but found the following: %s" % (message, formatted_paths))

def _validate_bundle_id(bundle_id):
    """Ensure the value is a valid bundle it or fail the build.

    Args:
      bundle_id: The string to check.
    """

    # Make sure the bundle id seems like a valid one. Apple's docs for
    # CFBundleIdentifier are all we have to go on, which are pretty minimal. The
    # only they they specifically document is the character set, so the other
    # two checks here are just added safety to catch likely errors by developers
    # setting things up.
    bundle_id_parts = bundle_id.split(".")
    for part in bundle_id_parts:
        if part == "":
            fail("Empty segment in bundle_id: \"%s\"" % bundle_id)
        if not part.isalnum():
            # Only non alpha numerics that are allowed are '.' and '-'. '.' was
            # handled by the split(), so just have to check for '-'.
            for i in range(len(part)):
                ch = part[i]
                if ch != "-" and not ch.isalnum():
                    fail("Invalid character(s) in bundle_id: \"%s\"" % bundle_id)

# Define the loadable module that lists the exported symbols in this file.
bundling_support = struct(
    bundle_full_name = _bundle_full_name,
    bundle_full_id = _bundle_full_id,
    ensure_asset_catalog_files_not_in_xcassets = _ensure_asset_catalog_files_not_in_xcassets,
    ensure_single_xcassets_type = _ensure_single_xcassets_type,
    generate_bundle_archive_action = _generate_bundle_archive_action,
    generate_tree_artifact_bundle_action = _generate_tree_artifact_bundle_action,
    validate_bundle_id = _validate_bundle_id,
)
