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
    "@build_bazel_rules_apple//apple/internal:cc_toolchain_info_support.bzl",
    "cc_toolchain_info_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:codesigning_support.bzl",
    "codesigning_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:framework_import_support.bzl",
    "framework_import_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/internal:linking_support.bzl",
    "linking_support",
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
    "@build_bazel_rules_apple//apple/internal/utils:bundle_paths.bzl",
    "bundle_paths",
)

visibility("//apple/...")

# These come from Apple's recommended paths for placing content in a macOS bundle for a Framework:
# https://developer.apple.com/documentation/bundleresources/placing_content_in_a_bundle#3875936
_MACOS_VERSIONED_ROOT_INFOPLIST_PATH = "Versions/A/Resources"
_MACOS_UNVERSIONED_ROOT_INFOPLIST_PATH = "Resources"

def _framework_provider_files_to_bundle(
        *,
        field_name,
        targets,
        targets_to_avoid):
    """Collect AppleFrameworkImportInfo files for the given field, subtracted by targets to avoid

    Args:
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

    return files_to_bundle

def _generate_empty_dylib(
        *,
        actions,
        cc_configured_features_init,
        cc_toolchains,
        disabled_features,
        features,
        framework_basename,
        has_versioned_framework_files,
        label_name,
        output_discriminator,
        platform_prerequisites):
    """Generates the empty dylib required for Apple static frameworks in Xcode 15's "bundle & sign"

    Args:
        actions: The actions provider from `ctx.actions`.
        cc_configured_features_init: A lambda that is the same as cc_common.configure_features(...)
            without the need for a `ctx`.
        cc_toolchains: Dictionary of CcToolchainInfo providers under a split transition to relay
            target platform information.
        disabled_features: List of features to be disabled for C++ link actions.
        features: List of features enabled by the user. Typically from `ctx.features`.
        framework_basename: A string representing the framework path's basename.
        has_versioned_framework_files: Boolean. Indicates if the framework has versioned symlinks.
        label_name: Name of the target being built.
        output_discriminator: A string to differentiate between different target intermediate files
            or `None`.
        platform_prerequisites: Struct containing information on the platform being targeted.

    Returns:
        An empty dylib suitable for embedding within a static framework bundle for a shipping app in
            Xcode 15+.
    """
    linking_outputs = []
    framework_name = paths.split_extension(framework_basename)[0]

    for cc_toolchain_target in cc_toolchains.values():
        cc_toolchain = cc_toolchain_target[cc_common.CcToolchainInfo]
        feature_configuration = cc_configured_features_init(
            cc_toolchain = cc_toolchain,
            requested_features = features,
            unsupported_features = disabled_features,
        )
        target_triple = cc_toolchain_info_support.get_apple_clang_triplet(cc_toolchain)
        output_name = "{label}_{framework_name}_{os}_{min_os}_{architecture}_stub_bin".format(
            architecture = target_triple.architecture,
            framework_name = framework_name,
            label = label_name,
            min_os = platform_prerequisites.minimum_os,
            os = target_triple.os,
        )
        linking_output = cc_common.link(
            actions = actions,
            additional_inputs = [],
            cc_toolchain = cc_toolchain,
            feature_configuration = feature_configuration,
            name = output_name,
            output_type = "dynamic_library",
        )
        linking_outputs.append(linking_output)

    framework_binary_subdir = ""
    if has_versioned_framework_files:
        framework_binary_subdir = framework_import_support.macos_versioned_root_binary_path

    fat_stub_binary_relative_path = ""
    if framework_binary_subdir:
        fat_stub_binary_relative_path = paths.join(
            framework_basename,
            framework_binary_subdir,
            framework_name,
        )
    else:
        fat_stub_binary_relative_path = paths.join(framework_basename, framework_name)

    fat_stub_binary = intermediates.file(
        actions = actions,
        file_name = fat_stub_binary_relative_path,
        output_discriminator = output_discriminator,
        target_name = label_name,
    )

    linking_support.lipo_or_symlink_inputs(
        actions = actions,
        apple_fragment = platform_prerequisites.apple_fragment,
        inputs = [output.library_to_link.dynamic_library for output in linking_outputs],
        output = fat_stub_binary,
        xcode_config = platform_prerequisites.xcode_version_config,
    )

    return fat_stub_binary

def _generate_minos_overridden_root_info_plist(
        *,
        actions,
        apple_mac_toolchain_info,
        framework_basename,
        has_versioned_framework_files,
        label_name,
        mac_exec_group,
        output_discriminator,
        platform_prerequisites,
        potential_root_infoplists):
    """Generates an updated root Info.plist with the built target's minimum OS version. (FB13657402)

    Args:
        actions: The actions provider from `ctx.actions`.
        apple_mac_toolchain_info: tools from the shared Apple toolchain.
        framework_basename: A string representing the framework path's basename.
        has_versioned_framework_files: Boolean. Indicates if the framework has versioned symlinks.
        label_name: Name of the target being built.
        mac_exec_group: Exec group associated with apple_mac_toolchain_info
        output_discriminator: A string to differentiate between different target intermediate files
            or `None`.
        platform_prerequisites: Struct containing information on the platform being targeted.
        potential_root_infoplists: A list of Files representing potential candidates for the
            original Info.plist.

    Returns:
        `Struct` containing the following fields:

        *   `disqualified_root_infoplists`: A List of Files left untouched, which should still be
            processed as additional files downstream by the import dynamic framework processor tool.

        *   `overridden_root_infoplist`: A File representing the generated Info.plist with a minimum
            OS version matching the target being built.
    """
    framework_name = paths.split_extension(framework_basename)[0]

    framework_infoplist_subdir = ""
    if platform_prerequisites.platform_type == apple_common.platform_type.macos:
        if has_versioned_framework_files:
            framework_infoplist_subdir = _MACOS_VERSIONED_ROOT_INFOPLIST_PATH
        else:
            framework_infoplist_subdir = _MACOS_UNVERSIONED_ROOT_INFOPLIST_PATH

    infoplist_filename = "Info.plist"
    framework_infoplist_relative_path = ""
    if framework_infoplist_subdir:
        framework_infoplist_relative_path = paths.join(
            framework_basename,
            framework_infoplist_subdir,
            infoplist_filename,
        )
    else:
        framework_infoplist_relative_path = paths.join(framework_basename, infoplist_filename)

    overridden_root_infoplist = intermediates.file(
        actions = actions,
        file_name = framework_infoplist_relative_path,
        output_discriminator = output_discriminator,
        target_name = label_name,
    )

    minos_plist_key = "MinimumOSVersion"
    if platform_prerequisites.platform_type == apple_common.platform_type.macos:
        minos_plist_key = "LSMinimumSystemVersion"

    original_root_infoplist = None
    disqualified_root_infoplists = []
    for potential_root_infoplist in potential_root_infoplists:
        if potential_root_infoplist.path.endswith(framework_infoplist_relative_path):
            if original_root_infoplist:
                fail("""
