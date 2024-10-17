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
load("@build_bazel_rules_apple//apple/internal:processor.bzl", "processor")
load(
    "@build_bazel_rules_apple//apple/internal/providers:app_intents_info.bzl",
    "AppIntentsInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/resource_actions:app_intents.bzl",
    "generate_app_intents_metadata_bundle",
)

visibility("//apple/...")

def _app_intents_metadata_bundle_partial_impl(
        *,
        actions,
        app_intent,
        cc_toolchains,
        label,
        mac_exec_group,
        platform_prerequisites):
    """Implementation of the AppIntents metadata bundle partial."""
    if not app_intent:
        # No `app_intents` were set by the rule calling this partial.
        return struct()

    # Mirroring Xcode 15+ behavior, the metadata tool only looks at the first split for a given arch
    # rather than every possible set of source files and inputs. Oddly, this only applies to the
    # swift source files and the swiftconstvalues files; the triples and other files do cover all
    # available archs.
    first_cc_toolchain_key = cc_toolchains.keys()[0]
    first_app_intents_info = app_intent[first_cc_toolchain_key][AppIntentsInfo]

    metadata_bundle_inputs = first_app_intents_info.metadata_bundle_inputs.to_list()
    if len(metadata_bundle_inputs) != 1:
        fail("""
Internal Error: Expected only one metadata bundle input for App Intents, but found \
{number_of_inputs} metadata bundle inputs instead.

Please file an issue with the Apple BUILD rules with repro steps.
""".format(
            number_of_inputs = len(metadata_bundle_inputs),
        ))

    # TODO(b/365825041): Support App Intents from multiple modules, starting with frameworks.
    metadata_bundle_input = metadata_bundle_inputs[0]

    metadata_bundle = generate_app_intents_metadata_bundle(
        actions = actions,
        constvalues_files = [
            swiftconstvalues_file
            for swiftconstvalues_file in metadata_bundle_input.swiftconstvalues_files
        ],
        intents_module_name = metadata_bundle_input.module_name,
        label = label,
        mac_exec_group = mac_exec_group,
        platform_prerequisites = platform_prerequisites,
        source_files = [
            swift_source_file
            for swift_source_file in metadata_bundle_input.swift_source_files
        ],
        target_triples = [
            cc_toolchain[cc_common.CcToolchainInfo].target_gnu_system_name
            for cc_toolchain in cc_toolchains.values()
        ],
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
        app_intent,
        cc_toolchains,
        label,
        mac_exec_group,
        platform_prerequisites):
    """Constructor for the AppIntents metadata bundle processing partial.

    This partial generates the Metadata.appintents bundle required for AppIntents functionality.

    Args:
        actions: The actions provider from ctx.actions.
        app_intent: Dictionary for one target under a split transition implementing the AppIntents
            protocol.
        cc_toolchains: Dictionary of CcToolchainInfo and ApplePlatformInfo providers under a split
            transition to relay target platform information.
        label: Label of the target being built.
        mac_exec_group: A String. The exec_group for actions using the mac toolchain.
        platform_prerequisites: Struct containing information on the platform being targeted.
    Returns:
        A partial that generates the Metadata.appintents bundle.
    """
    return partial.make(
        _app_intents_metadata_bundle_partial_impl,
        actions = actions,
        app_intent = app_intent,
        cc_toolchains = cc_toolchains,
        label = label,
        mac_exec_group = mac_exec_group,
        platform_prerequisites = platform_prerequisites,
    )
