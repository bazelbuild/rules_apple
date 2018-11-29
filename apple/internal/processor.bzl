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

"""Core bundling logic.

The processor module handles the execution of logic for different parts of the
bundling process. This logic is encapsulated into blocks of code called
partials. Each partial will then process a specific aspect of the build process
and will return information on how the bundles should be built.

All partials handled by this processor must follow this API:

  - The only expected argument has to be ctx.
  - The expected output is a struct with the following optional fields:
    * bundle_files: Contains tuples of the format
      (location_type, parent_dir, files) where location_type is a field of the
      location enum. The files are then placed at the given location in the
      output bundle.
    * bundle_zips: Contains tuples of the format
      (location_type, parent_dir, files) where location_type is a field of the
      location enum and each file is a ZIP file. The files extracted from the
      ZIPs are then placed at the given location in the output bundle.
    * output_files: Depset of `File`s that should be returned as outputs of the
      target.
    * providers: Providers that will be collected and returned by the rule.

Location types can be 7:
  - archive: Files are to be placed relative to the archive of the bundle
    (i.e. the root of the zip/IPA file to generate).
  - binary: Files are to be placed in the binary section of the bundle.
  - bundle: Files are to be placed at the root of the bundle.
  - content: Files are to be placed in the contents section of the bundle.
  - framework: Files are to be placed in the Frameworks section of the bundle.
  - plugin: Files are to be placed in the PlugIns section of the bundle.
  - resources: Files are to be placed in the resources section of the bundle.
  - watch: Files are to be placed inside the Watch section of the bundle. Only applicable for iOS
    apps.

For iOS, tvOS and watchOS, binary, content and resources all refer to the same
location. Only in macOS these paths differ.

All the files given will be symlinked into their expected location in the
bundle, and once complete, the processor will codesign and compress the bundle
into a zip file.

The processor will output a single file, which is the final compressed and
code-signed bundle, and a list of providers that need to be propagated from the
rule.
"""