Internal Error: Found two potential root Info.plists to override in a codeless framework:

- {first_found_infoplist}

- {second_found_infoplist}

Cannot determine which one is the canonical Info.plist for this framework. Please file an issue \
with the Apple BUILD Rules.
""".format(
                    first_found_infoplist = str(original_root_infoplist),
                    second_found_infoplist = str(potential_root_infoplist),
                ))
            original_root_infoplist = potential_root_infoplist
        else:
            disqualified_root_infoplists.append(potential_root_infoplist)

    if not original_root_infoplist:
        fail("""
Error: The framework {framework_basename} does not have a root Info.plist. One is needed to submit \
a framework that is bundled and signed as a "codeless framework" for Xcode 15+, such as a static \
framework or a framework with mergeable libraries.
        """.format(framework_basename = framework_basename))

    plisttool_control = struct(
        binary = True,
        forced_plists = [
            struct(
                **{minos_plist_key: platform_prerequisites.minimum_os}
            ),
        ],
        output = overridden_root_infoplist.path,
        plists = [original_root_infoplist.path],
        target = str(framework_name),
    )
    plisttool_control_file = intermediates.file(
        actions = actions,
        target_name = label_name,
        output_discriminator = output_discriminator,
        file_name = "{framework_name}-{infoplist_basename}-root-control".format(
            framework_name = framework_name,
            infoplist_basename = overridden_root_infoplist.basename,
        ),
    )
    actions.write(
        output = plisttool_control_file,
        content = json.encode(plisttool_control),
    )

    resource_actions.plisttool_action(
        actions = actions,
        control_file = plisttool_control_file,
        inputs = [original_root_infoplist],
        mac_exec_group = mac_exec_group,
        mnemonic = "CompileCodelessFrameworkRootInfoPlist",
        outputs = [overridden_root_infoplist],
        platform_prerequisites = platform_prerequisites,
        plisttool = apple_mac_toolchain_info.plisttool,
    )

    return struct(
        disqualified_root_infoplists = disqualified_root_infoplists,
        overridden_root_infoplist = overridden_root_infoplist,
    )

def _framework_import_partial_impl(
        *,
        actions,
        apple_mac_toolchain_info,
        cc_configured_features_init,
        cc_toolchains,
        disabled_features,
        features,
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
        field_name = "bundling_imports",
        targets = targets,
        targets_to_avoid = targets_to_avoid,
    )

    binary_files_to_bundle = _framework_provider_files_to_bundle(
        field_name = "binary_imports",
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
    infoplists_by_framework = dict()
    files_by_framework = dict()

    for file in bundling_files_to_bundle:
        framework_path = bundle_paths.farthest_parent(file.short_path, "framework")

        # Use the framework path's basename to distinguish groups of files.
        framework_basename = paths.basename(framework_path)
        if not files_by_framework.get(framework_basename):
            files_by_framework[framework_basename] = []
        if not infoplists_by_framework.get(framework_basename):
            infoplists_by_framework[framework_basename] = []

        # Classify if it's a file to bundle or an Info.plist
        if file.basename == "Info.plist":
            infoplists_by_framework[framework_basename].append(file)
            continue
        files_by_framework[framework_basename].append(file)

    framework_binaries_by_framework = dict()
    for file in binary_files_to_bundle:
        framework_path = bundle_paths.farthest_parent(file.short_path, "framework")

        # Continue using the framework path's basename to distinguish groups of files.
        framework_basename = paths.basename(framework_path)

        # Check that there's only one precompiled framework binary in this bundle, and that we don't
        # have multiple references to one binary, which is possible when merging providers.
        existing_framework_binary = framework_binaries_by_framework.get(framework_basename)
        if existing_framework_binary and existing_framework_binary.short_path != file.short_path:
            fail("""
