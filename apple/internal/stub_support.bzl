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

"""Stub binary creation support methods."""

load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:bitcode_support.bzl",
    "bitcode_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)

def _create_stub_binary(
        *,
        actions,
        output_discriminator = None,
        platform_prerequisites,
        rule_label,
        xcode_stub_path):
    """Returns a symlinked stub binary from the Xcode distribution.

    Args:
        actions: The actions provider from `ctx.actions`.
        output_discriminator: A string to differentiate between different target intermediate files
            or `None`.
        platform_prerequisites: Struct containing information on the platform being targeted.
        rule_label: The label of the target being analyzed.
        xcode_stub_path: The Xcode SDK root relative path to where the stub binary is to be copied
            from.

    Returns:
        A File reference to the stub binary artifact.
    """
    binary_artifact = intermediates.file(
        actions = actions,
        target_name = rule_label.name,
        output_discriminator = output_discriminator,
        file_name = "StubBinary",
    )

    if bitcode_support.bitcode_mode_string(platform_prerequisites.apple_fragment) == "none":
        apple_support.run(
            actions = actions,
            apple_fragment = platform_prerequisites.apple_fragment,
            executable = "/usr/bin/xcrun",
            arguments = ["bitcode_strip", "-r", "__BAZEL_XCODE_SDKROOT__/{}".format(xcode_stub_path), "-o", binary_artifact.path],
            mnemonic = "BitcodeStripStub",
            outputs = [binary_artifact],
            xcode_path_resolve_level = apple_support.xcode_path_resolve_level.args,
            progress_message = "Removing bitcode from stub executable for %s" % (rule_label),
            xcode_config = platform_prerequisites.xcode_version_config,
        )
    else:
        # TODO(b/79323243): Replace this with a symlink instead of a hard copy.
        apple_support.run_shell(
            actions = actions,
            apple_fragment = platform_prerequisites.apple_fragment,
            command = "cp -f \"$SDKROOT/{xcode_stub_path}\" {output_path}".format(
                output_path = binary_artifact.path,
                xcode_stub_path = xcode_stub_path,
            ),
            mnemonic = "CopyStubExecutable",
            outputs = [binary_artifact],
            progress_message = "Copying stub executable for %s" % (rule_label),
            xcode_config = platform_prerequisites.xcode_version_config,
        )
    return binary_artifact

stub_support = struct(
    create_stub_binary = _create_stub_binary,
)
