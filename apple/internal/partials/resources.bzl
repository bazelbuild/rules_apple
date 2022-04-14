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

"""Partial implementations for resource processing.

Resources are procesed according to type, by a series of methods that deal with the specifics for
each resource type. Each of this methods returns a struct, which always have a `files` field
containing resource tuples as described in processor.bzl. Optionally, the structs can also have an
`infoplists` field containing a list of plists that should be merged into the root Info.plist.
"""

load(
    "@build_bazel_rules_apple//apple/internal/partials/support:resources_support.bzl",
    "resources_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:bundle_paths.bzl",
    "bundle_paths",
)
load(
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/internal:outputs.bzl",
    "outputs",
)
load(
    "@build_bazel_rules_apple//apple/internal:processor.bzl",
    "processor",
)
load(
    "@build_bazel_rules_apple//apple/internal:resource_actions.bzl",
    "resource_actions",
)
load(
    "@build_bazel_rules_apple//apple/internal:resources.bzl",
    "CACHEABLE_PROVIDER_FIELD_TO_ACTION",
    "resources",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
    "AppleResourceInfo",
)
load(
    "@bazel_skylib//lib:new_sets.bzl",
    "sets",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)

_PROCESSED_FIELDS = CACHEABLE_PROVIDER_FIELD_TO_ACTION.keys()

def _merge_root_infoplists(
        *,
        actions,
        out_infoplist,
        output_discriminator,
        rule_descriptor,
        rule_label,
        **kwargs):
    """Registers the root Info.plist generation action.

    Args:
      actions: The actions provider from `ctx.actions`.
      out_infoplist: Reference to the output Info plist.
      output_discriminator: A string to differentiate between different target intermediate files
          or `None`.
      rule_descriptor: A rule descriptor for platform and product types from the rule context.
      rule_label: The label of the target being analyzed.
      **kwargs: Extra parameters forwarded into the merge_root_infoplists action.

    Returns:
      A list of tuples as described in processor.bzl with the Info.plist file
      reference and the PkgInfo file if required.
    """
    files = [out_infoplist]

    out_pkginfo = None
    if rule_descriptor.requires_pkginfo:
        out_pkginfo = intermediates.file(
            actions = actions,
            target_name = rule_label.name,
            output_discriminator = output_discriminator,
            file_name = "PkgInfo",
        )
        files.append(out_pkginfo)

    resource_actions.merge_root_infoplists(
        actions = actions,
        output_discriminator = output_discriminator,
        output_plist = out_infoplist,
        output_pkginfo = out_pkginfo,
        rule_descriptor = rule_descriptor,
        rule_label = rule_label,
        **kwargs
    )

    return [(processor.location.content, None, depset(direct = files))]

def _expand_owners(*, owners):
    """Converts a depset of (path, owner) to a dict of paths to dict of owners.

    Args:
      owners: A depset of (path, owner) pairs.
    """
    dict = {}
    for resource, owner in owners.to_list():
        if owner:
            dict.setdefault(resource, default = {})[owner] = None
    return dict

def _expand_processed_origins(*, processed_origins):
    """Converts a depset of (processed_resource, resource) to a dict.

    Args:
      processed_origins: A depset of (processed_resource, resource) pairs.
    """
    processed_origins_dict = {}
    for processed_resource, resource in processed_origins.to_list():
        processed_origins_dict[processed_resource] = resource
    return processed_origins_dict

