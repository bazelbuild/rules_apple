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

_APP_INTENTS_HINT_TARGET = "@build_bazel_rules_apple//apple/hints:app_intents_hint"

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

def _find_exclusively_owned_metadata_bundle_input(*, app_intents_infos, label, targets_to_avoid):
    """Find the expected metadata bundle owned by the current rule that isn't in targets to avoid.

    Args:
        app_intents_infos: A list of AppIntentsInfo providers.
        label: The label of the current rule.
        targets_to_avoid: A list of targets that should be ignored when collecting metadata bundle
            inputs.
    Returns:
        A single metadata bundle input that is exclusively owned by dependencies of the current
        rule if it exists. If more than one exclusively owned metadata bundle input was found, or
        if no exclusively owned metadata bundle input was found, a failure is reported to the user.
    """
    metadata_bundle_inputs = []

    avoid_owned_metadata_bundles = [
        x[AppIntentsBundleInfo].owned_metadata_bundles
        for x in targets_to_avoid
        if AppIntentsBundleInfo in x
    ]
    avoid_owners = [p.owner for x in avoid_owned_metadata_bundles for p in x.to_list()]

    for app_intents_info in app_intents_infos:
        for metadata_bundle_input in app_intents_info.metadata_bundle_inputs.to_list():
            if metadata_bundle_input.owner not in avoid_owners:
                metadata_bundle_inputs.append(metadata_bundle_input)

    if len(metadata_bundle_inputs) == 0:
        fail("""
Error: Expected one swift_library defining App Intents exclusive to the given top level Apple \
target at {label}, but only found {number_of_inputs} targets defining App Intents owned by \
frameworks.

App Intents bundles were defined by the following framework-referenced targets:
- {bundle_owners}

Please ensure that a single "swift_library" target is marked as providing App Intents metadata \
exclusively to the given top level Apple target via the "aspect_hints" attribute with \
{app_intents_hint_target}.
""".format(
            app_intents_hint_target = _APP_INTENTS_HINT_TARGET,
            bundle_owners = "\n- ".join(avoid_owners),
            label = str(label),
            number_of_inputs = len(avoid_owners),
        ))
    elif len(metadata_bundle_inputs) != 1:
        fail("""
Error: Expected only one swift_library defining App Intents exclusive to the given top level Apple \
target at {label}, but found {number_of_inputs} targets defining App Intents instead.

App Intents bundles were defined by the following targets:
- {bundle_owners}

Please ensure that only a single "swift_library" target is marked as providing App Intents \
metadata exclusively to the given top level Apple target via the "aspect_hints" attribute with \
{app_intents_hint_target}.

App Intents can also be shared via AppIntentsPackage APIs from a dynamic framework to apps, \
extensions and other frameworks in Xcode 16+. Please refer to the Apple App Intents documentation \
for more information: https://developer.apple.com/documentation/appintents/appintentspackage
""".format(
            app_intents_hint_target = _APP_INTENTS_HINT_TARGET,
            bundle_owners = "\n- ".join([x.owner for x in metadata_bundle_inputs]),
            label = str(label),
            number_of_inputs = len(metadata_bundle_inputs),
        ))

    return metadata_bundle_inputs[0]

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
    metadata_bundle_input = _find_exclusively_owned_metadata_bundle_input(
        app_intents_infos = app_intents_infos,
        label = label,
        targets_to_avoid = targets_to_avoid,
    )

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
