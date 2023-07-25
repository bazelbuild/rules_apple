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

"""Partial implementation for processing AppIntents metadata bundle."""

load("@build_bazel_rules_apple//apple/internal:intermediates.bzl", "intermediates")
load("@build_bazel_rules_apple//apple/internal:linking_support.bzl", "linking_support")
load("@build_bazel_rules_apple//apple/internal:processor.bzl", "processor")
load(
    "@build_bazel_rules_apple//apple/internal/providers:app_intents_info.bzl",
    "AppIntentsInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/resource_actions:app_intents.bzl",
    "generate_app_intents_metadata_bundle",
)
load("@bazel_skylib//lib:partial.bzl", "partial")

def _app_intents_metadata_bundle_partial_impl(
        *,
        actions,
        cc_toolchains,
        ctx,
        deps,
        disabled_features,
        features,
        label,
        platform_prerequisites):
    """Implementation of the AppIntents metadata bundle partial."""
    if not deps:
        # No `app_intents` were set by the rule calling this partial.
        return struct()

    # Link 'stub' binary to use for app intents metadata processing.
    # This binary should only contain symbols for structs implementing the AppIntents protocol.
    # Instead of containing all the application/extension/framework binary symbols, allowing
    # the action to run faster and avoid depending on the application binary linking step.
    link_result = linking_support.link_multi_arch_binary(
        actions = actions,
        cc_toolchains = cc_toolchains,
        ctx = ctx,
        deps = deps,
        disabled_features = disabled_features,
        features = features,
        label = label,
        # Allow `_main` to be undefined since none of the AppIntents implementing dependencies
        # should include this entry point, and we only care about linking all AppIntents symbols.
        user_link_flags = ["-Wl,-U,_main"],
    )

    fat_stub_binary = intermediates.file(
        actions = actions,
        target_name = label.name,
        output_discriminator = None,
        file_name = "{}_app_intents_stub_binary".format(label.name),
    )

    linking_support.lipo_or_symlink_inputs(
        actions = actions,
        inputs = [output.binary for output in link_result.outputs],
        output = fat_stub_binary,
        apple_fragment = platform_prerequisites.apple_fragment,
        xcode_config = platform_prerequisites.xcode_version_config,
    )

    label.relative(
        label.name + "_app_intents_stub_binary",
    )

    metadata_bundle = generate_app_intents_metadata_bundle(
        actions = actions,
        apple_fragment = platform_prerequisites.apple_fragment,
        bundle_binary = fat_stub_binary,
        label = label,
        source_files = [
            swift_source_file
            for split_deps in deps.values()
            for dep in split_deps
            for swift_source_file in dep[AppIntentsInfo].swift_source_files
        ],
        target_triples = [
            cc_toolchain[cc_common.CcToolchainInfo].target_gnu_system_name
            for cc_toolchain in cc_toolchains.values()
        ],
        xcode_version_config = platform_prerequisites.xcode_version_config,
    )

    bundle_location = processor.location.bundle
    if str(platform_prerequisites.platform_type) == "macos":
        bundle_location = processor.location.resource

    return struct(
        bundle_files = [(
            bundle_location,
            "Metadata.appintents",
            depset(direct = [metadata_bundle]),
        )],
    )

def app_intents_metadata_bundle_partial(
        *,
        actions,
        cc_toolchains,
        ctx,
        deps,
        disabled_features,
        features,
        label,
        platform_prerequisites):
    """Constructor for the AppIntents metadata bundle processing partial.

    This partial generates the Metadata.appintents bundle required for AppIntents functionality.

    Args:
        actions: The actions provider from ctx.actions.
        cc_toolchains: Dictionary of CcToolchainInfo providers for current target splits.
        ctx: The Starlark context for a rule target being built.
        deps: List of dependencies implementing the AppIntents protocol.
        disabled_features: List of features to be disabled for C++ link actions.
        features: List of features to be enabled for C++ link actions.
        label: Label of the target being built.
        platform_prerequisites: Struct containing information on the platform being targeted.
    Returns:
        A partial that generates the Metadata.appintents bundle.
    """
    return partial.make(
        _app_intents_metadata_bundle_partial_impl,
        actions = actions,
        cc_toolchains = cc_toolchains,
        ctx = ctx,
        deps = deps,
        disabled_features = disabled_features,
        features = features,
        label = label,
        platform_prerequisites = platform_prerequisites,
    )
