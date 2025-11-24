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
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

visibility("@build_bazel_rules_apple//apple/...")

_APP_INTENTS_HINT_TARGET = "@build_bazel_rules_apple//apple/hints:app_intents_hint"
_APP_INTENTS_HINT_DOCS = "See the aspect hint rule documentation for more information."
_LEGACY_APP_INTENTS_ALLOWLIST = []

def _find_app_intents_info(*, app_intents, first_cc_toolchain_key, label):
    """Finds the AppIntentsInfo providers from the given app_intents.

    Args:
        app_intents: A list of dictionaries for targets under a split transition providing
            AppIntentsInfo. The only supported targets are targets provided by a label list and
            targets provided by labels from the bundle rule.
        first_cc_toolchain_key: The key for the first cc_toolchain found in the split transition.
        label: The label of the current rule.
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
        if type(split_values) != "list":
            # TODO(b/377974185): Remove this messaging once the legacy app_intents attribute is
            # cleaned up.
            #
            # Emit a warning if the legacy app_intents attribute is used; we currently fall on the
            # assumption that if the input was not a list (i.e. from "deps"), it's "app_intents",
            # which takes in only a single label referencing a BUILD target.

            legacy_app_intents_message = """Found app intents defined through the legacy \
app_intents attribute on the target at {label}.

Please define app intents by assigning {app_intents_hint_target} via the referenced \
swift_library's "aspect_hints" attribute instead, and remove the existing reference to the \
swift_library target from the deprecated app_intents attribute found at {label}.

{app_intents_hint_docs}
"""
            if str(label) not in _LEGACY_APP_INTENTS_ALLOWLIST:
                fail("\nERROR: " + legacy_app_intents_message.format(
                    app_intents_hint_docs = _APP_INTENTS_HINT_DOCS,
                    app_intents_hint_target = _APP_INTENTS_HINT_TARGET,
                    label = str(label),
                ))
            else:
                # buildifier: disable=print
                print("\nWARNING: " + legacy_app_intents_message.format(
                    app_intents_hint_docs = _APP_INTENTS_HINT_DOCS,
                    app_intents_hint_target = _APP_INTENTS_HINT_TARGET,
                    label = str(label),
                ))

        targets = split_values if type(split_values) == "list" else [split_values]
        for target in targets:
            if AppIntentsInfo in target:
                app_intents_infos.append(target[AppIntentsInfo])
    return app_intents_infos

def _find_exclusively_owned_metadata_bundle_inputs(
        *,
        app_intents_infos,
        enable_wip_features,
        label,
        metadata_bundles_to_avoid):
    """Find the expected metadata bundle owned by the current rule that isn't in targets to avoid.

    Args:
        app_intents_infos: A list of AppIntentsInfo providers.
        enable_wip_features: Whether to enable WIP features.
        label: The label of the current rule.
        metadata_bundles_to_avoid: A list of metadata bundles that should be ignored, typically
            because they are owned by frameworks.
    Returns:
        A single metadata bundle input that is exclusively owned by dependencies of the current
        rule if it exists. If more than one exclusively owned metadata bundle input was found, or
        if no exclusively owned metadata bundle input was found, a failure is reported to the user.
    """
    owned_metadata_bundle_inputs = []

    avoid_owners = [x.owner for x in metadata_bundles_to_avoid]

    # Use a transitive depset to remove incoming duplicates.
    metadata_bundle_inputs = depset(
        transitive = [
            app_intents_info.metadata_bundle_inputs
            for app_intents_info in app_intents_infos
        ],
        order = "topological",
    )

    for metadata_bundle_input in metadata_bundle_inputs.to_list():
        owner = metadata_bundle_input.owner
        if owner not in avoid_owners:
            owned_metadata_bundle_inputs.append(metadata_bundle_input)

    if len(owned_metadata_bundle_inputs) == 0:
        fail("""
Error: Expected one swift_library defining App Intents exclusive to the given top level Apple \
target at {label}, but only found {number_of_inputs} targets defining App Intents owned by \
frameworks.

App Intents bundles were defined by the following framework-referenced targets:
- {bundle_owners}

