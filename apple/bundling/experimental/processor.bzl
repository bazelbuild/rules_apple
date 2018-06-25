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

The processor will output a single file, which is the final compressed and
code-signed bundle, and a list of providers that need to be propagated from the
rule.
"""

load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@build_bazel_rules_apple//apple/bundling:bundling_support.bzl",
    "bundling_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:codesigning_actions.bzl",
    "codesigning_actions",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:intermediates.bzl",
    "intermediates",
)

# Location enum that can be used to tag files into their appropriate location
# in the final archive.
_LOCATION_ENUM = struct(
    archive="archive",
    binary="binary",
    bundle="bundle",
    content="content",
    framework="framework",
    resource="resource",
)

def _archive_paths(ctx):
  """Returns the map of location type to final archive path."""
  # TODO(kaipi): Handle parameterized paths for macOS.
  contents_path = paths.join(
      "Payload", bundling_support.bundle_name(ctx) + ".app",
  )

  frameworks_path = paths.join(
      contents_path, "Frameworks",
  )

  # Map of location types to relative paths in the archive.
  # TODO(kaipi): Handle parameterized paths for macOS.
  return {
      _LOCATION_ENUM.archive: "",
      _LOCATION_ENUM.binary: contents_path,
      _LOCATION_ENUM.bundle: contents_path,
      _LOCATION_ENUM.content: contents_path,
      _LOCATION_ENUM.framework: frameworks_path,
      _LOCATION_ENUM.resource: contents_path,
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
  input_files = []

  location_to_paths = _archive_paths(ctx)

  for partial_output in partial_outputs:
    for location, parent_dir, files in partial_output.files:
      sources = files.to_list()
      input_files.extend(sources)

      for source in sources:
        target_path = paths.join(location_to_paths[location], parent_dir or "")
        if not source.is_directory:
          target_path = paths.join(target_path, source.basename)
        control_files.append(struct(src=source.path, dest=target_path))

  control = struct(
      bundle_merge_files = control_files,
      output = output_file.path,
  )

  control_file = intermediates.file(
      ctx.actions, ctx.label.name, "bundletool_control.json",
  )
  ctx.actions.write(
      output=control_file,
      content=control.to_json()
  )

  ctx.actions.run(
      inputs=input_files + [control_file],
      outputs=[output_file],
      executable=ctx.executable._bundletool,
      arguments=[control_file.path],
      mnemonic="BundleApp",
      progress_message="Bundling %s" % ctx.label.name,
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
  partial_outputs = [partial.call(p, ctx) for p in partials]

  unprocessed_archive = intermediates.file(
      ctx.actions, ctx.label.name, "unprocessed_archive.zip",
  )
  _bundle_partial_outputs_files(ctx, partial_outputs, unprocessed_archive)

  archive_paths = _archive_paths(ctx)
  archive_codesigning_path = archive_paths[_LOCATION_ENUM.bundle]
  frameworks_path = archive_paths[_LOCATION_ENUM.framework]
  output_archive = intermediates.file(
      ctx.actions, ctx.label.name, "processed_archive.zip",
  )
  codesigning_actions.post_process_and_sign_archive_action(
      ctx,
      archive_codesigning_path,
      frameworks_path,
      unprocessed_archive,
      output_archive,
  )

  providers = []
  for partial_output in partial_outputs:
    providers.extend(partial_output.providers)

  return output_archive, providers

processor = struct(
    process=_process,
    location=_LOCATION_ENUM,
)
