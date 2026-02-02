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
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@build_bazel_rules_apple//apple/internal:codesigning_support.bzl",
    "codesigning_support",
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
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "new_applecodesigningdossierinfo",
)

visibility("@build_bazel_rules_apple//apple/...")

_AppleCodesigningDossierInfo = provider(
    doc = """
Private provider to propagate codesigning dossier information.
""",
    fields = {
        "direct_embedded_dossier": """
A struct with codesigning dossier information to be embedded in another target, with the following
fields:
  * bundle_location: The location within the bundle to sign this artifact. This is typically based
      on processor.location values, and in that case will be resolved to the relative path of the
      bundle root when writing out the JSON for the dossier.
  * bundle_filename: The file name of the artifact to be signed.
  * dossier_file: The dossier zip file that provides context and inputs for signing.
  * user_defined_location: Whether the bundle_location was specified by the user. i.e. if the
      location was defined through "additional_contents". If true, the `bundle_location` will be
      a custom relative path within the bundle contents to the artifact to sign, which will be used
      directly when generating the JSON for the dossier.
""",
    },
)

# All locations are expected to be relative to the bundle contents directory, which is "Contents" on
# macOS for all but frameworks, "Versions/A" for macOS frameworks, and the bundle root on iOS
# derived platforms. If this assumption does not hold, then this set and "_location_map" below must
# be updated to take the full bundle location into account, like processor.bzl does.
_VALID_LOCATIONS_RELATIVE_CONTENTS = set([
    processor.location.app_clip,
    processor.location.binary,
    processor.location.bundle,
    processor.location.extension,
    processor.location.framework,
    processor.location.plugin,
    processor.location.watch,
    processor.location.xpc_service,
])

def _location_map(rule_descriptor):
    """Given a rule descriptor, returns a map of locations to relative paths within bundle contents.

    Args:
      rule_descriptor: The rule descriptor to build lookup for.

    Returns:
      Map from location value to location in bundle.
    """
    resolved = rule_descriptor.bundle_locations
    return {
        processor.location.app_clip: resolved.contents_relative_app_clips,
        processor.location.binary: resolved.contents_relative_binary,
        processor.location.bundle: "",
        processor.location.extension: resolved.contents_relative_extensions,
        processor.location.framework: resolved.contents_relative_frameworks,
        processor.location.plugin: resolved.contents_relative_plugins,
        processor.location.watch: resolved.contents_relative_watch,
        processor.location.xpc_service: resolved.contents_relative_xpc_service,
    }

def _embedded_codesign_dossiers_from_dossier_infos(
        *,
        bundle_paths,
        bundle_relative_contents,
        embedded_dossier_infos = []):
    """Resolves depsets of codesigning dossier info objects into a list of embedded dossiers.

    Args:
      bundle_paths: A map of bundle locations to paths in the bundle.
      bundle_relative_contents: The path fragment describing the root of the bundle relative to its
        contents. Expected to be "Contents" on macOS for all but macOS frameworks, "Versions/A" for
        modern macOS frameworks, and "" on iOS derived platforms.
      embedded_dossier_infos: Lists of embedded dossier info structs to extract.

    Returns:
      List of codesign dossiers embedded in locations computed using the map provided or the user
      defined location if specified. Each element is a struct with the following fields:
        * relative_bundle_path: The path to the artifact to sign relative to the bundle root.
        * dossier_file: The dossier zip file that provides context and inputs for signing.
    """
    existing_bundle_paths = set()
    embedded_codesign_dossiers = []
    for dossier_info in embedded_dossier_infos:
        if dossier_info.user_defined_location:
            contents_relative_path = dossier_info.bundle_location
        else:
            contents_relative_path = bundle_paths[dossier_info.bundle_location]
        relative_bundle_path = paths.join(
            bundle_relative_contents,
            contents_relative_path,
            dossier_info.bundle_filename,
        )
        if relative_bundle_path in existing_bundle_paths:
            continue
        existing_bundle_paths.add(relative_bundle_path)
        dossier = struct(
            relative_bundle_path = relative_bundle_path,
            dossier_file = dossier_info.dossier_file,
        )
        embedded_codesign_dossiers.append(dossier)
    return embedded_codesign_dossiers

