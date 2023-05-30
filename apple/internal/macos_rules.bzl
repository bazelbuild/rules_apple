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

"""Implementation of macOS rules."""

load(
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/internal:apple_toolchains.bzl",
    "AppleMacToolsToolchainInfo",
    "AppleXPlatToolsToolchainInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:bundling_support.bzl",
    "bundling_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:codesigning_support.bzl",
    "codesigning_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:entitlements_support.bzl",
    "entitlements_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:features_support.bzl",
    "features_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:linking_support.bzl",
    "linking_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:outputs.bzl",
    "outputs",
)
load(
    "@build_bazel_rules_apple//apple/internal:partials.bzl",
    "partials",
)
load(
    "@build_bazel_rules_apple//apple/internal:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:processor.bzl",
    "processor",
)
load(
    "@build_bazel_rules_apple//apple/internal:resources.bzl",
    "resources",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_factory.bzl",
    "rule_factory",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_support.bzl",
    "rule_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:run_support.bzl",
    "run_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:transition_support.bzl",
    "transition_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:clang_rt_dylibs.bzl",
    "clang_rt_dylibs",
)
load(
    "@build_bazel_rules_apple//apple/internal:cc_info_support.bzl",
    "cc_info_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:swift_support.bzl",
    "swift_support",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "SwiftInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/aspects:swift_dynamic_framework_aspect.bzl",
    "SwiftDynamicFrameworkInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:framework_import_support.bzl",
    "libraries_to_link_for_dynamic_framework",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBinaryInfo",
    "AppleBinaryInfoplistInfo",
    "AppleFrameworkBundleInfo",
    "MacosApplicationBundleInfo",
    "MacosBundleBundleInfo",
    "MacosExtensionBundleInfo",
    "MacosFrameworkBundleInfo",
    "MacosKernelExtensionBundleInfo",
    "MacosQuickLookPluginBundleInfo",
    "MacosSpotlightImporterBundleInfo",
    "MacosStaticFrameworkBundleInfo",
    "MacosXPCServiceBundleInfo",
)
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")

def _macos_application_impl(ctx):
    """Implementation of macos_application."""

    embedded_targets = (
        ctx.attr.frameworks +
        ctx.attr.extensions +
        ctx.attr.xpc_services +
        ctx.attr.deps
    )
    verification_targets = (
        ctx.attr.frameworks +
        ctx.attr.extensions +
        ctx.attr.xpc_services
    )
    actions = ctx.actions
    apple_mac_toolchain_info = ctx.attr._mac_toolchain[AppleMacToolsToolchainInfo]
    apple_xplat_toolchain_info = ctx.attr._xplat_toolchain[AppleXPlatToolsToolchainInfo]
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    executable_name = bundling_support.executable_name(ctx)

    bundle_verification_targets = [struct(target = ext) for ext in verification_targets]

    features = features_support.compute_enabled_features(
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    provisioning_profile = ctx.file.provisioning_profile
    resource_deps = ctx.attr.deps + ctx.attr.resources
    rule_descriptor = rule_support.rule_descriptor(ctx)
    top_level_infoplists = resources.collect(
        attr = ctx.attr,
        res_attrs = ["infoplists"],
    )
    top_level_resources = resources.collect(
        attr = ctx.attr,
        res_attrs = [
            "app_icons",
            "strings",
            "resources",
        ],
    )

    entitlements = entitlements_support.process_entitlements(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        bundle_id = bundle_id,
        entitlements_file = ctx.file.entitlements,
        platform_prerequisites = platform_prerequisites,
        product_type = rule_descriptor.product_type,
        provisioning_profile = provisioning_profile,
        rule_label = label,
        validation_mode = ctx.attr.entitlements_validation,
    )

    link_result = linking_support.register_binary_linking_action(
        ctx,
        avoid_deps = ctx.attr.frameworks,
        entitlements = entitlements.linking,
        platform_prerequisites = platform_prerequisites,
        stamp = ctx.attr.stamp,
    )
    binary_artifact = link_result.binary
    debug_outputs = linking_support.debug_outputs_by_architecture(link_result.outputs)

    processor_partials = [
        partials.apple_bundle_info_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            executable_name = executable_name,
            entitlements = entitlements.bundle,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            product_type = rule_descriptor.product_type,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            executable_name = executable_name,
            label_name = label.name,
        ),
        partials.codesigning_dossier_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            embedded_targets = embedded_targets,
            entitlements = entitlements.codesigning,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            provisioning_profile = provisioning_profile,
            rule_descriptor = rule_descriptor,
        ),
        partials.clang_rt_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            features = features,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            dylibs = clang_rt_dylibs.get_from_toolchain(ctx),
        ),
        partials.debug_symbols_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = embedded_targets + ctx.attr.additional_contents.keys(),
            dsym_binaries = debug_outputs.dsym_binaries,
            dsym_info_plist_template = apple_mac_toolchain_info.dsym_info_plist_template,
            executable_name = executable_name,
            linkmaps = debug_outputs.linkmaps,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.embedded_bundles_partial(
            bundle_embedded_bundles = True,
            embeddable_targets = embedded_targets,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.framework_import_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            features = features,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            provisioning_profile = provisioning_profile,
            rule_descriptor = rule_descriptor,
            targets = embedded_targets,
        ),
        partials.macos_additional_contents_partial(
            additional_contents = ctx.attr.additional_contents,
        ),
        partials.resources_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            executable_name = executable_name,
            bundle_verification_targets = bundle_verification_targets,
            environment_plist = ctx.file._environment_plist,
            launch_storyboard = None,
            platform_prerequisites = platform_prerequisites,
            resource_deps = resource_deps,
            rule_descriptor = rule_descriptor,
            rule_label = label,
            targets_to_avoid = ctx.attr.frameworks,
            top_level_infoplists = top_level_infoplists,
            top_level_resources = top_level_resources,
            version = ctx.attr.version,
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            bundle_dylibs = True,
            dependency_targets = embedded_targets,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.apple_symbols_file_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            dependency_targets = embedded_targets,
            dsym_binaries = debug_outputs.dsym_binaries,
            label_name = label.name,
            include_symbols_in_bundle = ctx.attr.include_symbols_in_bundle,
            platform_prerequisites = platform_prerequisites,
        ),
    ]

    if provisioning_profile:
        processor_partials.append(
            partials.provisioning_profile_partial(
                actions = actions,
                extension = "provisionprofile",
                location = processor.location.content,
                profile_artifact = provisioning_profile,
                rule_label = label,
            ),
        )

    processor_result = processor.process(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        codesign_inputs = ctx.files.codesign_inputs,
        codesignopts = codesigning_support.codesignopts_from_rule_ctx(ctx),
        entitlements = entitlements.codesigning,
        executable_name = executable_name,
        features = features,
        ipa_post_processor = ctx.executable.ipa_post_processor,
        partials = processor_partials,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_mac_toolchain_info.process_and_sign_template,
        provisioning_profile = provisioning_profile,
        rule_descriptor = rule_descriptor,
        rule_label = label,
    )

    executable = outputs.executable(
        actions = actions,
        label_name = label.name,
    )
    run_support.register_macos_executable(
        actions = actions,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        output = executable,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        runner_template = ctx.file._runner_template,
    )

    archive = outputs.archive(
        actions = actions,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        executable_name = executable_name,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
    )

    return [
        coverage_common.instrumented_files_info(ctx, dependency_attributes = ["deps"]),
        DefaultInfo(
            executable = executable,
            files = processor_result.output_files,
            runfiles = ctx.runfiles(
                files = [archive],
            ),
        ),
        MacosApplicationBundleInfo(),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
            )
        ),
        apple_common.new_executable_binary_provider(
            binary = binary_artifact,
            cc_info = link_result.cc_info,
            objc = link_result.objc,
        ),
        # TODO(b/228856372): Remove when downstream users are migrated off this provider.
        link_result.debug_outputs_provider,
    ] + processor_result.providers

