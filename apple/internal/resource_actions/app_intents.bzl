# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""AppIntents intents related actions."""

load("@build_bazel_apple_support//lib:apple_support.bzl", "apple_support")
load("@build_bazel_rules_apple//apple/internal:intermediates.bzl", "intermediates")

def generate_app_intents_metadata_bundle(
        *,
        actions,
        apple_fragment,
        bundle_binary,
        source_files,
        label,
        target_triples,
        xcode_version_config):
    """Process and generate AppIntents metadata bundle (Metadata.appintents).

    Args:
        actions: The actions provider from `ctx.actions`.
        apple_fragment: An Apple fragment (ctx.fragments.apple).
        bundle_binary: File referencing an application/extension/framework binary.
        source_files: List of Swift source files implementing the AppIntents protocol.
        label: Label for the current target (`ctx.label`).
        target_triples: List of Apple target triples from `CcToolchainInfo` providers.
        xcode_version_config: The `apple_common.XcodeVersionConfig` provider from the current ctx.
    Returns:
        File referencing the Metadata.appintents bundle.
    """

    output = intermediates.directory(
        actions = actions,
        target_name = label.name,
        output_discriminator = None,
        dir_name = "Metadata.appintents",
    )

    args = actions.args()
    args.add("appintentsmetadataprocessor")

    args.add("--binary-file", bundle_binary)
    args.add("--module-name", label.name)
    args.add("--output", output.dirname)
    args.add_all("--source-files", source_files)
    args.add("--sdk-root", apple_support.path_placeholders.sdkroot())
    args.add_all(target_triples, before_each = "--target-triple")
    args.add("--toolchain-dir", "{xcode_path}/Toolchains/XcodeDefault.xctoolchain".format(
        xcode_path = apple_support.path_placeholders.xcode(),
    ))
    if xcode_version_config.xcode_version() >= apple_common.dotted_version("15.0"):
        # TODO(b/295227222): Generate app intents metadata with --compile-time-extraction using
        # .swiftconstvals instead of --legacy-extraction at the earliest convenience.
        args.add("--legacy-extraction")

    apple_support.run(
        actions = actions,
        apple_fragment = apple_fragment,
        arguments = [args],
        executable = "/usr/bin/xcrun",
        inputs = depset([bundle_binary], transitive = [depset(source_files)]),
        outputs = [output],
        mnemonic = "AppIntentsMetadataProcessor",
        xcode_config = xcode_version_config,
    )

    return output
