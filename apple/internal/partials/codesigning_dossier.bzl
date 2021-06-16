# Copyright 2021 The Bazel Authors. All rights reserved.
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

"""Partial implementation for codesigning dossier file generation."""

load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@build_bazel_rules_apple//apple/internal:codesigning_support.bzl",
    "codesigning_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:processor.bzl",
    "processor",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@bazel_skylib//lib:new_sets.bzl",
    "sets",
)

_AppleCodesigningDossierInfo = provider(
    doc = """
Private provider to propagate codesigning dossier information.
""",
    fields = {
        "embedded_dossiers": """
Depset of structs with codesigning dossier information to be embedded in another target.
""",
    },
)

_VALID_LOCATIONS = sets.make([
    processor.location.app_clip,
    processor.location.framework,
    processor.location.plugin,
    processor.location.watch,
    processor.location.xpc_service,
])

def _is_location_valid(location):
    """Determines if a location is a valid location to embed a signed binary.

    Args:
      location: The location for an embedded signed binary.

    Returns:
      True if the location is valid, False otherwise.
    """
    return sets.contains(_VALID_LOCATIONS, location)

def _location_map(rule_descriptor):
    """Given a rule descriptor, returns a map of locations to actual paths within the bundle for the location.

    Args:
      rule_descriptor: The rule descriptor to build lookup for.

    Returns:
      Map from location value to location in bundle.
    """
    resolved = rule_descriptor.bundle_locations
    return {
        processor.location.app_clip: resolved.contents_relative_app_clips,
        processor.location.framework: resolved.contents_relative_frameworks,
        processor.location.plugin: resolved.contents_relative_plugins,
        processor.location.watch: resolved.contents_relative_watch,
        processor.location.xpc_service: resolved.contents_relative_xpc_service,
    }

def _codesigning_dossier_info(codesigning_dossier, bundle_name, bundle_extension, bundle_location):
    """Creates a struct containing information for a codesigning dossier.

    Args:
      codesigning_dossier: The rule descriptor to build lookup for.
      bundle_name: The name of the output bundle.
      bundle_extension: The extension for the bundle.
      bundle_location: Location of this bundle when embedded.

    Returns:
      Struct representing the codesigning dossier for use in _AppleCodesigningDossierInfo.
    """
    return struct(
        codesigning_dossier = codesigning_dossier,
        bundle_name = bundle_name,
        bundle_extension = bundle_extension,
        bundle_location = bundle_location,
    )

def _embedded_codesign_dossiers_from_dossier_infos(
        bundle_paths,
        embedded_dossier_info_depsets = []):
    """Resolves depsets of codesigning dossier info objects into a list of embedded dossiers.

    Args:
      bundle_paths: A map of bundle locations to paths in the bundle.
      embedded_dossier_info_depsets: Depsets of embedded dossier info structs to extract.

    Returns:
      List of codesign dossiers embedded in locations computed using the map provided.
    """
    existing_bundle_paths = sets.make()
    embedded_codesign_dossiers = []
    for dossier_info_depset in embedded_dossier_info_depsets:
        embedded_dossier_infos = dossier_info_depset.to_list()
        for dossier_info in embedded_dossier_infos:
            bundle_filename = dossier_info.bundle_name + dossier_info.bundle_extension
            relative_bundle_path = paths.join(
                bundle_paths[dossier_info.bundle_location],
                bundle_filename,
            )
            if sets.contains(existing_bundle_paths, relative_bundle_path):
                continue
            sets.insert(existing_bundle_paths, relative_bundle_path)
            dossier = codesigning_support.embedded_codesigning_dossier(
                relative_bundle_path,
                dossier_info.codesigning_dossier,
            )
            embedded_codesign_dossiers.append(dossier)
    return embedded_codesign_dossiers