def _deduplicate(
        *,
        avoid_owners,
        avoid_provider,
        field,
        owners,
        processed_origins,
        processed_deduplication_map,
        resources_provider):
    """Deduplicates and returns resources between 2 providers for a given field.

    Deduplication happens by comparing the target path of a file and the files
    themselves. If there are 2 resources with the same target path but different
    contents, the files will not be deduplicated.

    This approach is naïve in the sense that it deduplicates resources too
    aggressively. We also need to compare the target that references the
    resources so that they are not deduplicated if they are referenced within
    multiple binary-containing bundles.

    Args:
      avoid_owners: The owners map for avoid_provider computed by _expand_owners.
      avoid_provider: The provider with the resources to avoid bundling.
      field: The field to deduplicate resources on.
      resources_provider: The provider with the resources to be bundled.
      owners: The owners map for resources_provider computed by _expand_owners.
      processed_origins: The processed resources map for resources_provider computed by
          _expand_processed_origins.
      processed_deduplication_map: A dictionary of keys to lists of short paths referencing already-
          deduplicated resources that can be referenced by the resource processing aspect to avoid
          duplicating files referenced by library targets and top level targets.

    Returns:
      A list of tuples with the resources present in avoid_providers removed from
      resources_providers.
    """

    avoid_dict = {}
    if avoid_provider and hasattr(avoid_provider, field):
        for parent_dir, swift_module, files in getattr(avoid_provider, field):
            key = "%s_%s" % (parent_dir or "root", swift_module or "root")
            avoid_dict[key] = {x.short_path: None for x in files.to_list()}

    # Get the resources to keep, compare them to the avoid_dict under the same
    # key, and remove the duplicated file references. Then recreate the original
    # tuple with only the remaining files, if any.
    deduped_tuples = []

    for parent_dir, swift_module, files in getattr(resources_provider, field):
        key = "%s_%s" % (parent_dir or "root", swift_module or "root")

        # Dictionary used as a set to mark files as processed by short_path to deduplicate generated
        # files that may appear more than once if multiple architectures are being built.
        multi_architecture_deduplication_set = {}

        # Update the deduplication map for this key, representing the domain of this library
        # processable resource in bundling, and use that as our deduplication list for library
        # processable resources.
        if not processed_deduplication_map.get(key, None):
            processed_deduplication_map[key] = []
        processed_deduplication_list = processed_deduplication_map[key]

        deduped_files = []
        for to_bundle_file in files.to_list():
            short_path = to_bundle_file.short_path
            if short_path in multi_architecture_deduplication_set:
                continue
            multi_architecture_deduplication_set[short_path] = None
            if key in avoid_dict and short_path in avoid_dict[key]:
                # If the resource file is present in the provider of resources to avoid, we compare
                # the owners of the resource through the owners dictionaries of the providers. If
                # there are owners present in resources_provider which are not present in
                # avoid_provider, it means that there is at least one target that declares usage of
                # the resource which is not accounted for in avoid_provider. If this is the case, we
                # add the resource to be bundled in the bundle represented by resource_provider.
                deduped_owners = [
                    o
                    for o in owners[short_path]
                    if o not in avoid_owners[short_path]
                ]
                if not deduped_owners:
                    continue

            if field == "processed":
                # Check for duplicates referencing our map of where the processed resources were
                # based from.
                path_origins = processed_origins[short_path]
                if path_origins in processed_deduplication_list:
                    continue
                processed_deduplication_list.append(path_origins)
            elif field in _PROCESSED_FIELDS:
                # Check for duplicates across fields that can be processed by a resource aspect, to
                # avoid dupes between top-level fields and fields processed by the resource aspect.
                all_path_origins = [
                    path_origin
                    for path_origins in processed_deduplication_list
                    for path_origin in path_origins
                ]
                if short_path in all_path_origins:
                    continue
                processed_deduplication_list.append([short_path])

            deduped_files.append(to_bundle_file)

        if deduped_files:
            deduped_tuples.append((parent_dir, swift_module, depset(deduped_files)))

    return deduped_tuples

def _locales_requested(*, config_vars):
    """Determines which locales to include when resource actions.

    If the user has specified "apple.locales_to_include" we use those. Otherwise we don't filter.
    'Base' is included by default to any given list of locales to include.

    Args:
        config_vars: A dictionary (String to String) of config variables. Typically from `ctx.var`.

    Returns:
        A set of locales to include or None if all should be included.
    """
    requested_locales = config_vars.get("apple.locales_to_include")
    if requested_locales != None:
        return sets.make(["Base"] + [x.strip() for x in requested_locales.split(",")])
    else:
        return None

def _validate_processed_locales(*, label, locales_dropped, locales_included, locales_requested):
    """Prints a warning if locales were dropped and none of the requested ones were included."""
    if sets.length(locales_dropped):
        # Display a warning if a locale was dropped and there are unfulfilled locale requests; it
        # could mean that the user made a mistake in defining the locales they want to keep.
        if not sets.is_equal(locales_requested, locales_included):
            unused_locales = sets.difference(locales_requested, locales_included)

            # There is no way to issue a warning, so print is the only way
            # to message.
            # buildifier: disable=print
            print("Warning: " + str(label) + " did not have resources that matched " +
                  sets.str(unused_locales) + " in locale filter. Please verify " +
                  "apple.locales_to_include is defined properly.")