def _macos_bundle_impl(ctx):
    """Implementation of macos_bundle."""
    actions = ctx.actions
    apple_mac_toolchain_info = ctx.attr._mac_toolchain[AppleMacToolsToolchainInfo]
    apple_xplat_toolchain_info = ctx.attr._xplat_toolchain[AppleXPlatToolsToolchainInfo]
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    executable_name = bundling_support.executable_name(ctx)
    features = features_support.compute_enabled_features(
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    provisioning_profile = ctx.file.provisioning_profile
    resource_deps = ctx.attr.deps + ctx.attr.resources
    rule_descriptor = rule_support.rule_descriptor(ctx)
    top_level_infoplists = resources.collect(
        attr = ctx.attr,
        res_attrs = ["infoplists"],
    )
    top_level_resources = resources.collect(
        attr = ctx.attr,
        res_attrs = [
            "app_icons",
            "strings",
            "resources",
        ],
    )

    entitlements = entitlements_support.process_entitlements(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        bundle_id = bundle_id,
        entitlements_file = ctx.file.entitlements,
        platform_prerequisites = platform_prerequisites,
        product_type = rule_descriptor.product_type,
        provisioning_profile = provisioning_profile,
        rule_label = label,
        validation_mode = ctx.attr.entitlements_validation,
    )

    link_result = linking_support.register_binary_linking_action(
        ctx,
        bundle_loader = ctx.attr.bundle_loader,
        entitlements = entitlements.linking,
        extra_linkopts = ["-bundle"],
        platform_prerequisites = platform_prerequisites,
        stamp = ctx.attr.stamp,
    )
    binary_artifact = link_result.binary
    debug_outputs = linking_support.debug_outputs_by_architecture(link_result.outputs)

    archive = outputs.archive(
        actions = actions,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
    )

    processor_partials = [
        partials.apple_bundle_info_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            executable_name = executable_name,
            entitlements = entitlements.bundle,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            product_type = rule_descriptor.product_type,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            executable_name = executable_name,
            label_name = label.name,
        ),
        partials.clang_rt_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            features = features,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            dylibs = clang_rt_dylibs.get_from_toolchain(ctx),
        ),
        partials.codesigning_dossier_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_location = processor.location.plugin,
            bundle_name = bundle_name,
            embed_target_dossiers = False,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            provisioning_profile = provisioning_profile,
            rule_descriptor = rule_descriptor,
        ),
        partials.debug_symbols_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = ctx.attr.additional_contents.keys(),
            dsym_binaries = debug_outputs.dsym_binaries,
            dsym_info_plist_template = apple_mac_toolchain_info.dsym_info_plist_template,
            executable_name = executable_name,
            linkmaps = debug_outputs.linkmaps,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.embedded_bundles_partial(
            platform_prerequisites = platform_prerequisites,
            plugins = [archive],
        ),
        partials.macos_additional_contents_partial(
            additional_contents = ctx.attr.additional_contents,
        ),
        partials.resources_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            environment_plist = ctx.file._environment_plist,
            executable_name = executable_name,
            launch_storyboard = None,
            platform_prerequisites = platform_prerequisites,
            resource_deps = resource_deps,
            rule_descriptor = rule_descriptor,
            rule_label = label,
            top_level_infoplists = top_level_infoplists,
            top_level_resources = top_level_resources,
            version = ctx.attr.version,
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
    ]

    if provisioning_profile:
        processor_partials.append(
            partials.provisioning_profile_partial(
                actions = actions,
                extension = "provisionprofile",
                location = processor.location.content,
                profile_artifact = provisioning_profile,
                rule_label = label,
            ),
        )

    processor_result = processor.process(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        codesign_inputs = ctx.files.codesign_inputs,
        codesignopts = codesigning_support.codesignopts_from_rule_ctx(ctx),
        entitlements = entitlements.codesigning,
        executable_name = executable_name,
        features = features,
        ipa_post_processor = ctx.executable.ipa_post_processor,
        partials = processor_partials,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_mac_toolchain_info.process_and_sign_template,
        provisioning_profile = provisioning_profile,
        rule_descriptor = rule_descriptor,
        rule_label = label,
    )

    return [
        DefaultInfo(
            files = processor_result.output_files,
        ),
        MacosBundleBundleInfo(),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
            )
        ),
        # TODO(b/228856372): Remove when downstream users are migrated off this provider.
        link_result.debug_outputs_provider,
    ] + processor_result.providers

def _macos_extension_impl(ctx):
    """Experimental implementation of macos_extension."""
    actions = ctx.actions
    apple_mac_toolchain_info = ctx.attr._mac_toolchain[AppleMacToolsToolchainInfo]
    apple_xplat_toolchain_info = ctx.attr._xplat_toolchain[AppleXPlatToolsToolchainInfo]
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    executable_name = bundling_support.executable_name(ctx)
    features = features_support.compute_enabled_features(
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    provisioning_profile = ctx.file.provisioning_profile
    resource_deps = ctx.attr.deps + ctx.attr.resources
    rule_descriptor = rule_support.rule_descriptor(ctx)
    top_level_infoplists = resources.collect(
        attr = ctx.attr,
        res_attrs = ["infoplists"],
    )
    top_level_resources = resources.collect(
        attr = ctx.attr,
        res_attrs = [
            "app_icons",
            "strings",
            "resources",
        ],
    )

    entitlements = entitlements_support.process_entitlements(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        bundle_id = bundle_id,
        entitlements_file = ctx.file.entitlements,
        platform_prerequisites = platform_prerequisites,
        product_type = rule_descriptor.product_type,
        provisioning_profile = provisioning_profile,
        rule_label = label,
        validation_mode = ctx.attr.entitlements_validation,
    )

    link_result = linking_support.register_binary_linking_action(
        ctx,
        avoid_deps = ctx.attr.frameworks,
        entitlements = entitlements.linking,
        platform_prerequisites = platform_prerequisites,
        stamp = ctx.attr.stamp,
    )

    binary_artifact = link_result.binary
    debug_outputs = linking_support.debug_outputs_by_architecture(link_result.outputs)

    archive = outputs.archive(
        actions = actions,
        bundle_name = bundle_name,
        bundle_extension = bundle_extension,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
    )

    processor_partials = [
        partials.apple_bundle_info_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            entitlements = entitlements.bundle,
            executable_name = executable_name,
            extension_safe = True,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            product_type = rule_descriptor.product_type,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            executable_name = executable_name,
            label_name = label.name,
        ),
        partials.clang_rt_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            features = features,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            dylibs = clang_rt_dylibs.get_from_toolchain(ctx),
        ),
        partials.codesigning_dossier_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_location = processor.location.plugin,
            bundle_name = bundle_name,
            embed_target_dossiers = False,
            entitlements = entitlements.codesigning,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            provisioning_profile = provisioning_profile,
            rule_descriptor = rule_descriptor,
        ),
        partials.debug_symbols_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = ctx.attr.frameworks + ctx.attr.additional_contents.keys(),
            dsym_binaries = debug_outputs.dsym_binaries,
            dsym_info_plist_template = apple_mac_toolchain_info.dsym_info_plist_template,
            executable_name = executable_name,
            linkmaps = debug_outputs.linkmaps,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.embedded_bundles_partial(
            embeddable_targets = ctx.attr.frameworks,
            platform_prerequisites = platform_prerequisites,
            plugins = [archive],
        ),
        partials.macos_additional_contents_partial(
            additional_contents = ctx.attr.additional_contents,
        ),
        partials.resources_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            environment_plist = ctx.file._environment_plist,
            executable_name = executable_name,
            launch_storyboard = None,
            platform_prerequisites = platform_prerequisites,
            resource_deps = resource_deps,
            rule_descriptor = rule_descriptor,
            rule_label = label,
            top_level_infoplists = top_level_infoplists,
            top_level_resources = top_level_resources,
            version = ctx.attr.version,
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            dependency_targets = ctx.attr.frameworks,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.apple_symbols_file_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            dependency_targets = [],
            dsym_binaries = debug_outputs.dsym_binaries,
            label_name = label.name,
            include_symbols_in_bundle = False,
            platform_prerequisites = platform_prerequisites,
        ),
    ]

    if provisioning_profile:
        processor_partials.append(
            partials.provisioning_profile_partial(
                actions = actions,
                extension = "provisionprofile",
                location = processor.location.content,
                profile_artifact = provisioning_profile,
                rule_label = label,
            ),
        )

    processor_result = processor.process(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        codesign_inputs = ctx.files.codesign_inputs,
        codesignopts = codesigning_support.codesignopts_from_rule_ctx(ctx),
        entitlements = entitlements.codesigning,
        executable_name = executable_name,
        features = features,
        ipa_post_processor = ctx.executable.ipa_post_processor,
        partials = processor_partials,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_mac_toolchain_info.process_and_sign_template,
        provisioning_profile = provisioning_profile,
        rule_descriptor = rule_descriptor,
        rule_label = label,
    )

    return [
        DefaultInfo(
            files = processor_result.output_files,
        ),
        MacosExtensionBundleInfo(),
        apple_common.new_executable_binary_provider(
            binary = binary_artifact,
            objc = link_result.objc,
        ),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
            )
        ),
        # TODO(b/228856372): Remove when downstream users are migrated off this provider.
        link_result.debug_outputs_provider,
    ] + processor_result.providers