def _create_combined_zip_artifact(
        *,
        actions,
        bundletool,
        dossier_merge_zip,
        input_archive,
        output_combined_zip,
        output_discriminator,
        rule_label,
        xplat_exec_group):
    """Generates a zip file with the IPA contents in one subdirectory and the dossier in another.

     Args:
      actions: The actions provider from `ctx.actions`.
      bundletool: A bundle tool from xplat toolchain.
      dossier_merge_zip: A File referencing the generated code sign dossier zip.
      input_archive: A File referencing the rule's output archive (IPA or zipped app).
      output_combined_zip: A File referencing where the combined dossier zip should be written to.
      output_discriminator: A string to differentiate between different target intermediate files
          or `None`.
      rule_label: Name of the target being built.
      xplat_exec_group: A string. The exec_group for actions using xplat toolchain.
    """
    bundletool_control_file = intermediates.file(
        actions = actions,
        target_name = rule_label.name,
        output_discriminator = output_discriminator,
        file_name = "combined_zip_bundletool_control.json",
    )

    combined_zip_archive_zips = [
        struct(src = input_archive.path, dest = "bundle"),
        struct(src = dossier_merge_zip.path, dest = "dossier"),
    ]
    enable_zip64_support = False

    bundletool_control = struct(
        bundle_merge_zips = combined_zip_archive_zips,
        enable_zip64_support = enable_zip64_support,
        output = output_combined_zip.path,
    )

    actions.write(
        output = bundletool_control_file,
        content = json.encode(bundletool_control),
    )

    common_combined_dossier_zip_args = {
        "mnemonic": "CreateCombinedDossierZip",
        "outputs": [output_combined_zip],
        "progress_message": "Creating combined dossier zip for %s" % rule_label.name,
    }

    actions.run(
        arguments = [bundletool_control_file.path],
        executable = bundletool.files_to_run,
        inputs = depset(
            direct = [bundletool_control_file],
            transitive = [
                depset([input_archive, dossier_merge_zip]),
            ],
        ),
        exec_group = xplat_exec_group,
        **common_combined_dossier_zip_args
    )

def _codesigning_dossier_partial_impl(
        *,
        actions,
        additional_contents = {},
        allow_combined_zip_output = True,
        apple_mac_toolchain_info,
        apple_xplat_toolchain_info,
        bundle_extension,
        bundle_location = None,
        bundle_name,
        embedded_targets = [],
        entitlements = None,
        mac_exec_group,
        output_discriminator,
        platform_prerequisites,
        predeclared_outputs,
        provisioning_profile = None,
        rule_descriptor,
        rule_label,
        xplat_exec_group):
    """Implementation of codesigning_dossier_partial"""

    if bundle_location and bundle_location not in _VALID_LOCATIONS_RELATIVE_CONTENTS:
        fail(("Internal Error: Bundle location %s is not a valid location to embed a signed " +
              "binary - valid locations are %s") %
             bundle_location, _VALID_LOCATIONS_RELATIVE_CONTENTS)

    embedded_dossier_infos = [
        x[_AppleCodesigningDossierInfo].direct_embedded_dossier
        for x in embedded_targets
        if _AppleCodesigningDossierInfo in x
    ]

    # If additional_contents were provided, then amend to the embedded_dossier_infos if any
    # _AppleCodesigningDossierInfo providers were found within, rewriting the bundle_location with
    # the user specified content relative path while preserving bundle_filename and dossier_file.
    embedded_dossier_infos.extend([
        struct(
            bundle_location = content_relative_path,
            bundle_filename = (
                x[_AppleCodesigningDossierInfo].direct_embedded_dossier.bundle_filename
            ),
            dossier_file = x[_AppleCodesigningDossierInfo].direct_embedded_dossier.dossier_file,
            user_defined_location = True,
        )
        for x, content_relative_path in additional_contents.items()
        if _AppleCodesigningDossierInfo in x
    ])

    embedded_codesign_dossiers = _embedded_codesign_dossiers_from_dossier_infos(
        bundle_paths = _location_map(rule_descriptor),
        bundle_relative_contents = rule_descriptor.bundle_locations.bundle_relative_contents,
        embedded_dossier_infos = embedded_dossier_infos,
    )

    codesign_identity = codesigning_support.preferred_codesigning_identity(
        build_settings = platform_prerequisites.build_settings,
        requires_adhoc_signing = not platform_prerequisites.platform.is_device,
    )

    dossier_file = codesigning_support.generate_dossier_file(
        actions = actions,
        apple_fragment = platform_prerequisites.apple_fragment,
        codesign_identity = codesign_identity,
        dossier_codesigningtool = apple_mac_toolchain_info.dossier_codesigningtool,
        embedded_dossiers = embedded_codesign_dossiers,
        entitlements = entitlements,
        mac_exec_group = mac_exec_group,
        provisioning_profile = provisioning_profile,
        rule_label = rule_label,
        target_signs_with_entitlements = platform_prerequisites.platform.is_device,
        xcode_config = platform_prerequisites.xcode_version_config,
    )

    providers = [
        new_applecodesigningdossierinfo(
            dossier = dossier_file,
        ),
    ]

    # Propagate the internal provider for an embedded dossier if the bundle_location was set. This
    # communicates down a need to embed this "embedded dossier" into the dossier generated by the
    # parent target.
    if bundle_location:
        providers.append(_AppleCodesigningDossierInfo(
            direct_embedded_dossier = struct(
                bundle_location = bundle_location,
                bundle_filename = bundle_name + bundle_extension,
                dossier_file = dossier_file,
                user_defined_location = False,
            ),
        ))

    tree_artifact_is_enabled = platform_prerequisites.build_settings.use_tree_artifacts_outputs

    combined_zip_files = []

    if not tree_artifact_is_enabled and allow_combined_zip_output:
        # The combined zip is only created when the rule's output is a zip file; if it's a tree
        # artifact, we supply the bits necessary to create a combined zip in a downstream rule via
        # the contents of the AppleBundleArchiveSupportInfo provider.
        output_combined_zip = actions.declare_file("%s_dossier_with_bundle.zip" % rule_label.name)

        output_archive = outputs.archive(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            output_discriminator = output_discriminator,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
        )

        _create_combined_zip_artifact(
            actions = actions,
            bundletool = apple_xplat_toolchain_info.bundletool,
            dossier_merge_zip = dossier_file,
            input_archive = output_archive,
            output_combined_zip = output_combined_zip,
            output_discriminator = output_discriminator,
            rule_label = rule_label,
            xplat_exec_group = xplat_exec_group,
        )

        combined_zip_files.append(output_combined_zip)

    return struct(
        output_groups = {
            "combined_dossier_zip": depset(combined_zip_files),
            "dossier": depset([dossier_file]),
        },
        providers = providers,
    )