def _resources_partial_impl(
        *,
        actions,
        apple_mac_toolchain_info,
        bundle_extension,
        bundle_id,
        bundle_name,
        executable_name,
        bundle_verification_targets,
        environment_plist,
        launch_storyboard,
        output_discriminator,
        platform_prerequisites,
        resource_deps,
        rule_descriptor,
        rule_label,
        top_level_infoplists,
        top_level_resources,
        targets_to_avoid,
        version,
        version_keys_required):
    """Implementation for the resource processing partial."""
    providers = []

    if resource_deps:
        providers.extend([
            x[AppleResourceInfo]
            for x in resource_deps
            if AppleResourceInfo in x
        ])

    if top_level_resources:
        providers.append(resources.bucketize(
            owner = str(rule_label),
            resources = top_level_resources,
        ))

    if top_level_infoplists:
        providers.append(resources.bucketize_typed(
            top_level_infoplists,
            owner = str(rule_label),
            bucket_type = "infoplists",
        ))

    if not providers:
        # If there are no resource providers, return early, since there is nothing to process.
        # Most rules will always have at least one resource since they have a mandatory infoplists
        # attribute, but not ios_static_framework. This rule can be perfectly valid without any
        # resource.
        return struct()

    final_provider = resources.merge_providers(
        default_owner = str(rule_label),
        providers = providers,
    )

    avoid_providers = [
        x[AppleResourceInfo]
        for x in targets_to_avoid
        if AppleResourceInfo in x
    ]

    avoid_provider = None
    if avoid_providers:
        # Call merge_providers with validate_all_resources_owned set, to ensure that all the
        # resources from dependency bundles have an owner.
        avoid_provider = resources.merge_providers(
            providers = avoid_providers,
            validate_all_resources_owned = True,
        )

    # Map of resource provider fields to a tuple that contains the method to use to process those
    # resources and a boolean indicating whether the Swift module is required for that processing.
    provider_field_to_action = {
        "asset_catalogs": (resources_support.asset_catalogs, False),
        "datamodels": (resources_support.datamodels, True),
        "infoplists": (resources_support.infoplists, False),
        "metals": (resources_support.metals, False),
        "mlmodels": (resources_support.mlmodels, False),
        "plists": (resources_support.plists_and_strings, False),
        "pngs": (resources_support.pngs, False),
        "processed": (resources_support.noop, False),
        "storyboards": (resources_support.storyboards, True),
        "strings": (resources_support.plists_and_strings, False),
        "texture_atlases": (resources_support.texture_atlases, False),
        "unprocessed": (resources_support.noop, False),
        "xibs": (resources_support.xibs, True),
    }

    # List containing all the files that the processor will bundle in their
    # configured location.
    bundle_files = []

    fields = resources.populated_resource_fields(final_provider)

    infoplists = []

    locales_requested = _locales_requested(config_vars = platform_prerequisites.config_vars)
    locales_included = sets.make(["Base"])
    locales_dropped = sets.make()

    # Precompute owners, avoid_owners and processed_origins to avoid duplicate work in _deduplicate.
    # Build a dictionary with the file paths under each key for the avoided resources.
    avoid_owners = {}
    if avoid_provider:
        avoid_owners = _expand_owners(owners = avoid_provider.owners)
    owners = _expand_owners(owners = final_provider.owners)
    if final_provider.processed_origins:
        processed_origins = _expand_processed_origins(
            processed_origins = final_provider.processed_origins,
        )
    else:
        processed_origins = {}

    # Create the deduplication map for library processable resources to be referenced across fields
    # for the purposes of deduplicating top level resources and multiple library scoped resources.
    processed_deduplication_map = {}

    for field in fields:
        deduplicated = _deduplicate(
            avoid_owners = avoid_owners,
            avoid_provider = avoid_provider,
            field = field,
            owners = owners,
            processed_origins = processed_origins,
            processed_deduplication_map = processed_deduplication_map,
            resources_provider = final_provider,
        )
        processing_func, requires_swift_module = provider_field_to_action[field]
        for parent_dir, swift_module, files in deduplicated:
            if locales_requested:
                locale = bundle_paths.locale_for_path(parent_dir)
                if sets.contains(locales_requested, locale):
                    sets.insert(locales_included, locale)
                elif locale != None:
                    sets.insert(locales_dropped, locale)
                    continue

            processing_args = {
                "actions": actions,
                "apple_mac_toolchain_info": apple_mac_toolchain_info,
                "bundle_id": bundle_id,
                "files": files,
                "output_discriminator": output_discriminator,
                "parent_dir": parent_dir,
                "platform_prerequisites": platform_prerequisites,
                "product_type": rule_descriptor.product_type,
                "rule_label": rule_label,
            }

            # Only pass the Swift module name if the type of resource to process
            # requires it.
            if requires_swift_module:
                processing_args["swift_module"] = swift_module

            result = processing_func(**processing_args)
            bundle_files.extend(result.files)
            if hasattr(result, "infoplists"):
                infoplists.extend(result.infoplists)

    if locales_requested:
        _validate_processed_locales(
            label = rule_label,
            locales_dropped = locales_dropped,
            locales_included = locales_included,
            locales_requested = locales_requested,
        )

    if bundle_id:
        # If no bundle ID was given, do not process the root Info.plist and do not validate embedded
        # bundles.
        bundle_verification_infoplists = [
            b.target[AppleBundleInfo].infoplist
            for b in bundle_verification_targets
        ]

        bundle_verification_required_values = [
            (
                b.target[AppleBundleInfo].infoplist,
                [[b.parent_bundle_id_reference, bundle_id]],
            )
            for b in bundle_verification_targets
            if hasattr(b, "parent_bundle_id_reference")
        ]

        out_infoplist = outputs.infoplist(
            actions = actions,
            label_name = rule_label.name,
            output_discriminator = output_discriminator,
        )
        bundle_files.extend(
            _merge_root_infoplists(
                actions = actions,
                bundle_extension = bundle_extension,
                bundle_id = bundle_id,
                bundle_name = bundle_name,
                executable_name = executable_name,
                child_plists = bundle_verification_infoplists,
                child_required_values = bundle_verification_required_values,
                environment_plist = environment_plist,
                input_plists = infoplists,
                launch_storyboard = launch_storyboard,
                out_infoplist = out_infoplist,
                output_discriminator = output_discriminator,
                platform_prerequisites = platform_prerequisites,
                resolved_plisttool = apple_mac_toolchain_info.resolved_plisttool,
                rule_descriptor = rule_descriptor,
                rule_label = rule_label,
                version = version,
                version_keys_required = version_keys_required,
            ),
        )

    return struct(bundle_files = bundle_files, providers = [final_provider])