def _macos_quick_look_plugin_impl(ctx):
    """Experimental implementation of macos_quick_look_plugin."""
    actions = ctx.actions
    apple_mac_toolchain_info = ctx.attr._mac_toolchain[AppleMacToolsToolchainInfo]
    apple_xplat_toolchain_info = ctx.attr._xplat_toolchain[AppleXPlatToolsToolchainInfo]
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    executable_name = bundling_support.executable_name(ctx)
    features = features_support.compute_enabled_features(
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    provisioning_profile = ctx.file.provisioning_profile
    resource_deps = ctx.attr.deps + ctx.attr.resources
    rule_descriptor = rule_support.rule_descriptor(ctx)
    top_level_infoplists = resources.collect(
        attr = ctx.attr,
        res_attrs = ["infoplists"],
    )
    top_level_resources = resources.collect(
        attr = ctx.attr,
        res_attrs = [
            "strings",
            "resources",
        ],
    )

    entitlements = entitlements_support.process_entitlements(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        bundle_id = bundle_id,
        entitlements_file = ctx.file.entitlements,
        platform_prerequisites = platform_prerequisites,
        product_type = rule_descriptor.product_type,
        provisioning_profile = provisioning_profile,
        rule_label = label,
        validation_mode = ctx.attr.entitlements_validation,
    )

    extra_linkopts = [
        "-dynamiclib",
        "-install_name",
        "\"/Library/Frameworks/{0}.qlgenerator/{0}\"".format(ctx.attr.bundle_name),
    ]
    link_result = linking_support.register_binary_linking_action(
        ctx,
        entitlements = entitlements.linking,
        extra_linkopts = extra_linkopts,
        platform_prerequisites = platform_prerequisites,
        stamp = ctx.attr.stamp,
    )
    binary_artifact = link_result.binary
    debug_outputs = linking_support.debug_outputs_by_architecture(link_result.outputs)

    archive = outputs.archive(
        actions = actions,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
    )

    processor_partials = [
        partials.apple_bundle_info_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            executable_name = executable_name,
            entitlements = entitlements.bundle,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            product_type = rule_descriptor.product_type,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            executable_name = executable_name,
            label_name = label.name,
        ),
        # TODO(kaipi): Check if clang_rt dylibs are needed in Quick Look plugins, or if
        # they can be skipped.
        partials.clang_rt_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            features = features,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            dylibs = clang_rt_dylibs.get_from_toolchain(ctx),
        ),
        partials.codesigning_dossier_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_location = processor.location.framework,
            bundle_name = bundle_name,
            embed_target_dossiers = False,
            entitlements = entitlements.codesigning,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            provisioning_profile = provisioning_profile,
            rule_descriptor = rule_descriptor,
        ),
        partials.debug_symbols_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = ctx.attr.additional_contents.keys(),
            dsym_binaries = debug_outputs.dsym_binaries,
            dsym_info_plist_template = apple_mac_toolchain_info.dsym_info_plist_template,
            executable_name = executable_name,
            linkmaps = debug_outputs.linkmaps,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.embedded_bundles_partial(
            frameworks = [archive],
            platform_prerequisites = platform_prerequisites,
        ),
        partials.macos_additional_contents_partial(
            additional_contents = ctx.attr.additional_contents,
        ),
        partials.resources_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            environment_plist = ctx.file._environment_plist,
            executable_name = executable_name,
            launch_storyboard = None,
            platform_prerequisites = platform_prerequisites,
            resource_deps = resource_deps,
            rule_descriptor = rule_descriptor,
            rule_label = label,
            top_level_infoplists = top_level_infoplists,
            top_level_resources = top_level_resources,
            version = ctx.attr.version,
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.apple_symbols_file_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            dependency_targets = [],
            dsym_binaries = debug_outputs.dsym_binaries,
            label_name = label.name,
            include_symbols_in_bundle = False,
            platform_prerequisites = platform_prerequisites,
        ),
    ]

    if provisioning_profile:
        processor_partials.append(
            partials.provisioning_profile_partial(
                actions = actions,
                extension = "provisionprofile",
                location = processor.location.content,
                profile_artifact = provisioning_profile,
                rule_label = label,
            ),
        )

    processor_result = processor.process(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        codesignopts = codesigning_support.codesignopts_from_rule_ctx(ctx),
        entitlements = entitlements.codesigning,
        executable_name = executable_name,
        features = features,
        ipa_post_processor = ctx.executable.ipa_post_processor,
        partials = processor_partials,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_mac_toolchain_info.process_and_sign_template,
        provisioning_profile = provisioning_profile,
        rule_descriptor = rule_descriptor,
        rule_label = label,
    )

    return [
        DefaultInfo(files = processor_result.output_files),
        MacosQuickLookPluginBundleInfo(),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
            )
        ),
        # TODO(b/228856372): Remove when downstream users are migrated off this provider.
        link_result.debug_outputs_provider,
    ] + processor_result.providers

