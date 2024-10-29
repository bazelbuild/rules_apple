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
    "AppIntentsBundleInfo",
    "AppIntentsInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/resource_actions:app_intents.bzl",
    "generate_app_intents_metadata_bundle",
)

visibility("//apple/...")

def _find_app_intents_info(*, app_intents, first_cc_toolchain_key):
    """Finds the AppIntentsInfo providers from the given app_intents.

    Args:
        app_intents: A list of dictionaries for targets under a split transition providing
            AppIntentsInfo. The only supported targets are targets provided by a label list and
            targets provided by labels from the bundle rule.
        first_cc_toolchain_key: The key for the first cc_toolchain found in the split transition.
    Returns:
        A list of all AppIntentsInfo providers that were found.
    """
    app_intents_infos = []
    for split_target in app_intents:
        if not split_target:
            continue
        if not first_cc_toolchain_key in split_target:
            continue
        split_values = split_target[first_cc_toolchain_key]
        targets = split_values if type(split_values) == "list" else [split_values]
        for target in targets:
            if AppIntentsInfo in target:
                app_intents_infos.append(target[AppIntentsInfo])
    return app_intents_infos

def _find_exclusively_owned_metadata_bundle_inputs(*, app_intents_infos, targets_to_avoid):
    """Find the metadata bundles owned by the current rule that aren't in targets to avoid.

    Args:
        app_intents_infos: A list of AppIntentsInfo providers.
        targets_to_avoid: A list of targets that should be ignored when collecting metadata bundle
            inputs.
    Returns:
        A list of metadata bundle inputs that are exclusively owned by dependencies of the current
        rule.
    """
    exclusively_owned_metadata_bundle_inputs = []

    avoid_owned_metadata_bundles = [
        x[AppIntentsBundleInfo].owned_metadata_bundles
        for x in targets_to_avoid
        if AppIntentsBundleInfo in x
    ]
    avoid_owners = [p.owner for x in avoid_owned_metadata_bundles for p in x.to_list()]

    for app_intents_info in app_intents_infos:
        for metadata_bundle_input in app_intents_info.metadata_bundle_inputs.to_list():
            if metadata_bundle_input.owner not in avoid_owners:
                exclusively_owned_metadata_bundle_inputs.append(metadata_bundle_input)

    return exclusively_owned_metadata_bundle_inputs

def _app_intents_metadata_bundle_partial_impl(
        *,
        actions,
        app_intents,
        bundle_id,
        cc_toolchains,
        embedded_bundles,
        label,
        mac_exec_group,
        platform_prerequisites,
        targets_to_avoid):
    """Implementation of the AppIntents metadata bundle partial."""

    owned_metadata_bundles = [
        x[AppIntentsBundleInfo].owned_metadata_bundles
        for x in embedded_bundles
        if AppIntentsBundleInfo in x
    ]

    # Mirroring Xcode 15+ behavior, the metadata tool only looks at the first split for a given arch
    # rather than every possible set of source files and inputs. Oddly, this only applies to the
    # swift source files and the swiftconstvalues files; the triples and other files do cover all
    # available archs.
    first_cc_toolchain_key = cc_toolchains.keys()[0]

    app_intents_infos = _find_app_intents_info(
        app_intents = app_intents,
        first_cc_toolchain_key = first_cc_toolchain_key,
    )

    if not app_intents_infos:
        # No `app_intents` were set by the rule or any of its transitive deps; just propagate the
        # embedded metadata bundles if any were found.
        if owned_metadata_bundles:
            return struct(
                providers = [AppIntentsBundleInfo(
                    owned_metadata_bundles = depset(
                        transitive = owned_metadata_bundles,
                    ),
                )],
            )
        return struct()

    # Remove deps found from dependent bundle deps before determining if we have the right number of
    # AppIntentsInfo providers. Reusing the concept of "owners" from resources, where the owner is
    # a String based on the label of the swift_library target that provided the metadata bundle.
    metadata_bundle_inputs = _find_exclusively_owned_metadata_bundle_inputs(
        app_intents_infos = app_intents_infos,
        targets_to_avoid = targets_to_avoid,
    )

    if len(metadata_bundle_inputs) != 1:
        # TODO(b/365825041): Report where the multiple app intents were defined once we relay that
        # information from the AppIntentsInfo provider for easier debugging on the user's behalf.
        fail("""
Error: Expected only one metadata bundle input for App Intents, but found {number_of_inputs} \
metadata bundle inputs instead.
""".format(
            number_of_inputs = len(metadata_bundle_inputs),
        ))

    metadata_bundle_input = metadata_bundle_inputs[0]

    metadata_bundle = generate_app_intents_metadata_bundle(
        actions = actions,
        bundle_id = bundle_id,
        constvalues_files = [
            swiftconstvalues_file
            for swiftconstvalues_file in metadata_bundle_input.swiftconstvalues_files
        ],
        intents_module_name = metadata_bundle_input.module_name,
        label = label,
        mac_exec_group = mac_exec_group,
        owned_metadata_bundles = owned_metadata_bundles,
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

    providers = [AppIntentsBundleInfo(
        owned_metadata_bundles = depset(
            direct = [struct(
                bundle = metadata_bundle,
                owner = metadata_bundle_input.owner,
            )],
            transitive = owned_metadata_bundles,
        ),
    )]

    return struct(
        bundle_files = [(
            bundle_location,
            "Metadata.appintents",
            depset(direct = [metadata_bundle]),
        )],
        providers = providers,
    )

def app_intents_metadata_bundle_partial(
        *,
        actions,
        app_intents,
        bundle_id,
        cc_toolchains,
        embedded_bundles,
        label,
        mac_exec_group,
        platform_prerequisites,
        targets_to_avoid = []):
    """Constructor for the AppIntents metadata bundle processing partial.

    This partial generates the Metadata.appintents bundle required for AppIntents functionality.

    Args:
        actions: The actions provider from ctx.actions.
        app_intents: A list of dictionaries for targets under a split transition providing
            AppIntentsInfo.
        bundle_id: The bundle ID to configure for this target.
        cc_toolchains: Dictionary of CcToolchainInfo and ApplePlatformInfo providers under a split
            transition to relay target platform information.
        embedded_bundles: A list of targets that can propagate app intents metadata bundles.
        label: Label of the target being built.
        mac_exec_group: A String. The exec_group for actions using the mac toolchain.
        platform_prerequisites: Struct containing information on the platform being targeted.
        targets_to_avoid: A list of targets that should be ignored when collecting metadata bundle
            inputs.
    Returns:
        A partial that generates the Metadata.appintents bundle.
    """
    return partial.make(
        _app_intents_metadata_bundle_partial_impl,
        actions = actions,
        app_intents = app_intents,
        bundle_id = bundle_id,
        embedded_bundles = embedded_bundles,
        cc_toolchains = cc_toolchains,
        label = label,
        mac_exec_group = mac_exec_group,
        platform_prerequisites = platform_prerequisites,
        targets_to_avoid = targets_to_avoid,
    )