def _codesigning_dossier_partial_impl(
        *,
        actions,
        apple_toolchain_info,
        bundle_extension,
        bundle_location = None,
        bundle_name,
        embed_target_dossiers = True,
        embedded_targets = [],
        entitlements = None,
        label_name,
        output_discriminator,
        platform_prerequisites,
        provisioning_profile = None,
        rule_descriptor):
    """Implementation of codesigning_dossier_partial"""

    if bundle_location and not _is_location_valid(bundle_location):
        fail(("Bundle location %s is not a valid location to embed a signed " +
              "binary - valid locations are %s") %
             bundle_location, sets.str(_VALID_LOCATIONS))
    embedded_dossier_infos_depsets = [
        x[_AppleCodesigningDossierInfo].embedded_dossiers
        for x in embedded_targets
        if _AppleCodesigningDossierInfo in x
    ]

    embedded_codesign_dossiers = _embedded_codesign_dossiers_from_dossier_infos(
        bundle_paths = _location_map(rule_descriptor),
        embedded_dossier_info_depsets = embedded_dossier_infos_depsets,
    ) if embed_target_dossiers else []

    output_dossier = actions.declare_file("%s_dossier.zip" % label_name)

    dossier_info = _codesigning_dossier_info(
        codesigning_dossier = output_dossier,
        bundle_name = bundle_name,
        bundle_extension = bundle_extension,
        bundle_location = bundle_location,
    ) if bundle_location else None

    codesigning_support.generate_codesigning_dossier_action(
        actions = actions,
        label_name = label_name,
        resolved_codesigning_dossier_tool = apple_toolchain_info.resolved_dossier_codesigningtool,
        output_discriminator = output_discriminator,
        output_dossier = output_dossier,
        platform_prerequisites = platform_prerequisites,
        embedded_dossiers = embedded_codesign_dossiers,
        entitlements = entitlements,
        provisioning_profile = provisioning_profile,
    )

    embedded_dossier_depset = None
    if embed_target_dossiers and dossier_info:
        embedded_dossier_depset = depset(direct = [dossier_info])
    elif not embed_target_dossiers:
        if dossier_info:
            embedded_dossier_depset = depset(
                direct = [dossier_info],
                transitive = embedded_dossier_infos_depsets,
            )
        else:
            embedded_dossier_depset = depset(
                transitive = embedded_dossier_infos_depsets,
            )

    providers = [_AppleCodesigningDossierInfo(
        embedded_dossiers = embedded_dossier_depset,
    )] if embedded_dossier_depset else []

    return struct(
        output_groups = {
            "dossier": depset([output_dossier]),
        },
        providers = providers,
    )

def codesigning_dossier_partial(
        *,
        actions,
        apple_toolchain_info,
        bundle_extension,
        bundle_location = None,
        bundle_name,
        embed_target_dossiers = True,
        embedded_targets = [],
        entitlements = None,
        label_name,
        output_discriminator = None,
        platform_prerequisites,
        provisioning_profile = None,
        rule_descriptor):
    """Creates a struct containing information for a codesigning dossier.

    Args:
      actions: The actions provider from `ctx.actions`.
      apple_toolchain_info: `struct` of tools from the shared Apple toolchain.
      bundle_extension: The extension for the bundle.
      bundle_location: Optional location of this bundle if it is embedded in another bundle.
      bundle_name: The name of the output bundle.
      embed_target_dossiers: If True, this target's dossier will embed all transitive dossiers
            _only_ propagated through the targets given in embedded_targets. If False, the
            dossiers for embedded bundles will be propagated downstream for a top level target
            to bundle them.
      embedded_targets: The list of targets that propagate codesigning dossiers to bundle or
            propagate.
      entitlements: Optional entitlements for this bundle.
      label_name: Name of the target being built
      output_discriminator: A string to differentiate between different target intermediate files
          or `None`.
      platform_prerequisites: Struct containing information on the platform being targeted.
      provisioning_profile: Optional File for the provisioning profile.
      rule_descriptor: A rule descriptor for platform and product types from the rule context.

    Returns:
      A partial that returns the codesigning dossier, if one was requested.
    """

    return partial.make(
        _codesigning_dossier_partial_impl,
        actions = actions,
        apple_toolchain_info = apple_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_location = bundle_location,
        bundle_name = bundle_name,
        embed_target_dossiers = embed_target_dossiers,
        embedded_targets = embedded_targets,
        entitlements = entitlements,
        label_name = label_name,
        output_discriminator = output_discriminator,
        platform_prerequisites = platform_prerequisites,
        provisioning_profile = provisioning_profile,
        rule_descriptor = rule_descriptor,
    )