Please ensure that a single "swift_library" target is marked as providing App Intents metadata \
exclusively to the given top level Apple target via the "aspect_hints" attribute with \
{app_intents_hint_target}.

{app_intents_hint_docs}
""".format(
            app_intents_hint_docs = _APP_INTENTS_HINT_DOCS,
            app_intents_hint_target = _APP_INTENTS_HINT_TARGET,
            bundle_owners = "\n- ".join(avoid_owners),
            label = str(label),
            number_of_inputs = len(avoid_owners),
        ))
    elif len(owned_metadata_bundle_inputs) != 1 and not enable_wip_features:
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

{app_intents_hint_docs}
""".format(
            app_intents_hint_docs = _APP_INTENTS_HINT_DOCS,
            app_intents_hint_target = _APP_INTENTS_HINT_TARGET,
            bundle_owners = "\n- ".join([x.owner for x in owned_metadata_bundle_inputs]),
            label = str(label),
            number_of_inputs = len(owned_metadata_bundle_inputs),
        ))

    return owned_metadata_bundle_inputs

def _app_intents_metadata_bundle_partial_impl(
        *,
        actions,
        app_intents,
        apple_mac_toolchain_info,
        apple_xplat_toolchain_info,
        bundle_id,
        cc_toolchains,
        frameworks,
        embedded_bundles,
        label,
        mac_exec_group,
        platform_prerequisites):
    """Implementation of the AppIntents metadata bundle partial."""

    owned_embedded_metadata_bundles = [
        x[AppIntentsBundleInfo].owned_metadata_bundles
        for x in embedded_bundles
        if AppIntentsBundleInfo in x
    ]

    # Mirroring Xcode 15.x behavior, the metadata tool only looks at the first split for a given
    # arch rather than every possible set of source files and inputs. Oddly, this only applies to
    # the Swift source files and the swiftconstvalues files; the triples and other files do cover
    # all available architectures.
    #
    # This was changed in Xcode 16.x to consider every architecture, effectively doubling or
    # tripling the number of files that must be processed and validated. but the utility is unclear
    # at this time.
    first_cc_toolchain_key = cc_toolchains.keys()[0]

    app_intents_infos = _find_app_intents_info(
        app_intents = app_intents,
        first_cc_toolchain_key = first_cc_toolchain_key,
        label = label,
    )

    if not app_intents_infos:
        # No `app_intents` were set by the rule or any of its transitive deps; just propagate the
        # embedded metadata bundles if any were found.
        if owned_embedded_metadata_bundles:
            return struct(
                providers = [AppIntentsBundleInfo(
                    owned_metadata_bundles = depset(
                        transitive = owned_embedded_metadata_bundles,
                        order = "topological",
                    ),
                )],
            )
        return struct()

    enable_wip_features = apple_xplat_toolchain_info.build_settings.enable_wip_features

    # Remove deps found from dependent bundle deps before determining if we have the right number of
    # AppIntentsInfo providers. Reusing the concept of "owners" from resources, where the owner is
    # a String based on the label of the swift_library target that provided the metadata bundle.
    metadata_bundle_inputs = _find_exclusively_owned_metadata_bundle_inputs(
        app_intents_infos = app_intents_infos,
        enable_wip_features = enable_wip_features,
        label = label,
        metadata_bundles_to_avoid = [
            p
            for x in frameworks
            if AppIntentsBundleInfo in x
            for p in x[AppIntentsBundleInfo].owned_metadata_bundles.to_list()
        ],
    )

    target_triples = [
        cc_toolchain[cc_common.CcToolchainInfo].target_gnu_system_name
        for cc_toolchain in cc_toolchains.values()
    ]

    static_library_metadata_bundle_outputs = []
    for metadata_bundle_input in metadata_bundle_inputs[:-1]:
        # Generate bundles for static libraries with the same bundle identifier as the main bundle.
        static_library_metadata_bundle_outputs.append(
            generate_app_intents_metadata_bundle(
                actions = actions,
                apple_mac_toolchain_info = apple_mac_toolchain_info,
                bundle_id = bundle_id,
                constvalues_files = metadata_bundle_input.swiftconstvalues_files,
                direct_app_intents_modules = [
                    x
                    for x in static_library_metadata_bundle_outputs
                    if x.module_name in metadata_bundle_input.direct_app_intents_modules
                ],
                embedded_metadata_bundles = owned_embedded_metadata_bundles,
                enable_package_validation = False,
                intents_module_name = metadata_bundle_input.module_name,
                label = label,
                mac_exec_group = mac_exec_group,
                main_bundle_output = False,
                owner = metadata_bundle_input.owner,
                platform_prerequisites = platform_prerequisites,
                source_files = metadata_bundle_input.swift_source_files,
                target_triples = target_triples,
            ),
        )

    # The last one found - and "nearest" to the top level target - will be our "main" metadata
    # bundle. This will also be the metadata bundle that other top level bundles will have to
    # declare dependencies on whether this is an extension or a framework per Xcode 16+ behavior.
    main_metadata_bundle_input = metadata_bundle_inputs[-1]
    metadata_bundle_output = generate_app_intents_metadata_bundle(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        bundle_id = bundle_id,
        constvalues_files = main_metadata_bundle_input.swiftconstvalues_files,
        direct_app_intents_modules = [
            x
            for x in static_library_metadata_bundle_outputs
            if x.module_name in main_metadata_bundle_input.direct_app_intents_modules
        ],
        embedded_metadata_bundles = owned_embedded_metadata_bundles,
        enable_package_validation = False,
        intents_module_name = main_metadata_bundle_input.module_name,
        label = label,
        mac_exec_group = mac_exec_group,
        main_bundle_output = True,
        owner = main_metadata_bundle_input.owner,
        platform_prerequisites = platform_prerequisites,
        source_files = main_metadata_bundle_input.swift_source_files,
        target_triples = target_triples,
    )

    bundle_location = processor.location.bundle
    if platform_prerequisites.platform_type == "macos":
        bundle_location = processor.location.resource

    providers = [AppIntentsBundleInfo(
        owned_metadata_bundles = depset(
            direct = static_library_metadata_bundle_outputs + [metadata_bundle_output],
            transitive = owned_embedded_metadata_bundles,
            order = "topological",
        ),
    )]

    return struct(
        bundle_files = [(
            bundle_location,
            "Metadata.appintents",
            depset(direct = [metadata_bundle_output.bundle]),
        )],
        providers = providers,
    )