Internal Error: Expected to find only one precompiled framework binary when processing deps for \
the framework {framework_basename} referenced by {label_name}, but found the following instead:

- {existing_framework_binary}

- {latest_framework_binary}

There should only be one valid framework binary. Please file an issue with the Apple BUILD Rules.
""".format(
                existing_framework_binary = existing_framework_binary,
                framework_basename = framework_basename,
                latest_framework_binary = file,
                label_name = label_name,
            ))

        framework_binaries_by_framework[framework_basename] = file

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

        has_versioned_framework_files = False
        if platform_prerequisites.platform_type == apple_common.platform_type.macos:
            has_versioned_framework_files = framework_import_support.has_versioned_framework_files(
                files_by_framework[framework_basename],
            )

        # Pass through all binaries, files, and relevant info as args.
        args = actions.args()

        framework_binary = framework_binaries_by_framework.get(framework_basename)
        if not framework_binary:
            # If the framework doesn't have a binary (i.e. from an imported Static Framework
            # XCFramework), generate an empty dylib to fulfill Xcode 15 requirements.
            framework_binaries_by_framework[framework_basename] = _generate_empty_dylib(
                actions = actions,
                cc_configured_features_init = cc_configured_features_init,
                cc_toolchains = cc_toolchains,
                disabled_features = disabled_features,
                features = features,
                framework_basename = framework_basename,
                has_versioned_framework_files = has_versioned_framework_files,
                label_name = label_name,
                output_discriminator = output_discriminator,
                platform_prerequisites = platform_prerequisites,
            )

            if not infoplists_by_framework.get(framework_basename):
                fail("""