load(
    "@build_bazel_rules_apple//apple/bundling:bundling_support.bzl",
    "bundling_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:codesigning_actions.bzl",
    "codesigning_actions",
)
load(
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/internal:outputs.bzl",
    "outputs",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_support.bzl",
    "rule_support",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

# Location enum that can be used to tag files into their appropriate location
# in the final archive.
_LOCATION_ENUM = struct(
    archive = "archive",
    binary = "binary",
    bundle = "bundle",
    content = "content",
    framework = "framework",
    plugin = "plugin",
    resource = "resource",
    watch = "watch",
)

def _invalid_top_level_directories_for_platform(platform_type):
    """List of invalid top level directories for the given platform."""

    # As far as we know, there are no locations in macOS bundles that would break
    # codesigning.
    if platform_type == apple_common.platform_type.macos:
        return []

    # Non macOS bundles can't have a top level Resources folder, as it breaks
    # codesigning for some reason. With this, we validate that there are no
    # Resources folder going to be created in the bundle, with a message that
    # better explains which files are incorrectly placed.
    return ["Resources"]

def _is_parent_dir_valid(invalid_top_level_dirs, parent_dir):
    """Validates that the files to bundle are not placed in invalid locations.

    codesign will complain when building a non macOS bundle that contains certain
    folders at the top level. We check if there are files that would break
    codesign, and fail early with a nicer message.

    Args:
      invalid_top_level_dirs: String list containing the top level
          directories that have to be avoided when bundling resources.
      parent_dir: String containing the a parent directory inside a bundle.

    Returns:
      False if the parent_dir value is invalid.
    """
    if not parent_dir:
        return True
    for invalid_dir in invalid_top_level_dirs:
        if parent_dir == invalid_dir or parent_dir.startswith(invalid_dir + "/"):
            return False
    return True

def _archive_paths(ctx):
    """Returns the map of location type to final archive path."""
    rule_descriptor = rule_support.rule_descriptor(ctx)

    bundle_name_with_extension = (
        bundling_support.bundle_name(ctx) + bundling_support.bundle_extension(ctx)
    )
    bundle_path = paths.join(
        rule_descriptor.bundle_locations.archive_relative,
        bundle_name_with_extension,
    )

    contents_path = paths.join(
        bundle_path,
        rule_descriptor.bundle_locations.bundle_relative_contents,
    )

    # Map of location types to relative paths in the archive.
    return {
        _LOCATION_ENUM.archive: "",
        _LOCATION_ENUM.binary: paths.join(
            contents_path,
            rule_descriptor.bundle_locations.contents_relative_binary,
        ),
        _LOCATION_ENUM.bundle: bundle_path,
        _LOCATION_ENUM.content: contents_path,
        _LOCATION_ENUM.framework: paths.join(
            contents_path,
            rule_descriptor.bundle_locations.contents_relative_frameworks,
        ),
        _LOCATION_ENUM.plugin: paths.join(
            contents_path,
            rule_descriptor.bundle_locations.contents_relative_plugins,
        ),
        _LOCATION_ENUM.resource: paths.join(
            contents_path,
            rule_descriptor.bundle_locations.contents_relative_resources,
        ),
        _LOCATION_ENUM.watch: paths.join(
            contents_path,
            rule_descriptor.bundle_locations.contents_relative_watch,
        ),
    }

def _bundle_partial_outputs_files(ctx, partial_outputs, output_file):
    """Invokes bundletool to bundle the files specified by the partial outputs.

    Args:
      ctx: The target's rule context.
      partial_outputs: List of partial outputs from which to collect the files
        that will be bundled inside the final archive.
      output_file: The file where the final zipped bundle should be created.
    """
    control_files = []
    control_zips = []
    input_files = []

    location_to_paths = _archive_paths(ctx)

    platform_type = platform_support.platform_type(ctx)
    invalid_top_level_dirs = _invalid_top_level_directories_for_platform(platform_type)

    processed_file_target_paths = {}
    for partial_output in partial_outputs:
        for location, parent_dir, files in getattr(partial_output, "bundle_files", []):
            if (invalid_top_level_dirs and
                not _is_parent_dir_valid(invalid_top_level_dirs, parent_dir)):
                fail(("Error: For %s bundles, the following top level " +
                      "directories are invalid: %s") %
                     (platform_type, ", ".join(invalid_top_level_dirs)))

            sources = files.to_list()
            input_files.extend(sources)

            for source in sources:
                target_path = paths.join(location_to_paths[location], parent_dir or "")

                if not source.is_directory:
                    target_path = paths.join(target_path, source.basename)
                    if target_path in processed_file_target_paths:
                        fail(
                            ("Multiple files would be placed at \"%s\" in the bundle, which " +
                             "is not allowed") % target_path,
                        )
                    processed_file_target_paths[target_path] = None
                control_files.append(struct(src = source.path, dest = target_path))

        for location, parent_dir, zip_files in getattr(partial_output, "bundle_zips", []):
            if (invalid_top_level_dirs and
                not _is_parent_dir_valid(invalid_top_level_dirs, parent_dir)):
                fail(("Error: For %s bundles, the following top level " +
                      "directories are invalid: %s") %
                     (platform_type, ", ".join(invalid_top_level_dirs)))

            sources = zip_files.to_list()
            input_files.extend(sources)

            for source in sources:
                target_path = paths.join(location_to_paths[location], parent_dir or "")
                control_zips.append(struct(src = source.path, dest = target_path))

    control = struct(
        bundle_merge_files = control_files,
        bundle_merge_zips = control_zips,
        output = output_file.path,
    )

    control_file = intermediates.file(
        ctx.actions,
        ctx.label.name,
        "bundletool_control.json",
    )
    ctx.actions.write(
        output = control_file,
        content = control.to_json(),
    )

    ctx.actions.run(
        inputs = input_files + [control_file],
        outputs = [output_file],
        executable = ctx.executable._bundletool,
        arguments = [control_file.path],
        mnemonic = "BundleApp",
        progress_message = "Bundling %s" % ctx.label.name,
    )

def _process(ctx, partials):
    """Processes a list of partials that provide the files to be bundled.

    Args:
      ctx: The ctx object for the target being processed.
      partials: The list of partials to process to construct the complete bundle.

    Returns:
      A struct with the results of the processing. The files to make outputs of
      the rule are contained under the `output_files` field, and the providers to
      return are contained under the `providers` field.
    """
    partial_outputs = [partial.call(p, ctx) for p in partials]

    # This output, while an intermediate artifact not exposed through the AppleBundleInfo provider,
    # is used by Tulsi for custom processing logic. (b/120221708)
    unprocessed_archive = ctx.actions.declare_file(
        "{}.unprocessed.zip".format(ctx.label.name),
        sibling = outputs.archive(ctx),
    )
    _bundle_partial_outputs_files(ctx, partial_outputs, unprocessed_archive)

    archive_paths = _archive_paths(ctx)
    archive_codesigning_path = archive_paths[_LOCATION_ENUM.bundle]
    frameworks_path = archive_paths[_LOCATION_ENUM.framework]

    output_archive = outputs.archive(ctx)
    output_archive_root_path = outputs.archive_root_path(ctx)
    codesigning_actions.post_process_and_sign_archive_action(
        ctx,
        archive_codesigning_path,
        frameworks_path,
        unprocessed_archive,
        output_archive,
        output_archive_root_path,
    )

    providers = []
    output_files = depset([output_archive])
    for partial_output in partial_outputs:
        if hasattr(partial_output, "providers"):
            providers.extend(partial_output.providers)
        if hasattr(partial_output, "output_files"):
            output_files = depset(
                transitive = [output_files, partial_output.output_files],
            )

    return struct(
        output_files = output_files,
        providers = providers,
    )

processor = struct(
    process = _process,
    location = _LOCATION_ENUM,
)