def _macos_kernel_extension_impl(ctx):
    """Implementation of macos_kernel_extension."""
    actions = ctx.actions
    apple_mac_toolchain_info = ctx.attr._mac_toolchain[AppleMacToolsToolchainInfo]
    apple_xplat_toolchain_info = ctx.attr._xplat_toolchain[AppleXPlatToolsToolchainInfo]
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    executable_name = bundling_support.executable_name(ctx)
    features = features_support.compute_enabled_features(
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    provisioning_profile = ctx.file.provisioning_profile
    resource_deps = ctx.attr.deps + ctx.attr.resources
    rule_descriptor = rule_support.rule_descriptor(ctx)
    top_level_infoplists = resources.collect(
        attr = ctx.attr,
        res_attrs = ["infoplists"],
    )
    top_level_resources = resources.collect(
        attr = ctx.attr,
        res_attrs = ["resources"],
    )

    entitlements = entitlements_support.process_entitlements(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        bundle_id = bundle_id,
        entitlements_file = ctx.file.entitlements,
        platform_prerequisites = platform_prerequisites,
        product_type = rule_descriptor.product_type,
        provisioning_profile = provisioning_profile,
        rule_label = label,
        validation_mode = ctx.attr.entitlements_validation,
    )

    link_result = linking_support.register_binary_linking_action(
        ctx,
        entitlements = entitlements.linking,
        platform_prerequisites = platform_prerequisites,
        stamp = ctx.attr.stamp,
    )
    binary_artifact = link_result.binary
    debug_outputs = linking_support.debug_outputs_by_architecture(link_result.outputs)

    archive = outputs.archive(
        actions = actions,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
    )

    processor_partials = [
        partials.apple_bundle_info_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            executable_name = executable_name,
            entitlements = entitlements.bundle,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            product_type = rule_descriptor.product_type,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            executable_name = executable_name,
            label_name = label.name,
        ),
        partials.clang_rt_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            features = features,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            dylibs = clang_rt_dylibs.get_from_toolchain(ctx),
        ),
        partials.codesigning_dossier_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_location = processor.location.plugin,
            bundle_name = bundle_name,
            embed_target_dossiers = False,
            entitlements = entitlements.codesigning,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            provisioning_profile = provisioning_profile,
            rule_descriptor = rule_descriptor,
        ),
        partials.debug_symbols_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = ctx.attr.additional_contents.keys(),
            dsym_binaries = debug_outputs.dsym_binaries,
            dsym_info_plist_template = apple_mac_toolchain_info.dsym_info_plist_template,
            executable_name = executable_name,
            linkmaps = debug_outputs.linkmaps,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.embedded_bundles_partial(
            platform_prerequisites = platform_prerequisites,
            plugins = [archive],
        ),
        partials.macos_additional_contents_partial(
            additional_contents = ctx.attr.additional_contents,
        ),
        partials.resources_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            environment_plist = ctx.file._environment_plist,
            executable_name = executable_name,
            launch_storyboard = None,
            platform_prerequisites = platform_prerequisites,
            resource_deps = resource_deps,
            rule_descriptor = rule_descriptor,
            rule_label = label,
            top_level_infoplists = top_level_infoplists,
            top_level_resources = top_level_resources,
            version = ctx.attr.version,
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.apple_symbols_file_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            dependency_targets = [],
            dsym_binaries = debug_outputs.dsym_binaries,
            label_name = label.name,
            include_symbols_in_bundle = False,
            platform_prerequisites = platform_prerequisites,
        ),
    ]

    if provisioning_profile:
        processor_partials.append(
            partials.provisioning_profile_partial(
                actions = actions,
                extension = "provisionprofile",
                location = processor.location.content,
                profile_artifact = provisioning_profile,
                rule_label = label,
            ),
        )

    processor_result = processor.process(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        codesign_inputs = ctx.files.codesign_inputs,
        codesignopts = codesigning_support.codesignopts_from_rule_ctx(ctx),
        entitlements = entitlements.codesigning,
        executable_name = executable_name,
        features = features,
        ipa_post_processor = ctx.executable.ipa_post_processor,
        partials = processor_partials,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_mac_toolchain_info.process_and_sign_template,
        provisioning_profile = provisioning_profile,
        rule_descriptor = rule_descriptor,
        rule_label = label,
    )

    return [
        DefaultInfo(
            files = processor_result.output_files,
        ),
        MacosKernelExtensionBundleInfo(),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
            )
        ),
        # TODO(b/228856372): Remove when downstream users are migrated off this provider.
        link_result.debug_outputs_provider,
    ] + processor_result.providers

def _macos_spotlight_importer_impl(ctx):
    """Implementation of macos_spotlight_importer."""
    actions = ctx.actions
    apple_mac_toolchain_info = ctx.attr._mac_toolchain[AppleMacToolsToolchainInfo]
    apple_xplat_toolchain_info = ctx.attr._xplat_toolchain[AppleXPlatToolsToolchainInfo]
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    executable_name = bundling_support.executable_name(ctx)
    features = features_support.compute_enabled_features(
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    provisioning_profile = ctx.file.provisioning_profile
    resource_deps = ctx.attr.deps + ctx.attr.resources
    rule_descriptor = rule_support.rule_descriptor(ctx)
    top_level_infoplists = resources.collect(
        attr = ctx.attr,
        res_attrs = ["infoplists"],
    )

    entitlements = entitlements_support.process_entitlements(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        bundle_id = bundle_id,
        entitlements_file = ctx.file.entitlements,
        platform_prerequisites = platform_prerequisites,
        product_type = rule_descriptor.product_type,
        provisioning_profile = provisioning_profile,
        rule_label = label,
        validation_mode = ctx.attr.entitlements_validation,
    )

    link_result = linking_support.register_binary_linking_action(
        ctx,
        entitlements = entitlements.linking,
        platform_prerequisites = platform_prerequisites,
        stamp = ctx.attr.stamp,
    )
    binary_artifact = link_result.binary
    debug_outputs = linking_support.debug_outputs_by_architecture(link_result.outputs)

    archive = outputs.archive(
        actions = actions,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
    )

    processor_partials = [
        partials.apple_bundle_info_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            executable_name = executable_name,
            entitlements = entitlements.bundle,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            product_type = rule_descriptor.product_type,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            executable_name = executable_name,
            label_name = label.name,
        ),
        partials.clang_rt_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            features = features,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            dylibs = clang_rt_dylibs.get_from_toolchain(ctx),
        ),
        partials.codesigning_dossier_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_location = processor.location.plugin,
            bundle_name = bundle_name,
            embed_target_dossiers = False,
            entitlements = entitlements.codesigning,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            provisioning_profile = provisioning_profile,
            rule_descriptor = rule_descriptor,
        ),
        partials.debug_symbols_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = ctx.attr.additional_contents.keys(),
            dsym_binaries = debug_outputs.dsym_binaries,
            dsym_info_plist_template = apple_mac_toolchain_info.dsym_info_plist_template,
            executable_name = executable_name,
            linkmaps = debug_outputs.linkmaps,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.embedded_bundles_partial(
            platform_prerequisites = platform_prerequisites,
            plugins = [archive],
        ),
        partials.macos_additional_contents_partial(
            additional_contents = ctx.attr.additional_contents,
        ),
        partials.resources_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            environment_plist = ctx.file._environment_plist,
            executable_name = executable_name,
            launch_storyboard = None,
            platform_prerequisites = platform_prerequisites,
            resource_deps = resource_deps,
            rule_descriptor = rule_descriptor,
            rule_label = label,
            top_level_infoplists = top_level_infoplists,
            version = ctx.attr.version,
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.apple_symbols_file_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            dependency_targets = [],
            dsym_binaries = debug_outputs.dsym_binaries,
            label_name = label.name,
            include_symbols_in_bundle = False,
            platform_prerequisites = platform_prerequisites,
        ),
    ]

    if provisioning_profile:
        processor_partials.append(
            partials.provisioning_profile_partial(
                actions = actions,
                extension = "provisionprofile",
                location = processor.location.content,
                profile_artifact = provisioning_profile,
                rule_label = label,
            ),
        )

    processor_result = processor.process(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        codesign_inputs = ctx.files.codesign_inputs,
        codesignopts = codesigning_support.codesignopts_from_rule_ctx(ctx),
        entitlements = entitlements.codesigning,
        features = features,
        ipa_post_processor = ctx.executable.ipa_post_processor,
        partials = processor_partials,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_mac_toolchain_info.process_and_sign_template,
        provisioning_profile = provisioning_profile,
        rule_descriptor = rule_descriptor,
        rule_label = label,
    )

    return [
        DefaultInfo(
            files = processor_result.output_files,
        ),
        MacosSpotlightImporterBundleInfo(),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
            )
        ),
        # TODO(b/228856372): Remove when downstream users are migrated off this provider.
        link_result.debug_outputs_provider,
    ] + processor_result.providers

