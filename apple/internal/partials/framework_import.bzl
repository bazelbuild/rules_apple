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

"""Partial implementation for framework import file processing."""

load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleFrameworkImportInfo",
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
    "@build_bazel_rules_apple//apple/internal:processor.bzl",
    "processor",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:bundle_paths.bzl",
    "bundle_paths",
)

visibility("@build_bazel_rules_apple//apple/...")

def _framework_provider_files_to_bundle(
        *,
        deduplicate_short_paths,
        field_name,
        targets,
        targets_to_avoid):
    """Collect AppleFrameworkImportInfo files for the given field, subtracted by targets to avoid

    Args:
        deduplicate_short_paths: Boolean. Indicates if the returned set of files should be
            deduplicated by short path, ensuring no duplicated files are returned based on the
            transitions applied to the targets. This will return the first file found for each given
            short path, and ignore any subsequent files found with the same short path, losing any
            detection of when the files aren't guaranteed to be the same in the process.
        field_name: A String representing the field name of the AppleFrameworkImportInfo provider to
            collect files from.
        targets: A List of Targets to collect AppleFrameworkImportInfo providers from.
        targets_to_avoid: A List of Targets to collect AppleFrameworkImportInfo provider that should
            be subtracted from the information collected from `targets`.

    Returns:
        A List of Files from AppleFrameworkImportInfo providers as determined from the given
            arguments.
    """
    transitive_files_to_bundle = [
        getattr(x[AppleFrameworkImportInfo], field_name)
        for x in targets
        if AppleFrameworkImportInfo in x and
           hasattr(x[AppleFrameworkImportInfo], field_name)
    ]
    files_to_bundle = depset(transitive = transitive_files_to_bundle).to_list()

    if targets_to_avoid:
        avoid_transitive_files_to_bundle = [
            getattr(x[AppleFrameworkImportInfo], field_name)
            for x in targets_to_avoid
            if AppleFrameworkImportInfo in x and
               hasattr(x[AppleFrameworkImportInfo], field_name)
        ]
        if avoid_transitive_files_to_bundle:
            avoid_files = depset(transitive = avoid_transitive_files_to_bundle).to_list()

            # Remove any files present in the targets to avoid from framework files that need to be
            # bundled.
            files_to_bundle = [x for x in files_to_bundle if x not in avoid_files]

    if deduplicate_short_paths:
        deduplicated_files_to_bundle = dict()
        for file in files_to_bundle:
            if file.short_path in deduplicated_files_to_bundle:
                continue
            deduplicated_files_to_bundle[file.short_path] = file
        files_to_bundle = deduplicated_files_to_bundle.values()

    return files_to_bundle

