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
    "resources",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_support.bzl",
    "rule_support",
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

def _merge_root_infoplists(ctx, infoplists, out_infoplist, **kwargs):
    """Registers the root Info.plist generation action.

    Args:
      ctx: The target's rule context.
      infoplists: List of plists that should be merged into the root Info.plist.
      out_infoplist: Reference to the output Info plist.
      **kwargs: Extra parameters forwarded into the merge_root_infoplists action.

    Returns:
      A list of tuples as described in processor.bzl with the Info.plist file
      reference and the PkgInfo file if required.
    """
    files = [out_infoplist]

    rule_descriptor = rule_support.rule_descriptor(ctx)
    out_pkginfo = None
    if rule_descriptor.requires_pkginfo:
        out_pkginfo = intermediates.file(
            ctx.actions,
            ctx.label.name,
            "PkgInfo",
        )
        files.append(out_pkginfo)

    resource_actions.merge_root_infoplists(
        ctx,
        infoplists,
        out_infoplist,
        out_pkginfo,
        **kwargs
    )

    return [(processor.location.content, None, depset(direct = files))]

def _expand_owners(owners):
    """Converts a depset of (path, owner) to a dict of paths to dict of owners.

    Args:
      owners: A depset of (path, owner) pairs.
    """
    dict = {}
    for resource, owner in owners.to_list():
        if owner:
            dict.setdefault(resource, default = {})[owner] = None
    return dict