def _macos_xpc_service_impl(ctx):
    """Implementation of macos_xpc_service."""
    actions = ctx.actions
    apple_mac_toolchain_info = ctx.attr._mac_toolchain[AppleMacToolsToolchainInfo]
    apple_xplat_toolchain_info = ctx.attr._xplat_toolchain[AppleXPlatToolsToolchainInfo]
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    executable_name = bundling_support.executable_name(ctx)
    features = features_support.compute_enabled_features(
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    provisioning_profile = ctx.file.provisioning_profile
    resource_deps = ctx.attr.deps + ctx.attr.resources
    rule_descriptor = rule_support.rule_descriptor(ctx)
    top_level_infoplists = resources.collect(
        attr = ctx.attr,
        res_attrs = ["infoplists"],
    )

    entitlements = entitlements_support.process_entitlements(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        bundle_id = bundle_id,
        entitlements_file = ctx.file.entitlements,
        platform_prerequisites = platform_prerequisites,
        product_type = rule_descriptor.product_type,
        provisioning_profile = provisioning_profile,
        rule_label = label,
        validation_mode = ctx.attr.entitlements_validation,
    )

    link_result = linking_support.register_binary_linking_action(
        ctx,
        entitlements = entitlements.linking,
        platform_prerequisites = platform_prerequisites,
        stamp = ctx.attr.stamp,
    )
    binary_artifact = link_result.binary
    debug_outputs = linking_support.debug_outputs_by_architecture(link_result.outputs)

    archive = outputs.archive(
        actions = actions,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
    )

    processor_partials = [
        partials.apple_bundle_info_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            executable_name = executable_name,
            bundle_id = bundle_id,
            entitlements = entitlements.bundle,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            product_type = rule_descriptor.product_type,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            executable_name = executable_name,
            label_name = label.name,
        ),
        partials.clang_rt_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            features = features,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            dylibs = clang_rt_dylibs.get_from_toolchain(ctx),
        ),
        partials.codesigning_dossier_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_location = processor.location.xpc_service,
            bundle_name = bundle_name,
            embed_target_dossiers = False,
            entitlements = entitlements.codesigning,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            provisioning_profile = provisioning_profile,
            rule_descriptor = rule_descriptor,
        ),
        partials.debug_symbols_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = ctx.attr.additional_contents.keys(),
            dsym_binaries = debug_outputs.dsym_binaries,
            dsym_info_plist_template = apple_mac_toolchain_info.dsym_info_plist_template,
            executable_name = executable_name,
            linkmaps = debug_outputs.linkmaps,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.embedded_bundles_partial(
            platform_prerequisites = platform_prerequisites,
            xpc_services = [archive],
        ),
        partials.macos_additional_contents_partial(
            additional_contents = ctx.attr.additional_contents,
        ),
        partials.resources_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            environment_plist = ctx.file._environment_plist,
            executable_name = executable_name,
            launch_storyboard = None,
            platform_prerequisites = platform_prerequisites,
            resource_deps = resource_deps,
            rule_descriptor = rule_descriptor,
            rule_label = label,
            top_level_infoplists = top_level_infoplists,
            version = ctx.attr.version,
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.apple_symbols_file_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            dependency_targets = [],
            dsym_binaries = debug_outputs.dsym_binaries,
            label_name = label.name,
            include_symbols_in_bundle = False,
            platform_prerequisites = platform_prerequisites,
        ),
    ]

    if provisioning_profile:
        processor_partials.append(
            partials.provisioning_profile_partial(
                actions = actions,
                extension = "provisionprofile",
                location = processor.location.content,
                profile_artifact = provisioning_profile,
                rule_label = label,
            ),
        )

    processor_result = processor.process(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        codesign_inputs = ctx.files.codesign_inputs,
        codesignopts = codesigning_support.codesignopts_from_rule_ctx(ctx),
        entitlements = entitlements.codesigning,
        executable_name = executable_name,
        features = features,
        ipa_post_processor = ctx.executable.ipa_post_processor,
        partials = processor_partials,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_mac_toolchain_info.process_and_sign_template,
        provisioning_profile = provisioning_profile,
        rule_descriptor = rule_descriptor,
        rule_label = label,
    )

    return [
        DefaultInfo(
            files = processor_result.output_files,
        ),
        MacosXPCServiceBundleInfo(),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
            )
        ),
        # TODO(b/228856372): Remove when downstream users are migrated off this provider.
        link_result.debug_outputs_provider,
    ] + processor_result.providers

def _macos_command_line_application_impl(ctx):
    """Implementation of the macos_command_line_application rule."""
    actions = ctx.actions
    apple_mac_toolchain_info = ctx.attr._mac_toolchain[AppleMacToolsToolchainInfo]
    apple_xplat_toolchain_info = ctx.attr._xplat_toolchain[AppleXPlatToolsToolchainInfo]
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    executable_name = bundling_support.executable_name(ctx)
    features = features_support.compute_enabled_features(
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    provisioning_profile = ctx.file.provisioning_profile
    rule_descriptor = rule_support.rule_descriptor(ctx)

    link_result = linking_support.register_binary_linking_action(
        ctx,
        # Command-line applications do not have entitlements.
        entitlements = None,
        platform_prerequisites = platform_prerequisites,
        stamp = ctx.attr.stamp,
    )
    binary_artifact = link_result.binary
    debug_outputs = linking_support.debug_outputs_by_architecture(link_result.outputs)

    debug_outputs_partial = partials.debug_symbols_partial(
        actions = actions,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        dsym_binaries = debug_outputs.dsym_binaries,
        dsym_info_plist_template = apple_mac_toolchain_info.dsym_info_plist_template,
        executable_name = executable_name,
        linkmaps = debug_outputs.linkmaps,
        platform_prerequisites = platform_prerequisites,
    )

    processor_result = processor.process(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        bundle_post_process_and_sign = False,
        codesign_inputs = ctx.files.codesign_inputs,
        codesignopts = codesigning_support.codesignopts_from_rule_ctx(ctx),
        executable_name = executable_name,
        features = features,
        ipa_post_processor = None,
        partials = [debug_outputs_partial],
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_mac_toolchain_info.process_and_sign_template,
        provisioning_profile = provisioning_profile,
        rule_descriptor = rule_descriptor,
        rule_label = label,
    )
    output_file = actions.declare_file(label.name)
    codesigning_support.sign_binary_action(
        actions = actions,
        codesign_inputs = ctx.files.codesign_inputs,
        codesignopts = codesigning_support.codesignopts_from_rule_ctx(ctx),
        input_binary = binary_artifact,
        output_binary = output_file,
        platform_prerequisites = platform_prerequisites,
        provisioning_profile = provisioning_profile,
        resolved_codesigningtool = apple_mac_toolchain_info.resolved_codesigningtool,
        rule_descriptor = rule_descriptor,
    )

    infoplists = [
        x[AppleBinaryInfoplistInfo].infoplist
        for x in getattr(ctx.attr, "deps", [])
        if AppleBinaryInfoplistInfo in x
    ]

    # There should only be one `AppleBinaryInfoplistInfo` providing dep
    infoplist = infoplists[0] if infoplists else None

    runfiles = []
    if clang_rt_dylibs.should_package_clang_runtime(features = features):
        runfiles = clang_rt_dylibs.get_from_toolchain(ctx)

    return [
        AppleBinaryInfo(
            binary = output_file,
            infoplist = infoplist,
            product_type = rule_descriptor.product_type,
        ),
        DefaultInfo(
            executable = output_file,
            files = depset(transitive = [
                depset([output_file]),
                processor_result.output_files,
            ]),
            runfiles = ctx.runfiles(runfiles),
        ),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
            )
        ),
        apple_common.new_executable_binary_provider(
            binary = output_file,
            cc_info = link_result.cc_info,
            objc = link_result.objc,
        ),
        # TODO(b/228856372): Remove when downstream users are migrated off this provider.
        link_result.debug_outputs_provider,
    ] + processor_result.providers

