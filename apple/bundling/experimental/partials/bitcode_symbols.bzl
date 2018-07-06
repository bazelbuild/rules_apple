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
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "join_commands",
)
load(
    "@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:processor.bzl",
    "processor",
)

def _bitcode_symbols_partial_impl(ctx, binary_artifact, debug_outputs_provider=None):
    """Implementation for the bitcode symbols processing partial."""
    # If there is no AppleDebugOutputs provider, return early.
    if not debug_outputs_provider:
        return struct()

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
             "${{{{OUTPUT_DIR}}}}/$(dwarfdump -u -arch {arch} {binary} " +
             "| cut -d' ' -f2).bcsymbolmap").format(
                arch = arch,
                binary = binary_artifact.path,
                bitcode_file = bitcode_file.path,
            ),
        )

    if not bitcode_files:
        return struct()

    bitcode_dir = intermediates.directory(ctx.actions, ctx.label.name, "bitcode_files")

    platform_support.xcode_env_action(
        ctx,
        inputs = [binary_artifact] + bitcode_files,
        outputs = [bitcode_dir],
        command = [
            "/bin/bash",
            "-c",
            (
                "set -e && " +
                "OUTPUT_DIR={output_path} && " +
                "mkdir -p {output_path} && " +
                join_commands(copy_commands)
            ).format(output_path = bitcode_dir.path),
        ],
        mnemonic = "BitcodeSymbolsCopy",
    )

    bundle_files = [(processor.location.archive, "BCSymbolMaps", depset([bitcode_dir]))]

    return struct(bundle_files = bundle_files)

def bitcode_symbols_partial(binary_artifact, debug_outputs_provider):
    """Constructor for the bitcode symbols processing partial.

    Args:
      binary_artifact: The main binary artifact for this target.
      debug_outputs_provider: The AppleDebugOutputs provider containing the references to the debug
        outputs of this target's binary.

    Returns:
      A partial that returns the bitcode files to bundle, if any were requested.
    """
    return partial.make(
        _bitcode_symbols_partial_impl,
        binary_artifact = binary_artifact,
        debug_outputs_provider = debug_outputs_provider,
    )