def _deduplicate(resources_provider, avoid_provider, owners, avoid_owners, field):
    """Deduplicates and returns resources between 2 providers for a given field.

    Deduplication happens by comparing the target path of a file and the files
    themselves. If there are 2 resources with the same target path but different
    contents, the files will not be deduplicated.

    This approach is naïve in the sense that it deduplicates resources too
    aggressively. We also need to compare the target that references the
    resources so that they are not deduplicated if they are referenced within
    multiple binary-containing bundles.

    Args:
      resources_provider: The provider with the resources to be bundled.
      avoid_provider: The provider with the resources to avoid bundling.
      owners: The owners map for resources_provider computed by _expand_owners.
      avoid_owners: The owners map for avoid_provider computed by _expand_owners.
      field: The field to deduplicate resources on.

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
                if deduped_owners:
                    deduped_files.append(to_bundle_file)
            else:
                deduped_files.append(to_bundle_file)

        if deduped_files:
            deduped_tuples.append((parent_dir, swift_module, depset(deduped_files)))

    return deduped_tuples

def _locales_requested(ctx):
    """Determines which locales to include when resource actions.

    If the user has specified "apple.locales_to_include" we use those. Otherwise we don't filter.
    'Base' is included by default to any given list of locales to include.

    Args:
        ctx: The rule context.

    Returns:
        A set of locales to include or None if all should be included.
    """
    requested_locales = ctx.var.get("apple.locales_to_include")
    if requested_locales != None:
        return sets.make(["Base"] + [x.strip() for x in requested_locales.split(",")])
    else:
        return None

def _validate_processed_locales(label, locales_requested, locales_included, locales_dropped):
    """Prints a warning if locales were dropped and none of the requested ones were included."""
    if sets.length(locales_dropped):
        # Display a warning if a locale was dropped and there are unfulfilled locale requests; it
        # could mean that the user made a mistake in defining the locales they want to keep.
        if not sets.is_equal(locales_requested, locales_included):
            unused_locales = sets.difference(locales_requested, locales_included)
            print("Warning: " + str(label) + " did not have resources that matched " +
                  sets.str(unused_locales) + " in locale filter. Please verify " +
                  "apple.locales_to_include is defined properly.")

def _resources_partial_impl(
        ctx,
        bundle_id,
        bundle_verification_targets,
        plist_attrs,
        targets_to_avoid,
        top_level_attrs,
        version_keys_required):
    """Implementation for the resource processing partial."""
    providers = []
    for attr in ["deps", "resources"]:
        if hasattr(ctx.attr, attr):
            providers.extend([
                x[AppleResourceInfo]
                for x in getattr(ctx.attr, attr)
                if AppleResourceInfo in x
            ])

    # TODO(kaipi): Bucket top_level_attrs directly instead of collecting and
    # splitting.
    files = resources.collect(ctx.attr, res_attrs = top_level_attrs)
    if files:
        providers.append(resources.bucketize(files, owner = str(ctx.label)))

    if plist_attrs:
        plists = resources.collect(ctx.attr, res_attrs = plist_attrs)
        plist_provider = resources.bucketize_typed(
            plists,
            owner = str(ctx.label),
            bucket_type = "infoplists",
        )
        providers.append(plist_provider)

    if not providers:
        # If there are no resource providers, return early, since there is nothing to process.
        # Most rules will always have at least one resource since they have a mandatory infoplists
        # attribute, but not ios_static_framework. This rule can be perfectly valid without any
        # resource.
        return struct()

    final_provider = resources.merge_providers(providers, default_owner = str(ctx.label))

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
            avoid_providers,
            validate_all_resources_owned = True,
        )

    # Map of resource provider fields to a tuple that contains the method to use to process those
    # resources and a boolean indicating whether the Swift module is required for that processing.
    provider_field_to_action = {
        "asset_catalogs": (resources_support.asset_catalogs, False),
        "datamodels": (resources_support.datamodels, True),
        "infoplists": (resources_support.infoplists, False),
        "mlmodels": (resources_support.mlmodels, False),
        "plists": (resources_support.plists_and_strings, False),
        "pngs": (resources_support.pngs, False),
        # TODO(b/113252360): Remove this once we can correctly process Fileset files.
        "resource_zips": (resources_support.resource_zips, False),
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

    locales_requested = _locales_requested(ctx)
    locales_included = sets.make(["Base"])
    locales_dropped = sets.make()

    # Precompute owners and avoid_owners to avoid duplicate work in _deduplicate.
    # Build a dictionary with the file paths under each key for the avoided resources.
    avoid_owners = {}
    if avoid_provider:
        avoid_owners = _expand_owners(avoid_provider.owners)
    owners = _expand_owners(final_provider.owners)

    for field in fields:
        processing_func, requires_swift_module = provider_field_to_action[field]
        deduplicated = _deduplicate(final_provider, avoid_provider, owners, avoid_owners, field)
        for parent_dir, swift_module, files in deduplicated:
            if locales_requested:
                locale = bundle_paths.locale_for_path(parent_dir)
                if sets.contains(locales_requested, locale):
                    sets.insert(locales_included, locale)
                elif locale != None:
                    sets.insert(locales_dropped, locale)
                    continue

            processing_args = {
                "ctx": ctx,
                "files": files,
                "parent_dir": parent_dir,
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
        _validate_processed_locales(ctx.label, locales_requested, locales_included, locales_dropped)

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

        out_infoplist = outputs.infoplist(ctx)
        bundle_files.extend(
            _merge_root_infoplists(
                ctx,
                infoplists,
                out_infoplist,
                bundle_id = bundle_id,
                child_plists = bundle_verification_infoplists,
                child_required_values = bundle_verification_required_values,
                version_keys_required = version_keys_required,
            ),
        )

    return struct(bundle_files = bundle_files, providers = [final_provider])

def resources_partial(
        bundle_id = None,
        bundle_verification_targets = [],
        plist_attrs = [],
        targets_to_avoid = [],
        top_level_attrs = [],
        version_keys_required = True):
    """Constructor for the resources processing partial.

    This partial collects and propagates all resources that should be bundled in the target being
    processed.

    Args:
        bundle_id: Optional bundle ID to use when processing resources. If no bundle ID is given,
            the bundle will not contain a root Info.plist and no embedded bundle verification will
            occur.
        bundle_verification_targets: List of structs that reference embedable targets that need to
            be validated. The structs must have a `target` field with the target containing an
            Info.plist file that will be validated. The structs may also have a
            `parent_bundle_id_reference` field that contains the plist path, in list form, to the
            plist entry that must contain this target's bundle ID.
        plist_attrs: List of attributes that should be processed as Info plists that should be
            merged and processed.
        targets_to_avoid: List of targets containing resources that should be deduplicated from the
            target being processed.
        top_level_attrs: List of attributes containing resources that need to be processed from the
            target being processed.
        version_keys_required: Whether to validate that the Info.plist version keys are correctly
            configured.

    Returns:
        A partial that returns the bundle location of the resources and the resources provider.
    """
    return partial.make(
        _resources_partial_impl,
        bundle_id = bundle_id,
        bundle_verification_targets = bundle_verification_targets,
        plist_attrs = plist_attrs,
        targets_to_avoid = targets_to_avoid,
        top_level_attrs = top_level_attrs,
        version_keys_required = version_keys_required,
    )
