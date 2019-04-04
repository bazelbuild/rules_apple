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
    "@build_bazel_rules_apple//apple/internal/utils:legacy_actions.bzl",
    "legacy_actions",
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
        ctx,
        binary_artifact,
        debug_outputs_provider,
        dependency_targets,
        package_bitcode):
    """Implementation for the bitcode symbols processing partial."""

    bitcode_dirs = []
    if binary_artifact and debug_outputs_provider:
        debug_outputs_map = debug_outputs_provider.outputs_map

        bitcode_files = []
        copy_commands = []
        for arch in debug_outputs_map:
            bitcode_file = debug_outputs_map[arch].get("bitcode_symbols")
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
            bitcode_dir = intermediates.directory(ctx.actions, ctx.label.name, "bitcode_files")
            bitcode_dirs.append(bitcode_dir)

            legacy_actions.run_shell(
                ctx,
                inputs = [binary_artifact] + bitcode_files,
                outputs = [bitcode_dir],
                command = "mkdir -p ${OUTPUT_DIR} && " + " && ".join(copy_commands),
                env = {"OUTPUT_DIR": bitcode_dir.path},
                mnemonic = "BitcodeSymbolsCopy",
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
        binary_artifact = None,
        debug_outputs_provider = None,
        dependency_targets = [],
        package_bitcode = False):
    """Constructor for the bitcode symbols processing partial.

    Args:
      binary_artifact: The main binary artifact for this target.
      debug_outputs_provider: The AppleDebugOutputs provider containing the references to the debug
        outputs of this target's binary.
      dependency_targets: List of targets that should be checked for bitcode files that need to be
        bundled..
      package_bitcode: Whether the partial should package the bitcode files for all dependency
        binaries.

    Returns:
      A partial that returns the bitcode files to propagate or bundle, if any were requested.
    """
    return partial.make(
        _bitcode_symbols_partial_impl,
        binary_artifact = binary_artifact,
        debug_outputs_provider = debug_outputs_provider,
        dependency_targets = dependency_targets,
        package_bitcode = package_bitcode,
    )
