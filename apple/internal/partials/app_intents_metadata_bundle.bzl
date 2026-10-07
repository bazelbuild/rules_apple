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

load("@bazel_skylib//lib:partial.bzl", "partial")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("//apple/internal:outputs.bzl", "outputs")
load("//apple/internal:processor.bzl", "processor")
load(
    "//apple/internal/providers:app_intents_info.bzl",
    "AppIntentsInfo",
)
load(
    "//apple/internal/resource_actions:app_intents.bzl",
    "generate_app_intents_metadata_bundle",
    "generate_app_intents_nl_training_assets",
)

def _app_intents_nl_training_partial_impl(
        *,
        actions,
        bundle_id,
        label,
        mac_exec_group,
        metadata_bundle,
        nl_training_tool,
        partial_outputs,
        platform_prerequisites):
    """Implementation of the App Shortcuts Flexible Matching partial.

    It consumes the training inputs explicitly exported by resource processing.
    """
    infoplist = outputs.infoplist(
        actions = actions,
        label_name = label.name,
        output_discriminator = None,
    )
    lproj_dirs = {}
    lproj_files = []
    resource_trees = []
    for partial_output in partial_outputs:
        training_resources = getattr(partial_output, "app_intents_resources", None)
        if training_resources:
            for lproj_dir in training_resources.lproj_dirs:
                lproj_dirs[lproj_dir] = None
            lproj_files.extend(training_resources.lproj_files)
            resource_trees.extend(training_resources.resource_trees)

    assets = generate_app_intents_nl_training_assets(
        actions = actions,
        apple_fragment = platform_prerequisites.apple_fragment,
        bundle_id = bundle_id,
        infoplist = infoplist,
        label = label,
        lproj_dirs = lproj_dirs.keys(),
        lproj_files = lproj_files,
        mac_exec_group = mac_exec_group,
        metadata_bundle = metadata_bundle,
        nl_training_tool = nl_training_tool,
        resource_trees = resource_trees,
        xcode_version_config = platform_prerequisites.xcode_version_config,
    )

    return struct(
        bundle_files = [(processor.location.resource, None, depset(direct = [assets]))],
    )

def _app_intents_metadata_bundle_partial_impl(
        *,
        actions,
        bundle_id,
        mac_exec_group,
        cc_toolchains,
        deps,
        flexible_matching,
        label,
        nl_training_tool,
        platform_prerequisites,
        json_tool):
    """Implementation of the AppIntents metadata bundle partial."""
    if not deps:
        # No `app_intents` were set by the rule calling this partial.
        return struct()

    # Mirroring Xcode 15+ behavior, the metadata tool only looks at the first split for a given arch
    # rather than every possible set of source files and inputs. Oddly, this only applies to the
    # swift source files and the swiftconstvalues files; the triples and other files do cover all
    # available archs.
    first_cc_toolchain_key = cc_toolchains.keys()[0]

    metadata_bundle = generate_app_intents_metadata_bundle(
        actions = actions,
        apple_fragment = platform_prerequisites.apple_fragment,
        constvalues_files = [
            swiftconstvalues_file
            for dep in deps[first_cc_toolchain_key]
            for swiftconstvalues_file in dep[AppIntentsInfo].swiftconstvalues_files
        ],
        intents_module_names = [
            intent_module_name
            for dep in deps[first_cc_toolchain_key]
            for intent_module_name in dep[AppIntentsInfo].intent_module_names
        ],
        label = label,
        mac_exec_group = mac_exec_group,
        platform_prerequisites = platform_prerequisites,
        source_files = [
            swift_source_file
            for dep in deps[first_cc_toolchain_key]
            for swift_source_file in dep[AppIntentsInfo].swift_source_files
        ],
        target_triples = [
            cc_toolchain[cc_common.CcToolchainInfo].target_gnu_system_name
            for cc_toolchain in cc_toolchains.values()
        ],
        xcode_version_config = platform_prerequisites.xcode_version_config,
        json_tool = json_tool,
    )

    bundle_location = processor.location.bundle
    if str(platform_prerequisites.platform_type) == "macos":
        bundle_location = processor.location.resource

    # appintentsnltrainingprocessor ships with Xcode 15 and later.
    deferred_partial = None
    xcode_version = platform_prerequisites.xcode_version_config.xcode_version()
    if (flexible_matching and bundle_id and
        xcode_version >= apple_common.dotted_version("15.0")):
        deferred_partial = partial.make(
            _app_intents_nl_training_partial_impl,
            actions = actions,
            bundle_id = bundle_id,
            label = label,
            mac_exec_group = mac_exec_group,
            metadata_bundle = metadata_bundle,
            nl_training_tool = nl_training_tool,
            platform_prerequisites = platform_prerequisites,
        )

    return struct(
        bundle_files = [(
            bundle_location,
            "Metadata.appintents",
            depset(direct = [metadata_bundle]),
        )],
        deferred_partial = deferred_partial,
    )

def app_intents_metadata_bundle_partial(
        *,
        actions,
        bundle_id = None,
        mac_exec_group,
        cc_toolchains,
        deps,
        flexible_matching = False,
        label,
        nl_training_tool = None,
        platform_prerequisites,
        json_tool):
    """Constructor for the AppIntents metadata bundle processing partial.

    This partial generates the Metadata.appintents bundle required for AppIntents functionality.
    When `flexible_matching` is True, it also generates the App Shortcuts Flexible Matching assets
    after the other partials run, since those assets depend on the merged Info.plist and the
    localized resources.

    Args:
        actions: The actions provider from ctx.actions.
        bundle_id: The bundle ID of the target. Required when `flexible_matching` is True.
        mac_exec_group: The execution group for Mac tools.
        cc_toolchains: Dictionary of CcToolchainInfo and ApplePlatformInfo providers under a split
            transition to relay target platform information.
        deps: Dictionary of targets under a split transition implementing the AppIntents protocol.
        flexible_matching: Whether to generate the App Shortcuts Flexible Matching assets.
        label: Label of the target being built.
        nl_training_tool: A `files_to_run` for the App Intents NL training tool. Required when
            `flexible_matching` is True.
        platform_prerequisites: Struct containing information on the platform being targeted.
        json_tool: A `files_to_run` wrapping Python's `json.tool` module
            (https://docs.python.org/3.5/library/json.html#module-json.tool) for deterministic
            JSON handling.
    Returns:
        A partial that generates the Metadata.appintents bundle.
    """
    return partial.make(
        _app_intents_metadata_bundle_partial_impl,
        actions = actions,
        bundle_id = bundle_id,
        cc_toolchains = cc_toolchains,
        deps = deps,
        flexible_matching = flexible_matching,
        label = label,
        mac_exec_group = mac_exec_group,
        nl_training_tool = nl_training_tool,
        platform_prerequisites = platform_prerequisites,
        json_tool = json_tool,
    )
