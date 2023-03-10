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

"""Partial implementation for bitcode symbol file processing."""

load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/internal:processor.bzl",
    "processor",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)

_AppleBitcodeInfo = provider(
    doc = "Private provider to propagate the transitive bitcode `File`s.",
    fields = {
        "bitcode": "Depset of `File`s containing the transitive dependency bitcode files.",
    },
)

def _bitcode_symbols_partial_impl(
        *,
        actions,
        binary_artifact,
        bitcode_symbol_maps,
        dependency_targets,
        label_name,
        output_discriminator,
        package_bitcode,
        platform_prerequisites):
    """Implementation for the bitcode symbols processing partial."""

    bitcode_dirs = []

    bitcode_symbols = {}
    if bitcode_symbol_maps:
        bitcode_symbols.update(bitcode_symbol_maps)

    if binary_artifact and bitcode_symbols:
        bitcode_files = []
        copy_commands = []
        for arch in bitcode_symbols:
            bitcode_file = bitcode_symbols[arch]
            if not bitcode_file:
                continue
            bitcode_files.append(bitcode_file)

            # Get the UUID of the arch slice and use that to name the bcsymbolmap file.
            copy_commands.append(
                ("cp {bitcode_file} " +
                 "${{OUTPUT_DIR}}/$(dwarfdump -u {binary} " +
                 "| grep \"({arch})\" | cut -d' ' -f2).bcsymbolmap").format(
                    arch = arch,
                    binary = binary_artifact.path,
                    bitcode_file = bitcode_file.path,
                ),
            )

        if bitcode_files:
            bitcode_dir = intermediates.directory(
                actions = actions,
                target_name = label_name,
                output_discriminator = output_discriminator,
                dir_name = "bitcode_files",
            )
            bitcode_dirs.append(bitcode_dir)

            apple_support.run_shell(
                actions = actions,
                apple_fragment = platform_prerequisites.apple_fragment,
                inputs = [binary_artifact] + bitcode_files,
                outputs = [bitcode_dir],
                command = "mkdir -p ${OUTPUT_DIR} && " + " && ".join(copy_commands),
                env = {"OUTPUT_DIR": bitcode_dir.path},
                mnemonic = "BitcodeSymbolsCopy",
                xcode_config = platform_prerequisites.xcode_version_config,
            )

    transitive_bitcode_files = depset(
        direct = bitcode_dirs,
        transitive = [
            x[_AppleBitcodeInfo].bitcode
            for x in dependency_targets
            if _AppleBitcodeInfo in x
        ],
    )

    if package_bitcode:
        bundle_files = [(processor.location.archive, "BCSymbolMaps", transitive_bitcode_files)]
    else:
        bundle_files = []

    return struct(
        bundle_files = bundle_files,
        providers = [_AppleBitcodeInfo(bitcode = transitive_bitcode_files)],
    )

def bitcode_symbols_partial(
        *,
        actions,
        binary_artifact = None,
        bitcode_symbol_maps = {},
        dependency_targets = [],
        label_name,
        output_discriminator = None,
        package_bitcode = False,
        platform_prerequisites):
    """Constructor for the bitcode symbols processing partial.

    Args:
      actions: Actions defined for the current build context.
      binary_artifact: The main binary artifact for this target.
      bitcode_symbol_maps: A mapping of architectures to Files representing bitcode symbol maps for
        each architecture.
      dependency_targets: List of targets that should be checked for bitcode files that need to be
        bundled..
      label_name: Name of the target being built
      output_discriminator: A string to differentiate between different target intermediate files
          or `None`.
      package_bitcode: Whether the partial should package the bitcode files for all dependency
        binaries.
      platform_prerequisites: Struct containing information on the platform being targeted.

    Returns:
      A partial that returns the bitcode files to propagate or bundle, if any were requested.
    """
    return partial.make(
        _bitcode_symbols_partial_impl,
        actions = actions,
        binary_artifact = binary_artifact,
        bitcode_symbol_maps = bitcode_symbol_maps,
        dependency_targets = dependency_targets,
        label_name = label_name,
        output_discriminator = output_discriminator,
        package_bitcode = package_bitcode,
        platform_prerequisites = platform_prerequisites,
    )