def _macos_dylib_impl(ctx):
    """Implementation of the macos_dylib rule."""
    actions = ctx.actions
    apple_mac_toolchain_info = ctx.attr._mac_toolchain[AppleMacToolsToolchainInfo]
    apple_xplat_toolchain_info = ctx.attr._xplat_toolchain[AppleXPlatToolsToolchainInfo]
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    executable_name = bundling_support.executable_name(ctx)
    features = features_support.compute_enabled_features(
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    provisioning_profile = ctx.file.provisioning_profile
    rule_descriptor = rule_support.rule_descriptor(ctx)

    link_result = linking_support.register_binary_linking_action(
        ctx,
        # Dynamic libraries do not have entitlements.
        entitlements = None,
        extra_linkopts = ["-dynamiclib"],
        platform_prerequisites = platform_prerequisites,
        stamp = ctx.attr.stamp,
    )
    binary_artifact = link_result.binary
    debug_outputs = linking_support.debug_outputs_by_architecture(link_result.outputs)

    debug_outputs_partial = partials.debug_symbols_partial(
        actions = actions,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        dsym_binaries = debug_outputs.dsym_binaries,
        dsym_info_plist_template = apple_mac_toolchain_info.dsym_info_plist_template,
        executable_name = executable_name,
        linkmaps = debug_outputs.linkmaps,
        platform_prerequisites = platform_prerequisites,
    )

    processor_result = processor.process(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        bundle_post_process_and_sign = False,
        codesign_inputs = ctx.files.codesign_inputs,
        codesignopts = codesigning_support.codesignopts_from_rule_ctx(ctx),
        executable_name = executable_name,
        features = features,
        ipa_post_processor = None,
        partials = [debug_outputs_partial],
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_mac_toolchain_info.process_and_sign_template,
        provisioning_profile = provisioning_profile,
        rule_descriptor = rule_descriptor,
        rule_label = label,
    )
    output_file = actions.declare_file(label.name + ".dylib")
    codesigning_support.sign_binary_action(
        actions = actions,
        codesign_inputs = ctx.files.codesign_inputs,
        codesignopts = codesigning_support.codesignopts_from_rule_ctx(ctx),
        input_binary = binary_artifact,
        output_binary = output_file,
        platform_prerequisites = platform_prerequisites,
        provisioning_profile = provisioning_profile,
        resolved_codesigningtool = apple_mac_toolchain_info.resolved_codesigningtool,
        rule_descriptor = rule_descriptor,
    )

    infoplists = [
        x[AppleBinaryInfoplistInfo].infoplist
        for x in getattr(ctx.attr, "deps", [])
        if AppleBinaryInfoplistInfo in x
    ]

    # There should only be one `AppleBinaryInfoplistInfo` providing dep
    infoplist = infoplists[0] if infoplists else None

    return [
        AppleBinaryInfo(
            binary = output_file,
            infoplist = infoplist,
            product_type = rule_descriptor.product_type,
        ),
        DefaultInfo(files = depset(transitive = [
            depset([output_file]),
            processor_result.output_files,
        ])),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
                {"dylib": depset(direct = [output_file])},
            )
        ),
        # TODO(b/228856372): Remove when downstream users are migrated off this provider.
        link_result.debug_outputs_provider,
    ] + processor_result.providers

macos_application = rule_factory.create_apple_bundling_rule(
    implementation = _macos_application_impl,
    platform_type = "macos",
    product_type = apple_product_type.application,
    doc = """Builds and bundles a macOS Application.

This rule creates an application that is a `.app` bundle. If you want to build a
simple command line tool as a standalone binary, use
[`macos_command_line_application`](#macos_command_line_application) instead.""",
)

macos_bundle = rule_factory.create_apple_bundling_rule(
    implementation = _macos_bundle_impl,
    platform_type = "macos",
    product_type = apple_product_type.bundle,
    doc = "Builds and bundles a macOS Loadable Bundle.",
)

macos_extension = rule_factory.create_apple_bundling_rule(
    implementation = _macos_extension_impl,
    platform_type = "macos",
    product_type = apple_product_type.app_extension,
    doc = """Builds and bundles a macOS Application Extension.

Most macOS app extensions use a plug-in-based architecture where the
executable's entry point is provided by a system framework. However, macOS 11
introduced Widget Extensions that use a traditional `main` entry
point (typically expressed through Swift's `@main` attribute).""",
)

macos_quick_look_plugin = rule_factory.create_apple_bundling_rule(
    implementation = _macos_quick_look_plugin_impl,
    platform_type = "macos",
    product_type = apple_product_type.quicklook_plugin,
    doc = "Builds and bundles a macOS Quick Look Plugin.",
)

macos_kernel_extension = rule_factory.create_apple_bundling_rule(
    implementation = _macos_kernel_extension_impl,
    platform_type = "macos",
    product_type = apple_product_type.kernel_extension,
    doc = "Builds and bundles a macOS Kernel Extension.",
    cfg = transition_support.apple_rule_arm64_as_arm64e_transition,
)

macos_spotlight_importer = rule_factory.create_apple_bundling_rule(
    implementation = _macos_spotlight_importer_impl,
    platform_type = "macos",
    product_type = apple_product_type.spotlight_importer,
    doc = "Builds and bundles a macOS Spotlight Importer.",
)

macos_xpc_service = rule_factory.create_apple_bundling_rule(
    implementation = _macos_xpc_service_impl,
    platform_type = "macos",
    product_type = apple_product_type.xpc_service,
    doc = "Builds and bundles a macOS XPC Service.",
)

macos_command_line_application = rule_factory.create_apple_binary_rule(
    implementation = _macos_command_line_application_impl,
    platform_type = "macos",
    product_type = apple_product_type.tool,
    doc = """Builds a macOS Command Line Application binary.


A command line application is a standalone binary file, rather than a `.app`
bundle like those produced by [`macos_application`](#macos_application). Unlike
a plain `apple_binary` target, however, this rule supports versioning and
embedding an `Info.plist` into the binary and allows the binary to be
code-signed.

Targets created with `macos_command_line_application` can be executed using
`bazel run`.""",
    additional_attrs = {
        "_cc_toolchain": attr.label(default = "@bazel_tools//tools/cpp:current_cc_toolchain"),
    },
)

macos_dylib = rule_factory.create_apple_binary_rule(
    implementation = _macos_dylib_impl,
    platform_type = "macos",
    product_type = apple_product_type.dylib,
    doc = "Builds a macOS Dylib binary.",
)