def resources_partial(
        *,
        actions,
        apple_mac_toolchain_info,
        bundle_extension,
        bundle_id = None,
        bundle_name,
        executable_name,
        bundle_verification_targets = [],
        environment_plist,
        launch_storyboard,
        output_discriminator = None,
        platform_prerequisites,
        resource_deps,
        rule_descriptor,
        rule_label,
        targets_to_avoid = [],
        top_level_infoplists = [],
        top_level_resources = [],
        version,
        version_keys_required = True):
    """Constructor for the resources processing partial.

    This partial collects and propagates all resources that should be bundled in the target being
    processed.

    Args:
        actions: The actions provider from `ctx.actions`.
        apple_mac_toolchain_info: `struct` of tools from the shared Apple toolchain.
        bundle_extension: The extension for the bundle.
        bundle_id: Optional bundle ID to use when processing resources. If no bundle ID is given,
            the bundle will not contain a root Info.plist and no embedded bundle verification will
            occur.
        bundle_name: The name of the output bundle.
        executable_name: The name of the output executable.
        bundle_verification_targets: List of structs that reference embedable targets that need to
            be validated. The structs must have a `target` field with the target containing an
            Info.plist file that will be validated. The structs may also have a
            `parent_bundle_id_reference` field that contains the plist path, in list form, to the
            plist entry that must contain this target's bundle ID.
        environment_plist: File referencing a plist with the required variables about the versions
            the target is being built for and with.
        launch_storyboard: A file to be used as a launch screen for the application.
        output_discriminator: A string to differentiate between different target intermediate files
            or `None`.
        platform_prerequisites: Struct containing information on the platform being targeted.
        resource_deps: A list of dependencies that the resource aspect has been applied to.
        rule_descriptor: A rule descriptor for platform and product types from the rule context.
        rule_label: The label of the target being analyzed.
        targets_to_avoid: List of targets containing resources that should be deduplicated from the
            target being processed.
        top_level_infoplists: A list of collected resources found from Info.plist attributes.
        top_level_resources: A list of collected resources found from resource attributes.
        version: A label referencing AppleBundleVersionInfo, if provided by the rule.
        version_keys_required: Whether to validate that the Info.plist version keys are correctly
            configured.

    Returns:
        A partial that returns the bundle location of the resources and the resources provider.
    """
    return partial.make(
        _resources_partial_impl,
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_id = bundle_id,
        bundle_name = bundle_name,
        executable_name = executable_name,
        bundle_verification_targets = bundle_verification_targets,
        environment_plist = environment_plist,
        launch_storyboard = launch_storyboard,
        output_discriminator = output_discriminator,
        platform_prerequisites = platform_prerequisites,
        resource_deps = resource_deps,
        rule_descriptor = rule_descriptor,
        rule_label = rule_label,
        targets_to_avoid = targets_to_avoid,
        top_level_infoplists = top_level_infoplists,
        top_level_resources = top_level_resources,
        version = version,
        version_keys_required = version_keys_required,
    )