Error: The framework {framework_basename} does not have a root Info.plist. One is needed to submit \
a framework that is bundled and signed as a "codeless framework" for Xcode 15+, such as a static \
framework or a framework with mergeable libraries.
                     """.format(framework_basename = framework_basename))

            # Update the corresponding Info.plist with relevant minimum OS version information per
            # Xcode 15.3 implementation for "bundle & sign"ing a codeless framework, enough to get
            # past App Store Connect validation without a MinimumOSVersion of 100 hack (FB13657402).
            processed_infoplists = _generate_minos_overridden_root_info_plist(
                actions = actions,
                apple_mac_toolchain_info = apple_mac_toolchain_info,
                framework_basename = framework_basename,
                has_versioned_framework_files = has_versioned_framework_files,
                label_name = label_name,
                mac_exec_group = mac_exec_group,
                output_discriminator = output_discriminator,
                platform_prerequisites = platform_prerequisites,
                potential_root_infoplists = infoplists_by_framework[framework_basename],
            )

            infoplists_by_framework[framework_basename] = (
                [processed_infoplists.overridden_root_infoplist] +
                processed_infoplists.disqualified_root_infoplists
            )

        args.add("--framework_binary", framework_binaries_by_framework[framework_basename])

        args.add_all(build_archs_found, before_each = "--slice")

        args.add("--output_zip", framework_zip.path)

        args.add("--temp_path", temp_framework_bundle_path)

        args.add_all(files_by_framework[framework_basename], before_each = "--framework_file")

        infoplists = infoplists_by_framework.get(framework_basename)
        if infoplists:
            args.add_all(
                infoplists_by_framework[framework_basename],
                before_each = "--framework_file",
            )

        codesign_args = codesigning_support.codesigning_args(
            entitlements = None,
            features = features,
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
            args.add("--disable_signing")

        codesigningtool = apple_mac_toolchain_info.codesigningtool
        imported_dynamic_framework_processor = apple_mac_toolchain_info.imported_dynamic_framework_processor

        # Inputs of action are all the framework files, plus binaries needed for identifying the
        # current build's preferred architecture, and the provisioning profile if specified.
        input_files = (
            files_by_framework[framework_basename] +
            [framework_binaries_by_framework[framework_basename]]
        )
        if infoplists:
            input_files.extend(infoplists)
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

    return struct(
        bundle_zips = bundle_zips,
        signed_frameworks = depset(signed_frameworks_list),
    )

def framework_import_partial(
        *,
        actions,
        apple_mac_toolchain_info,
        cc_configured_features_init,
        cc_toolchains,
        disabled_features,
        features,
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
        cc_configured_features_init: A lambda that is the same as cc_common.configure_features(...)
            without the need for a `ctx`.
        cc_toolchains: Dictionary of CcToolchainInfo providers under a split transition to relay
            target platform information.
        disabled_features: List of features to be disabled for C++ link actions.
        features: List of features enabled by the user. Typically from `ctx.features`.
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
        cc_configured_features_init = cc_configured_features_init,
        cc_toolchains = cc_toolchains,
        disabled_features = disabled_features,
        features = features,
        label_name = label_name,
        mac_exec_group = mac_exec_group,
        output_discriminator = output_discriminator,
        platform_prerequisites = platform_prerequisites,
        provisioning_profile = provisioning_profile,
        rule_descriptor = rule_descriptor,
        targets = targets,
        targets_to_avoid = targets_to_avoid,
    )