def _macos_framework_impl(ctx):
    """Experimental implementation of macos_framework."""
    actions = ctx.actions
    apple_mac_toolchain_info = ctx.attr._mac_toolchain[AppleMacToolsToolchainInfo]
    apple_xplat_toolchain_info = ctx.attr._xplat_toolchain[AppleXPlatToolsToolchainInfo]
    bin_root_path = ctx.bin_dir.path
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    executable_name = bundling_support.executable_name(ctx)
    cc_toolchain = find_cpp_toolchain(ctx)
    cc_features = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        language = "objc",
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    features = features_support.compute_enabled_features(
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    provisioning_profile = ctx.file.provisioning_profile
    resource_deps = ctx.attr.deps + ctx.attr.resources
    rule_descriptor = rule_support.rule_descriptor(ctx)
    signed_frameworks = []
    if provisioning_profile:
        signed_frameworks = [
            bundle_name + rule_descriptor.bundle_extension,
        ]
    top_level_infoplists = resources.collect(
        attr = ctx.attr,
        res_attrs = ["infoplists"],
    )
    top_level_resources = resources.collect(
        attr = ctx.attr,
        res_attrs = ["resources"],
    )

    extra_linkopts = [
        "-dynamiclib",
        "-Wl,-install_name,@rpath/{name}{extension}/{name}".format(
            extension = bundle_extension,
            name = bundle_name,
        ),
    ]
    if ctx.attr.extension_safe:
        extra_linkopts.append("-fapplication-extension")

    link_result = linking_support.register_binary_linking_action(
        ctx,
        avoid_deps = ctx.attr.frameworks,
        # Frameworks do not have entitlements.
        entitlements = None,
        extra_linkopts = extra_linkopts,
        platform_prerequisites = platform_prerequisites,
        stamp = ctx.attr.stamp,
    )
    binary_artifact = link_result.binary
    debug_outputs = linking_support.debug_outputs_by_architecture(link_result.outputs)

    archive_for_embedding = outputs.archive_for_embedding(
        actions = actions,
        bundle_name = bundle_name,
        bundle_extension = bundle_extension,
        executable_name = executable_name,
        label_name = label.name,
        rule_descriptor = rule_descriptor,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
    )

    processor_partials = [
        partials.apple_bundle_info_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            executable_name = executable_name,
            extension_safe = ctx.attr.extension_safe,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            product_type = rule_descriptor.product_type,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            executable_name = executable_name,
            label_name = label.name,
        ),
        partials.codesigning_dossier_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_location = processor.location.framework,
            bundle_name = bundle_name,
            embed_target_dossiers = False,
            embedded_targets = ctx.attr.frameworks,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            provisioning_profile = provisioning_profile,
            rule_descriptor = rule_descriptor,
        ),
        # TODO(kaipi): Check if clang_rt dylibs are needed in Frameworks, or if
        # the can be skipped.
        partials.clang_rt_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            features = features,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            dylibs = clang_rt_dylibs.get_from_toolchain(ctx),
        ),
        partials.debug_symbols_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = ctx.attr.frameworks,
            dsym_binaries = debug_outputs.dsym_binaries,
            dsym_info_plist_template = apple_mac_toolchain_info.dsym_info_plist_template,
            executable_name = executable_name,
            linkmaps = debug_outputs.linkmaps,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.embedded_bundles_partial(
            frameworks = [archive_for_embedding],
            embeddable_targets = ctx.attr.frameworks,
            platform_prerequisites = platform_prerequisites,
            signed_frameworks = depset(signed_frameworks),
        ),
        partials.extension_safe_validation_partial(
            is_extension_safe = ctx.attr.extension_safe,
            rule_label = label,
            targets_to_validate = ctx.attr.frameworks,
        ),
        partials.framework_headers_partial(hdrs = ctx.files.hdrs),
        partials.framework_provider_partial(
            actions = actions,
            bin_root_path = bin_root_path,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            bundle_only = ctx.attr.bundle_only,
            cc_features = cc_features,
            cc_info = link_result.cc_info,
            cc_toolchain = cc_toolchain,
            objc_provider = link_result.objc,
            rule_label = label,
        ),
        partials.resources_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            environment_plist = ctx.file._environment_plist,
            executable_name = executable_name,
            launch_storyboard = None,
            platform_prerequisites = platform_prerequisites,
            resource_deps = resource_deps,
            rule_descriptor = rule_descriptor,
            rule_label = label,
            targets_to_avoid = ctx.attr.frameworks,
            top_level_infoplists = top_level_infoplists,
            top_level_resources = top_level_resources,
            version = ctx.attr.version,
            version_keys_required = False,
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            dependency_targets = ctx.attr.frameworks,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.apple_symbols_file_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            dependency_targets = ctx.attr.frameworks,
            dsym_binaries = debug_outputs.dsym_binaries,
            label_name = label.name,
            include_symbols_in_bundle = False,
            platform_prerequisites = platform_prerequisites,
        ),
    ]

    processor_result = processor.process(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        codesign_inputs = ctx.files.codesign_inputs,
        codesignopts = codesigning_support.codesignopts_from_rule_ctx(ctx),
        executable_name = executable_name,
        features = features,
        ipa_post_processor = ctx.executable.ipa_post_processor,
        partials = processor_partials,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_mac_toolchain_info.process_and_sign_template,
        provisioning_profile = provisioning_profile,
        rule_descriptor = rule_descriptor,
        rule_label = label,
    )

    return [
        DefaultInfo(files = processor_result.output_files),
        AppleFrameworkBundleInfo(),
        MacosFrameworkBundleInfo(),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
            )
        ),
        # TODO(b/228856372): Remove when downstream users are migrated off this provider.
        link_result.debug_outputs_provider,
    ] + processor_result.providers

def _macos_dynamic_framework_impl(ctx):
    """Experimental implementation of macos_dynamic_framework."""

    # This rule should only have one swift_library dependency. This means len(ctx.attr.deps) should be 1
    swiftdeps = [x for x in ctx.attr.deps if SwiftInfo in x]
    if len(swiftdeps) != 1 or len(ctx.attr.deps) > 1:
        fail(
            """\
    error: Swift dynamic frameworks expect a single swift_library dependency.
    """,
        )

    binary_target = ctx.attr.deps[0]

    actions = ctx.actions
    apple_mac_toolchain_info = ctx.attr._mac_toolchain[AppleMacToolsToolchainInfo]
    apple_xplat_toolchain_info = ctx.attr._xplat_toolchain[AppleXPlatToolsToolchainInfo]
    bin_root_path = ctx.bin_dir.path
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    executable_name = bundling_support.executable_name(ctx)
    cc_toolchain = find_cpp_toolchain(ctx)
    cc_features = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        language = "objc",
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    features = features_support.compute_enabled_features(
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    provisioning_profile = ctx.file.provisioning_profile
    resource_deps = ctx.attr.deps + ctx.attr.resources
    rule_descriptor = rule_support.rule_descriptor(ctx)
    top_level_infoplists = resources.collect(
        attr = ctx.attr,
        res_attrs = ["infoplists"],
    )
    top_level_resources = resources.collect(
        attr = ctx.attr,
        res_attrs = [
            "app_icons",
            "launch_images",
            "launch_storyboard",
            "strings",
            "resources",
        ],
    )

    signed_frameworks = []
    if getattr(ctx.file, "provisioning_profile", None):
        signed_frameworks = [
            bundle_name + rule_descriptor.bundle_extension,
        ]

    extra_linkopts = [
        "-dynamiclib",
        "-Wl,-install_name,@rpath/{name}{extension}/{name}".format(
            extension = bundle_extension,
            name = bundle_name,
        ),
    ]
    if ctx.attr.extension_safe:
        extra_linkopts.append("-fapplication-extension")

    link_result = linking_support.register_binary_linking_action(
        ctx,
        avoid_deps = ctx.attr.frameworks,
        # Frameworks do not have entitlements.
        entitlements = None,
        extra_linkopts = extra_linkopts,
        platform_prerequisites = platform_prerequisites,
        stamp = ctx.attr.stamp,
    )
    binary_artifact = link_result.binary
    debug_outputs = linking_support.debug_outputs_by_architecture(link_result.outputs)

    archive_for_embedding = outputs.archive_for_embedding(
        actions = actions,
        bundle_name = bundle_name,
        bundle_extension = bundle_extension,
        executable_name = executable_name,
        label_name = label.name,
        rule_descriptor = rule_descriptor,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
    )

    processor_partials = [
        partials.apple_bundle_info_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            executable_name = executable_name,
            extension_safe = ctx.attr.extension_safe,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            product_type = rule_descriptor.product_type,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            executable_name = executable_name,
            label_name = label.name,
        ),
        partials.codesigning_dossier_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_location = processor.location.framework,
            bundle_name = bundle_name,
            embed_target_dossiers = False,
            embedded_targets = ctx.attr.frameworks,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            provisioning_profile = provisioning_profile,
            rule_descriptor = rule_descriptor,
        ),
        partials.clang_rt_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            features = features,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            dylibs = clang_rt_dylibs.get_from_toolchain(ctx),
        ),
        partials.debug_symbols_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = ctx.attr.frameworks,
            dsym_binaries = debug_outputs.dsym_binaries,
            dsym_info_plist_template = apple_mac_toolchain_info.dsym_info_plist_template,
            executable_name = executable_name,
            linkmaps = debug_outputs.linkmaps,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.embedded_bundles_partial(
            frameworks = [archive_for_embedding],
            embeddable_targets = ctx.attr.frameworks,
            platform_prerequisites = platform_prerequisites,
            signed_frameworks = depset(signed_frameworks),
        ),
        partials.extension_safe_validation_partial(
            is_extension_safe = ctx.attr.extension_safe,
            rule_label = label,
            targets_to_validate = ctx.attr.frameworks,
        ),
        partials.framework_provider_partial(
            actions = actions,
            bin_root_path = bin_root_path,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            bundle_only = False,
            cc_features = cc_features,
            cc_info = link_result.cc_info,
            cc_toolchain = cc_toolchain,
            objc_provider = link_result.objc,
            rule_label = label,
        ),
        partials.resources_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            environment_plist = ctx.file._environment_plist,
            executable_name = executable_name,
            launch_storyboard = None,
            platform_prerequisites = platform_prerequisites,
            resource_deps = resource_deps,
            rule_descriptor = rule_descriptor,
            rule_label = label,
            targets_to_avoid = ctx.attr.frameworks,
            top_level_infoplists = top_level_infoplists,
            top_level_resources = top_level_resources,
            version = ctx.attr.version,
            version_keys_required = False,
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            dependency_targets = ctx.attr.frameworks,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.swift_dynamic_framework_partial(
            actions = actions,
            bundle_name = bundle_name,
            label_name = label.name,
            swift_dynamic_framework_info = binary_target[SwiftDynamicFrameworkInfo],
        ),
    ]

    processor_result = processor.process(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        codesignopts = codesigning_support.codesignopts_from_rule_ctx(ctx),
        executable_name = executable_name,
        features = features,
        ipa_post_processor = ctx.executable.ipa_post_processor,
        partials = processor_partials,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_mac_toolchain_info.process_and_sign_template,
        provisioning_profile = provisioning_profile,
        rule_descriptor = rule_descriptor,
        rule_label = label,
    )

    providers = processor_result.providers

    additional_providers = []
    for provider in providers:
        if type(provider) == "AppleDynamicFramework":
            # Make the ObjC provider using the framework_files depset found
            # in the AppleDynamicFramework provider. This is to make the
            # macos_dynamic_framework usable as a dependency in swift_library
            libraries_to_link = libraries_to_link_for_dynamic_framework(
                actions = actions,
                cc_toolchain = cc_toolchain,
                feature_configuration = cc_features,
                libraries = provider.framework_files.to_list(),
            )
            additional_providers.extend([
                apple_common.new_objc_provider(
                    dynamic_framework_file = provider.framework_files,
                ),
                CcInfo(
                    linking_context = cc_common.create_linking_context(
                        linker_inputs = depset([
                            cc_common.create_linker_input(
                                owner = label,
                                libraries = depset(libraries_to_link),
                            ),
                        ]),
                    ),
                ),
            ])
    providers.extend(additional_providers)

    return [
        DefaultInfo(files = processor_result.output_files),
        MacosFrameworkBundleInfo(),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
            )
        ),
    ] + providers