def app_intents_metadata_bundle_partial(
        *,
        actions,
        app_intents,
        apple_mac_toolchain_info,
        apple_xplat_toolchain_info,
        bundle_id,
        cc_toolchains,
        embedded_bundles,
        frameworks = [],
        label,
        mac_exec_group,
        platform_prerequisites):
    """Constructor for the AppIntents metadata bundle processing partial.

    This partial generates the Metadata.appintents bundle required for AppIntents functionality.

    Args:
        actions: The actions provider from ctx.actions.
        app_intents: A list of dictionaries for targets under a split transition providing
            AppIntentsInfo.
        apple_mac_toolchain_info: `struct` of tools from the shared Apple Mac toolchain.
        apple_xplat_toolchain_info: `struct` of tools from the shared Apple Xplat toolchain.
        bundle_id: The bundle ID to configure for this target.
        cc_toolchains: Dictionary of CcToolchainInfo and ApplePlatformInfo providers under a split
            transition to relay target platform information.
        embedded_bundles: A list of targets that can propagate app intents metadata bundles.
        frameworks: A list of framework targets that are dependencies of the current target. These
            will be a subset of the embedded_bundles.
        label: Label of the target being built.
        mac_exec_group: A String. The exec_group for actions using the mac toolchain.
        platform_prerequisites: Struct containing information on the platform being targeted.
    Returns:
        A partial that generates the Metadata.appintents bundle.
    """
    return partial.make(
        _app_intents_metadata_bundle_partial_impl,
        actions = actions,
        app_intents = app_intents,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_id = bundle_id,
        embedded_bundles = embedded_bundles,
        frameworks = frameworks,
        cc_toolchains = cc_toolchains,
        label = label,
        mac_exec_group = mac_exec_group,
        platform_prerequisites = platform_prerequisites,
    )
