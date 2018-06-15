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
  - The expected output is a struct with 2 fields:
    * files: Contains a tuple of the format (location_type, parent_dir, files)
      where location_type is a field of the location enum.

Location types can be 4:
  - archive: Files are to be placed relative to the archive of the bundle
    (i.e. the root of the zip/IPA file to generate).
  - binary: Files are to be placed in the binary section of the bundle.
  - content: Files are to be placed in the contents section of the bundle.
  - resources: Files are to be placed in the resources section of the bundle.

For iOS, tvOS and watchOS, binary, content and resources all refer to the same
location. Only in macOS these paths differ.

All the files given will be symlinked into their expected location in the
bundle, and once complete, the processor will codesign and compress the bundle
into a zip file.

The processor will output a single file, which is the final compressed bundle,
and a list of providers that need to be propagated from the rule.
"""

load("@bazel_skylib//lib:partial.bzl", "partial")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@build_bazel_rules_apple//apple/bundling:file_actions.bzl", "file_actions")
load("@build_bazel_rules_apple//apple/bundling:bundling_support.bzl", "bundling_support")
load("@build_bazel_rules_apple//apple:utils.bzl", "join_commands")

# Location enum that can be used to tag files into their appropriate location
# in the final bundle.
_LOCATION_ENUM = struct(
    resource="resource",
    content="content",
    archive="archive",
    binary="binary",
)

def _process(ctx, partials):
  """Processes a list of partials that provide the files to be bundled.

  Args:
    ctx: The ctx object for the target being processed.
    partials: The list of partials to process to construct the complete bundle.

  Returns:
    The final compressed bundle and a list of providers to be propagated from
    the target.
  """
  # Staging path for the bundle.
  archive_root = "%s-archiveroot" % ctx.label.name

  # TODO(kaipi): Handle parameterized paths for macOS.
  contents_path = paths.join(
      archive_root,
      paths.join("Payload", bundling_support.bundle_name(ctx) + ".app")
  )

  # Map of location types to relative paths in the archive.
  # TODO(kaipi): Handle parameterized paths for macOS.
  location_to_paths = {
      _LOCATION_ENUM.archive: archive_root,
      _LOCATION_ENUM.binary: contents_path,
      _LOCATION_ENUM.content: contents_path,
      _LOCATION_ENUM.resource: contents_path,
  }

  structs = [partial.call(p, ctx) for p in partials]
  providers = []
  target_files = []
  for s in structs:
    providers.extend(s.providers)

    for location, parent_dir, files in s.files:
      for source in files.to_list():
        # For each file, symlink it into the expected location in the bundle.
        target = ctx.actions.declare_file(
            paths.join(location_to_paths[location], parent_dir or "", source.basename)
        )
        target_files.append(target)
        file_actions.symlink(ctx, source, target)

  # Compress the staging directory into a zip file.
  # TODO(kaipi): Handle signing. Look into integrating with bundletool or
  # repurposing it. Also handle zip files that need to be uncompressed into
  # expected locations in the bundle.
  archive_path = paths.join(ctx.bin_dir.path, ctx.label.package, archive_root)
  output = ctx.actions.declare_file(archive_root + ".zip")
  ctx.actions.run(
      executable="/bin/sh",
      arguments = ["-c", join_commands([
          "export OUTPUT_PATH=\"$PWD/%s\"" % output.path,
          "pushd %s > /dev/null" % archive_path,
          "zip -r \"$OUTPUT_PATH\" * > /dev/null",
          "popd > /dev/null",
      ])],
      inputs = target_files,
      outputs = [output],
  )

  return output, providers

processor = struct(
    process=_process,
    location=_LOCATION_ENUM,
)