def _macos_static_framework_impl(ctx):
    """Implementation of macos_static_framework."""

    actions = ctx.actions
    apple_mac_toolchain_info = ctx.attr._mac_toolchain[AppleMacToolsToolchainInfo]
    apple_xplat_toolchain_info = ctx.attr._xplat_toolchain[AppleXPlatToolsToolchainInfo]
    avoid_deps = ctx.attr.avoid_deps
    deps = ctx.attr.deps
    label = ctx.label
    predeclared_outputs = ctx.outputs
    split_deps = ctx.split_attr.deps
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    executable_name = bundling_support.executable_name(ctx)
    features = features_support.compute_enabled_features(
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    resource_deps = ctx.attr.deps + ctx.attr.resources
    rule_descriptor = rule_support.rule_descriptor(ctx)

    link_result = linking_support.register_static_library_linking_action(ctx = ctx)
    binary_artifact = link_result.library

    processor_partials = [
        partials.apple_bundle_info_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            executable_name = executable_name,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            product_type = rule_descriptor.product_type,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            executable_name = executable_name,
            label_name = label.name,
        ),
    ]

    swift_infos = {}
    if swift_support.uses_swift(deps):
        for link_output in link_result.outputs:
            split_attr_key = transition_support.apple_common_multi_arch_split_key(
                cpu = link_output.architecture,
                environment = link_output.environment,
                platform_type = link_output.platform,
            )
            for dep in split_deps[split_attr_key]:
                if SwiftInfo in dep:
                    swift_infos[link_output.architecture] = dep[SwiftInfo]

    # If there's any Swift dependencies on the static framework rule, treat it as a Swift static
    # framework.
    if swift_infos:
        processor_partials.append(
            partials.swift_framework_partial(
                actions = actions,
                avoid_deps = avoid_deps,
                bundle_name = bundle_name,
                label_name = label.name,
                swift_infos = swift_infos,
            ),
        )
    else:
        processor_partials.append(
            partials.framework_header_modulemap_partial(
                actions = actions,
                bundle_name = bundle_name,
                hdrs = ctx.files.hdrs,
                label_name = label.name,
                sdk_dylibs = cc_info_support.get_sdk_dylibs(deps = deps),
                sdk_frameworks = cc_info_support.get_sdk_frameworks(deps = deps),
                umbrella_header = ctx.file.umbrella_header,
            ),
        )

    if not ctx.attr.exclude_resources:
        processor_partials.append(partials.resources_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            environment_plist = ctx.file._environment_plist,
            executable_name = executable_name,
            launch_storyboard = None,
            platform_prerequisites = platform_prerequisites,
            resource_deps = resource_deps,
            rule_descriptor = rule_descriptor,
            rule_label = label,
            version = None,
        ))

    processor_result = processor.process(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        codesign_inputs = ctx.files.codesign_inputs,
        codesignopts = codesigning_support.codesignopts_from_rule_ctx(ctx),
        executable_name = executable_name,
        features = features,
        ipa_post_processor = ctx.executable.ipa_post_processor,
        partials = processor_partials,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_mac_toolchain_info.process_and_sign_template,
        rule_descriptor = rule_descriptor,
        rule_label = label,
    )

    return [
        DefaultInfo(files = processor_result.output_files),
        MacosStaticFrameworkBundleInfo(),
        OutputGroupInfo(**processor_result.output_groups),
    ] + processor_result.providers

macos_framework = rule_factory.create_apple_bundling_rule(
    implementation = _macos_framework_impl,
    platform_type = "macos",
    product_type = apple_product_type.framework,
    doc = """Builds and bundles an macOS Dynamic Framework.

To use this framework for your app and extensions, list it in the `frameworks` attributes
of those `macos_application` and/or `macos_extension` rules.""",
)

macos_dynamic_framework = rule_factory.create_apple_bundling_rule(
    implementation = _macos_dynamic_framework_impl,
    platform_type = "macos",
    product_type = apple_product_type.framework,
    doc = "Builds and bundles a macOS dynamic framework that is consumable by Xcode.",
)

macos_static_framework = rule_factory.create_apple_bundling_rule(
    implementation = _macos_static_framework_impl,
    platform_type = "macos",
    product_type = apple_product_type.static_framework,
    doc = """Builds and bundles a macOS static framework for third-party distribution.

A static framework is bundled like a dynamic framework except that the embedded
binary is a static library rather than a dynamic library. It is intended to
create distributable static SDKs or artifacts that can be easily imported into
other Xcode projects; it is specifically **not** intended to be used as a
dependency of other Bazel targets. For that use case, use the corresponding
`objc_library` targets directly.

Unlike other macOS bundles, the fat binary in an `macos_static_framework` may
simultaneously contain simulator and device architectures (that is, you can
build a single framework artifact that works for all architectures by specifying
`--macos_cpus=x86_64,arm64` when you build).

`macos_static_framework` supports Swift, but there are some constraints:

* `macos_static_framework` with Swift only works with Xcode 11 and above, since
  the required Swift functionality for module compatibility is available in
  Swift 5.1.
* `macos_static_framework` only supports a single direct `swift_library` target
  that does not depend transitively on any other `swift_library` targets. The
  Swift compiler expects a framework to contain a single Swift module, and each
  `swift_library` target is its own module by definition.
* `macos_static_framework` does not support mixed Objective-C and Swift public
  interfaces. This means that the `umbrella_header` and `hdrs` attributes are
  unavailable when using `swift_library` dependencies. You are allowed to depend
  on `objc_library` from the main `swift_library` dependency, but note that only
  the `swift_library`'s public interface will be available to users of the
  static framework.

When using Swift, the `macos_static_framework` bundles `swiftinterface` and
`swiftdocs` file for each of the required architectures. It also bundles an
umbrella header which is the header generated by the single `swift_library`
target. Finally, it also bundles a `module.modulemap` file pointing to the
umbrella header for Objetive-C module compatibility. This umbrella header and
modulemap can be skipped by disabling the `swift.no_generated_header` feature (
i.e. `--features=-swift.no_generated_header`).""",
)
