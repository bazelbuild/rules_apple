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
load("//apple/internal:processor.bzl", "processor")
load(
    "//apple/internal/providers:app_intents_info.bzl",
    "AppIntentsInfo",
)
load(
    "//apple/internal/resource_actions:app_intents.bzl",
    "generate_app_intents_metadata_bundle",
)

def _app_intents_metadata_bundle_partial_impl(
        *,
        actions,
        cc_toolchains,
        deps,
        label,
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
        deps,
        label,
        platform_prerequisites,
        json_tool):
    """Constructor for the AppIntents metadata bundle processing partial.

    This partial generates the Metadata.appintents bundle required for AppIntents functionality.

    Args:
        actions: The actions provider from ctx.actions.
        cc_toolchains: Dictionary of CcToolchainInfo and ApplePlatformInfo providers under a split
            transition to relay target platform information.
        deps: Dictionary of targets under a split transition implementing the AppIntents protocol.
        label: Label of the target being built.
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
        cc_toolchains = cc_toolchains,
        deps = deps,
        label = label,
        platform_prerequisites = platform_prerequisites,
        json_tool = json_tool,
    )