def _framework_import_partial_impl(
        *,
        actions,
        apple_mac_toolchain_info,
        cc_configured_features,
        label_name,
        mac_exec_group,
        output_discriminator,
        platform_prerequisites,
        provisioning_profile,
        rule_descriptor,
        targets,
        targets_to_avoid):
    """Implementation for the framework import file processing partial."""

    bundling_files_to_bundle = _framework_provider_files_to_bundle(
        deduplicate_short_paths = True,
        field_name = "bundling_imports",
        targets = targets,
        targets_to_avoid = targets_to_avoid,
    )

    binary_files_to_bundle = _framework_provider_files_to_bundle(
        deduplicate_short_paths = False,  # Required to handle stub dylibs for codeless frameworks.
        field_name = "binary_imports",
        targets = targets,
        targets_to_avoid = targets_to_avoid,
    )

    signature_files_to_bundle = _framework_provider_files_to_bundle(
        deduplicate_short_paths = True,
        field_name = "signature_files",
        targets = targets,
        targets_to_avoid = targets_to_avoid,
    )

    # Collect the architectures that we are using for the build.
    build_archs_found = [
        build_arch
        for x in targets
        if AppleFrameworkImportInfo in x
        for build_arch in x[AppleFrameworkImportInfo].build_archs.to_list()
    ]

    # Start assembling our partial's outputs.
    bundle_zips = []
    signed_frameworks_list = []

    # Separating our files by framework path, to better address what should be passed in.
    files_by_framework = dict()
    for file in bundling_files_to_bundle:
        framework_path = bundle_paths.farthest_parent(file.short_path, "framework")

        # Use the framework path's basename to distinguish groups of files.
        framework_basename = paths.basename(framework_path)
        if not files_by_framework.get(framework_basename):
            files_by_framework[framework_basename] = []

        files_by_framework[framework_basename].append(file)

    framework_binaries_by_framework = dict()
    for file in binary_files_to_bundle:
        framework_path = bundle_paths.farthest_parent(file.short_path, "framework")

        # Continue using the framework path's basename to distinguish groups of files.
        framework_basename = paths.basename(framework_path)
        if not framework_binaries_by_framework.get(framework_basename):
            framework_binaries_by_framework[framework_basename] = []

        framework_binaries_by_framework[framework_basename].append(file)

    for framework_basename in files_by_framework.keys():
        # Create a temporary path for intermediate files and the anticipated zip output.
        temp_path = paths.join("_imported_frameworks/", framework_basename)
        framework_zip = intermediates.file(
            actions = actions,
            target_name = label_name,
            output_discriminator = output_discriminator,
            file_name = temp_path + ".zip",
        )
        temp_framework_bundle_path = paths.split_extension(framework_zip.path)[0]

        # Pass through all binaries, files, and relevant info as args.
        args = actions.args()

        framework_binaries = framework_binaries_by_framework.get(framework_basename)
        if not framework_binaries:
            fail("""
Internal Error: The framework {framework_basename} does not have a binary. One is needed to submit \
a framework that is bundled and signed for Xcode that will pass App Store Connect validation.
            """.format(framework_basename = framework_basename))

        args.add_all(framework_binaries, before_each = "--framework-binary-paths")

        args.add_all(build_archs_found, before_each = "--requested-architectures")

        args.add("--output-zip-path", framework_zip.path)

        args.add_all(files_by_framework[framework_basename], before_each = "--framework-file-paths")

        codesign_args = codesigning_support.codesigning_args(
            cc_configured_features = cc_configured_features,
            entitlements = None,
            full_archive_path = temp_framework_bundle_path,
            is_framework = True,
            platform_prerequisites = platform_prerequisites,
            provisioning_profile = provisioning_profile,
            rule_descriptor = rule_descriptor,
        )
        if codesign_args:
            args.add_all(codesign_args)
        else:
            # Add required argument to disable signing because
            # code sign arguments are mutually exclusive groups.
            args.add("--disable-signing")

        codesigningtool = apple_mac_toolchain_info.codesigningtool
        imported_dynamic_framework_processor = (
            apple_mac_toolchain_info.imported_dynamic_framework_processor
        )

        # Inputs of action are all the framework files, plus binaries needed for identifying the
        # current build's preferred architecture, and the provisioning profile if specified.
        input_files = (
            files_by_framework[framework_basename] +
            framework_binaries_by_framework[framework_basename]
        )
        if provisioning_profile:
            input_files.append(provisioning_profile)

        apple_support.run(
            actions = actions,
            apple_fragment = platform_prerequisites.apple_fragment,
            arguments = [args],
            executable = imported_dynamic_framework_processor,
            exec_group = mac_exec_group,
            inputs = input_files,
            mnemonic = "ImportedDynamicFrameworkProcessor",
            outputs = [framework_zip],
            tools = [codesigningtool],
            xcode_config = platform_prerequisites.xcode_version_config,
        )

        bundle_zips.append(
            (processor.location.framework, None, depset([framework_zip])),
        )
        signed_frameworks_list.append(framework_basename)

    # Process signature files separately; we can bundle them as is thanks to earlier deduplication.
    if signature_files_to_bundle:
        bundle_files = [(
            processor.location.archive,
            "Signatures",
            depset(signature_files_to_bundle),
        )]
    else:
        bundle_files = []

    return struct(
        bundle_files = bundle_files,
        bundle_zips = bundle_zips,
        signed_frameworks = depset(signed_frameworks_list),
    )

def framework_import_partial(
        *,
        actions,
        apple_mac_toolchain_info,
        cc_configured_features,
        label_name,
        mac_exec_group,
        output_discriminator = None,
        platform_prerequisites,
        provisioning_profile,
        rule_descriptor,
        targets,
        targets_to_avoid = []):
    """Constructor for the framework import file processing partial.

    This partial propagates framework import file bundle locations. The files are collected through
    the framework_provider_aspect aspect.

    Args:
        actions: The actions provider from `ctx.actions`.
        apple_mac_toolchain_info: tools from the shared Apple toolchain.
        cc_configured_features: A struct returned by `features_support.cc_configured_features(...)`
            to capture the rule ctx for a deferred `cc_common.configure_features(...)` call.
        label_name: Name of the target being built.
        mac_exec_group: Exec group associated with apple_mac_toolchain_info
        output_discriminator: A string to differentiate between different target intermediate files
            or `None`.
        platform_prerequisites: Struct containing information on the platform being targeted.
        provisioning_profile: File for the provisioning profile.
        rule_descriptor: A rule descriptor for platform and product types from the rule context.
        targets: The list of targets through which to collect the framework import files.
        targets_to_avoid: The list of targets that may already be bundling some of the frameworks,
            to be used when deduplicating frameworks already bundled.

    Returns:
        A partial that returns the bundle location of the framework import files.
    """
    return partial.make(
        _framework_import_partial_impl,
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        cc_configured_features = cc_configured_features,
        label_name = label_name,
        mac_exec_group = mac_exec_group,
        output_discriminator = output_discriminator,
        platform_prerequisites = platform_prerequisites,
        provisioning_profile = provisioning_profile,
        rule_descriptor = rule_descriptor,
        targets = targets,
        targets_to_avoid = targets_to_avoid,
    )