def codesigning_dossier_partial(
        *,
        actions,
        additional_contents = {},
        allow_combined_zip_output = True,
        apple_mac_toolchain_info,
        apple_xplat_toolchain_info,
        bundle_extension,
        bundle_location = None,
        bundle_name,
        embedded_targets = [],
        entitlements = None,
        mac_exec_group,
        rule_descriptor,
        rule_label,
        output_discriminator = None,
        platform_prerequisites,
        predeclared_outputs,
        provisioning_profile = None,
        xplat_exec_group):
    """Creates a struct containing information for a codesigning dossier.

    Args:
      actions: The actions provider from `ctx.actions`.
      additional_contents: Additional contents to include in the codesigning dossier, which can have
            user specified paths into the bundle.
      allow_combined_zip_output: Whether or not to allow the creation of a combined zip output.
      apple_mac_toolchain_info: `struct` of tools from the shared Apple toolchain.
      apple_xplat_toolchain_info: An AppleXPlatToolsToolchainInfo provider.
      bundle_extension: The extension for the bundle.
      bundle_location: Optional location of this bundle if it is embedded in another bundle.
      bundle_name: The name of the output bundle.
      embedded_targets: The list of targets that propagate codesigning dossiers to bundle or
            propagate.
      entitlements: Optional entitlements for this bundle.
      mac_exec_group: The exec_group associated with apple_mac_toolchain
      output_discriminator: A string to differentiate between different target intermediate files
          or `None`.
      predeclared_outputs: Outputs declared by the owning context. Typically from `ctx.outputs`.
      platform_prerequisites: Struct containing information on the platform being targeted.
      provisioning_profile: Optional File for the provisioning profile.
      rule_descriptor: A rule descriptor for platform and product types from the rule context.
      rule_label: The label of the rule being built.
      xplat_exec_group: A string. The exec_group for actions using xplat toolchain.

    Returns:
      A partial that returns the codesigning dossier, if one was requested.
    """

    return partial.make(
        _codesigning_dossier_partial_impl,
        actions = actions,
        additional_contents = additional_contents,
        allow_combined_zip_output = allow_combined_zip_output,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_location = bundle_location,
        bundle_name = bundle_name,
        embedded_targets = embedded_targets,
        entitlements = entitlements,
        mac_exec_group = mac_exec_group,
        output_discriminator = output_discriminator,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        provisioning_profile = provisioning_profile,
        rule_descriptor = rule_descriptor,
        rule_label = rule_label,
        xplat_exec_group = xplat_exec_group,
    )
