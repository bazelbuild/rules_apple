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

def _generate_empty_dylib(
        *,
        actions,
        cc_configured_features_init,
        cc_toolchains,
        disabled_features,
        features,
        framework_basename,
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
        linking_context, _ = cc_common.create_linking_context_from_compilation_outputs(
            actions = actions,
            cc_toolchain = cc_toolchain,
            compilation_outputs = cc_common.create_compilation_outputs(),
            feature_configuration = feature_configuration,
            name = label_name,
        )
        target_triple = cc_toolchain_info_support.get_apple_clang_triplet(cc_toolchain)
        output_name = "{label}_{framework_name}_{os}_{architecture}_stub_bin".format(
            architecture = target_triple.architecture,
            framework_name = framework_name,
            label = label_name,
            os = target_triple.os,
        )
        linking_output = cc_common.link(
            actions = actions,
            additional_inputs = [],
            cc_toolchain = cc_toolchain,
            feature_configuration = feature_configuration,
            linking_contexts = [linking_context],
            name = output_name,
            output_type = "dynamic_library",
            stamp = 0,
            user_link_flags = [
                # Suppress linker warnings, which avoids warnings on the empty dylib that shouldn't
                # affect the main app binary.
                "-Wl,-w",
            ],
        )
        linking_outputs.append(linking_output)

    # TODO(b/326440971): Have this account for /Versions/{id} for macOS, per
    # https://developer.apple.com/documentation/bundleresources/placing_content_in_a_bundle
    fat_stub_binary = intermediates.file(
        actions = actions,
        target_name = label_name,
        output_discriminator = output_discriminator,
        file_name = "{framework_name}.framework/{framework_name}".format(
            framework_name = framework_name,
        ),
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
        label_name,
        mac_exec_group,
        original_root_infoplist,
        output_discriminator,
        platform_prerequisites):
    """Generates an updated root Info.plist with the built target's minimum OS version. (FB13657402)

    Args:
        actions: The actions provider from `ctx.actions`.
        apple_mac_toolchain_info: tools from the shared Apple toolchain.
        framework_basename: A string representing the framework path's basename.
        label_name: Name of the target being built.
        mac_exec_group: Exec group associated with apple_mac_toolchain_info
        original_root_infoplist: A File representing the original original Info.plist.
        output_discriminator: A string to differentiate between different target intermediate files
            or `None`.
        platform_prerequisites: Struct containing information on the platform being targeted.

    Returns:
        A File representing the generated Info.plist with a minimum OS version matching the target
            being built.
    """
    framework_name = paths.split_extension(framework_basename)[0]

    # TODO(b/326440971): Have this account for /Versions/{id}/Resources for macOS, per
    # https://developer.apple.com/documentation/bundleresources/placing_content_in_a_bundle
    overridden_root_infoplist = intermediates.file(
        actions = actions,
        target_name = label_name,
        output_discriminator = output_discriminator,
        file_name = "{framework_name}.framework/Info.plist".format(
            framework_name = framework_name,
        ),
    )

    minos_plist_key = "MinimumOSVersion"
    if platform_prerequisites.platform_type == apple_common.platform_type.macos:
        minos_plist_key = "LSMinimumSystemVersion"

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

    return overridden_root_infoplist

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
    transitive_sets = [
        x[AppleFrameworkImportInfo].framework_imports
        for x in targets
        if AppleFrameworkImportInfo in x and
           hasattr(x[AppleFrameworkImportInfo], "framework_imports")
    ]
    files_to_bundle = depset(transitive = transitive_sets).to_list()

    if targets_to_avoid:
        avoid_transitive_sets = [
            x[AppleFrameworkImportInfo].framework_imports
            for x in targets_to_avoid
            if AppleFrameworkImportInfo in x and
               hasattr(x[AppleFrameworkImportInfo], "framework_imports")
        ]
        if avoid_transitive_sets:
            avoid_files = depset(transitive = avoid_transitive_sets).to_list()

            # Remove any files present in the targets to avoid from framework files that need to be
            # bundled.
            files_to_bundle = [x for x in files_to_bundle if x not in avoid_files]

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
    framework_binaries_by_framework = dict()
    files_by_framework = dict()
    root_infoplists_by_framework = dict()

    for file in files_to_bundle:
        framework_path = bundle_paths.farthest_parent(file.short_path, "framework")

        # Use the framework path's basename to distinguish groups of files.
        framework_basename = paths.basename(framework_path)
        if not files_by_framework.get(framework_basename):
            files_by_framework[framework_basename] = []
        if not framework_binaries_by_framework.get(framework_basename):
            framework_binaries_by_framework[framework_basename] = []

        # Check if this file is a binary to slice and code sign.
        framework_relative_path = paths.relativize(file.short_path, framework_path)

        parent_dir = framework_basename
        framework_relative_dir = paths.dirname(framework_relative_path).strip("/")
        if framework_relative_dir:
            parent_dir = paths.join(parent_dir, framework_relative_dir)

        # Classify if it's a file to bundle or framework binary
        if paths.replace_extension(parent_dir, "") == file.basename:
            framework_binaries_by_framework[framework_basename].append(file)
            continue
        elif file.basename == "Info.plist":
            # TODO(b/326440971): Have this account for /Versions/{id}/Resources for macOS, per
            # https://developer.apple.com/documentation/bundleresources/placing_content_in_a_bundle
            if (platform_prerequisites.platform_type != apple_common.platform_type.macos and
                not framework_relative_dir):
                # For non-macOS platforms, check specifically if this Info.plist was at the root of
                # the framework bundle. This is the one which we will want to change the declared
                # MinimumOSVersion to match the generated empty dylib for App Store Connect.
                root_infoplists_by_framework[framework_basename] = file
                continue
        files_by_framework[framework_basename].append(file)

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

        # TODO(b/326440971): Correctly account for the Versions/Current symlink and a Versions/{id}
        # binary when targeting macOS, both at analysis time when identifying binaries and in the
        # implementation of _generate_empty_dylib(...).
        if (not framework_binaries_by_framework.get(framework_basename) and
            platform_prerequisites.platform_type != apple_common.platform_type.macos):
            # If the framework doesn't have a binary (i.e. from an imported Static Framework
            # XCFramework), generate an empty dylib to fulfill Xcode 15 requirements.
            framework_binaries_by_framework[framework_basename] = [
                _generate_empty_dylib(
                    actions = actions,
                    cc_configured_features_init = cc_configured_features_init,
                    cc_toolchains = cc_toolchains,
                    disabled_features = disabled_features,
                    features = features,
                    framework_basename = framework_basename,
                    label_name = label_name,
                    output_discriminator = output_discriminator,
                    platform_prerequisites = platform_prerequisites,
                ),
            ]

            if not root_infoplists_by_framework.get(framework_basename):
                fail("""
Error: The framework {framework_basename} does not have a root Info.plist. One is needed to submit \
a framework that is bundled and signed as a "codeless framework" for Xcode 15+, such as a static \
framework or a framework with mergeable libraries.
                     """.format(framework_basename = framework_basename))

            # Update the corresponding Info.plist with relevant minimum OS version information per
            # Xcode 15.3 implementation for "bundle & sign"ing a codeless framework, enough to get
            # past App Store Connect validation without a MinimumOSVersion of 100 hack (FB13657402).
            overridden_root_infoplist = _generate_minos_overridden_root_info_plist(
                actions = actions,
                apple_mac_toolchain_info = apple_mac_toolchain_info,
                framework_basename = framework_basename,
                label_name = label_name,
                mac_exec_group = mac_exec_group,
                original_root_infoplist = root_infoplists_by_framework[framework_basename],
                output_discriminator = output_discriminator,
                platform_prerequisites = platform_prerequisites,
            )

            root_infoplists_by_framework[framework_basename] = overridden_root_infoplist

        args.add_all(
            framework_binaries_by_framework[framework_basename],
            before_each = "--framework_binary",
        )

        args.add_all(build_archs_found, before_each = "--slice")

        args.add("--output_zip", framework_zip.path)

        args.add("--temp_path", temp_framework_bundle_path)

        args.add_all(files_by_framework[framework_basename], before_each = "--framework_file")

        root_infoplist = root_infoplists_by_framework.get(framework_basename)
        if root_infoplist:
            args.add("--framework_file", root_infoplists_by_framework[framework_basename])

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
            framework_binaries_by_framework[framework_basename]
        )
        if root_infoplist:
            input_files.append(root_infoplist)
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
