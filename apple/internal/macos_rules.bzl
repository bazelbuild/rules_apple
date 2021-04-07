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
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBinaryInfo",
    "AppleSupportToolchainInfo",
    "MacosApplicationBundleInfo",
    "MacosBundleBundleInfo",
    "MacosExtensionBundleInfo",
    "MacosKernelExtensionBundleInfo",
    "MacosQuickLookPluginBundleInfo",
    "MacosSpotlightImporterBundleInfo",
    "MacosXPCServiceBundleInfo",
)

def _macos_application_impl(ctx):
    """Implementation of macos_application."""
    link_result = linking_support.register_linking_action(
        ctx,
        stamp = ctx.attr.stamp,
    )
    binary_artifact = link_result.binary_provider.binary
    debug_outputs_provider = link_result.debug_outputs_provider

    embedded_targets = ctx.attr.extensions + ctx.attr.xpc_services

    actions = ctx.actions
    apple_toolchain_info = ctx.attr._toolchain[AppleSupportToolchainInfo]
    bin_root_path = ctx.bin_dir.path
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    executable_name = bundling_support.executable_name(ctx)
    bundle_verification_targets = [struct(target = ext) for ext in embedded_targets]
    entitlements = entitlements_support.entitlements(
        entitlements_attr = getattr(ctx.attr, "entitlements", None),
        entitlements_file = getattr(ctx.file, "entitlements", None),
    )
    features = features_support.compute_enabled_features(
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    rule_descriptor = rule_support.rule_descriptor(ctx)

    processor_partials = [
        partials.apple_bundle_info_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            executable_name = executable_name,
            entitlements = entitlements,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            product_type = rule_descriptor.product_type,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            executable_name = executable_name,
            label_name = label.name,
        ),
        partials.clang_rt_dylibs_partial(
            actions = actions,
            apple_toolchain_info = apple_toolchain_info,
            binary_artifact = binary_artifact,
            features = features,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.debug_symbols_partial(
            actions = actions,
            bin_root_path = bin_root_path,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = embedded_targets + ctx.attr.additional_contents.keys(),
            debug_outputs_provider = debug_outputs_provider,
            dsym_info_plist_template = apple_toolchain_info.dsym_info_plist_template,
            executable_name = executable_name,
            package_symbols = True,
            platform_prerequisites = platform_prerequisites,
            rule_label = label,
        ),
        partials.embedded_bundles_partial(
            bundle_embedded_bundles = True,
            embeddable_targets = embedded_targets,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.framework_import_partial(
            actions = actions,
            apple_toolchain_info = apple_toolchain_info,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            provisioning_profile = getattr(ctx.file, "provisioning_profile", None),
            rule_descriptor = rule_descriptor,
            targets = ctx.attr.deps + embedded_targets,
        ),
        partials.macos_additional_contents_partial(
            additional_contents = ctx.attr.additional_contents,
        ),
        partials.resources_partial(
            actions = actions,
            apple_toolchain_info = apple_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            executable_name = executable_name,
            bundle_verification_targets = bundle_verification_targets,
            environment_plist = ctx.file._environment_plist,
            launch_storyboard = None,
            platform_prerequisites = platform_prerequisites,
            plist_attrs = ["infoplists"],
            rule_attrs = ctx.attr,
            rule_descriptor = rule_descriptor,
            rule_label = label,
            top_level_attrs = [
                "app_icons",
                "strings",
                "resources",
            ],
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            apple_toolchain_info = apple_toolchain_info,
            binary_artifact = binary_artifact,
            bundle_dylibs = True,
            dependency_targets = embedded_targets,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
    ]

    if ctx.file.provisioning_profile:
        processor_partials.append(
            partials.provisioning_profile_partial(
                actions = actions,
                extension = "provisionprofile",
                location = processor.location.content,
                profile_artifact = ctx.file.provisioning_profile,
                rule_label = label,
            ),
        )

    processor_result = processor.process(
        actions = actions,
        apple_toolchain_info = apple_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        codesign_inputs = ctx.files.codesign_inputs,
        codesignopts = codesigning_support.codesignopts_from_rule_ctx(ctx),
        entitlements = entitlements,
        executable_name = executable_name,
        ipa_post_processor = ctx.executable.ipa_post_processor,
        partials = processor_partials,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_toolchain_info.process_and_sign_template,
        provisioning_profile = getattr(ctx.file, "provisioning_profile", None),
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
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
    )

    return [
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
        link_result.binary_provider,
    ] + processor_result.providers

def _macos_bundle_impl(ctx):
    """Implementation of macos_bundle."""
    link_result = linking_support.register_linking_action(
        ctx,
        stamp = ctx.attr.stamp,
    )
    binary_artifact = link_result.binary_provider.binary
    debug_outputs_provider = link_result.debug_outputs_provider

    actions = ctx.actions
    apple_toolchain_info = ctx.attr._toolchain[AppleSupportToolchainInfo]
    bin_root_path = ctx.bin_dir.path
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    executable_name = bundling_support.executable_name(ctx)
    entitlements = entitlements_support.entitlements(
        entitlements_attr = getattr(ctx.attr, "entitlements", None),
        entitlements_file = getattr(ctx.file, "entitlements", None),
    )
    features = features_support.compute_enabled_features(
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    rule_descriptor = rule_support.rule_descriptor(ctx)

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
            entitlements = entitlements,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            product_type = rule_descriptor.product_type,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            executable_name = executable_name,
            label_name = label.name,
        ),
        partials.clang_rt_dylibs_partial(
            actions = actions,
            apple_toolchain_info = apple_toolchain_info,
            binary_artifact = binary_artifact,
            features = features,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.debug_symbols_partial(
            actions = actions,
            bin_root_path = bin_root_path,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = ctx.attr.additional_contents.keys(),
            debug_outputs_provider = debug_outputs_provider,
            dsym_info_plist_template = apple_toolchain_info.dsym_info_plist_template,
            executable_name = executable_name,
            platform_prerequisites = platform_prerequisites,
            rule_label = label,
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
            apple_toolchain_info = apple_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            environment_plist = ctx.file._environment_plist,
            executable_name = executable_name,
            launch_storyboard = None,
            platform_prerequisites = platform_prerequisites,
            plist_attrs = ["infoplists"],
            rule_attrs = ctx.attr,
            rule_descriptor = rule_descriptor,
            rule_label = label,
            top_level_attrs = [
                "app_icons",
                "strings",
                "resources",
            ],
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            apple_toolchain_info = apple_toolchain_info,
            binary_artifact = binary_artifact,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
    ]

    if ctx.file.provisioning_profile:
        processor_partials.append(
            partials.provisioning_profile_partial(
                actions = actions,
                extension = "provisionprofile",
                location = processor.location.content,
                profile_artifact = ctx.file.provisioning_profile,
                rule_label = label,
            ),
        )

    processor_result = processor.process(
        actions = actions,
        apple_toolchain_info = apple_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        codesign_inputs = ctx.files.codesign_inputs,
        codesignopts = codesigning_support.codesignopts_from_rule_ctx(ctx),
        entitlements = entitlements,
        executable_name = executable_name,
        ipa_post_processor = ctx.executable.ipa_post_processor,
        partials = processor_partials,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_toolchain_info.process_and_sign_template,
        provisioning_profile = getattr(ctx.file, "provisioning_profile", None),
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
    ] + processor_result.providers

def _macos_extension_impl(ctx):
    """Experimental implementation of macos_extension."""
    link_result = linking_support.register_linking_action(
        ctx,
        stamp = ctx.attr.stamp,
    )
    binary_artifact = link_result.binary_provider.binary
    debug_outputs_provider = link_result.debug_outputs_provider

    actions = ctx.actions
    apple_toolchain_info = ctx.attr._toolchain[AppleSupportToolchainInfo]
    bin_root_path = ctx.bin_dir.path
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    executable_name = bundling_support.executable_name(ctx)
    entitlements = entitlements_support.entitlements(
        entitlements_attr = getattr(ctx.attr, "entitlements", None),
        entitlements_file = getattr(ctx.file, "entitlements", None),
    )
    features = features_support.compute_enabled_features(
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    rule_descriptor = rule_support.rule_descriptor(ctx)

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
            executable_name = executable_name,
            entitlements = entitlements,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            product_type = rule_descriptor.product_type,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            executable_name = executable_name,
            label_name = label.name,
        ),
        partials.clang_rt_dylibs_partial(
            actions = actions,
            apple_toolchain_info = apple_toolchain_info,
            binary_artifact = binary_artifact,
            features = features,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.debug_symbols_partial(
            actions = actions,
            bin_root_path = bin_root_path,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = ctx.attr.additional_contents.keys(),
            debug_outputs_provider = debug_outputs_provider,
            dsym_info_plist_template = apple_toolchain_info.dsym_info_plist_template,
            executable_name = executable_name,
            platform_prerequisites = platform_prerequisites,
            rule_label = label,
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
            apple_toolchain_info = apple_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            environment_plist = ctx.file._environment_plist,
            executable_name = executable_name,
            launch_storyboard = None,
            platform_prerequisites = platform_prerequisites,
            plist_attrs = ["infoplists"],
            rule_attrs = ctx.attr,
            rule_descriptor = rule_descriptor,
            rule_label = label,
            top_level_attrs = [
                "app_icons",
                "strings",
                "resources",
            ],
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            apple_toolchain_info = apple_toolchain_info,
            binary_artifact = binary_artifact,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
    ]

    if ctx.file.provisioning_profile:
        processor_partials.append(
            partials.provisioning_profile_partial(
                actions = actions,
                extension = "provisionprofile",
                location = processor.location.content,
                profile_artifact = ctx.file.provisioning_profile,
                rule_label = label,
            ),
        )

    processor_result = processor.process(
        actions = actions,
        apple_toolchain_info = apple_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        codesign_inputs = ctx.files.codesign_inputs,
        codesignopts = codesigning_support.codesignopts_from_rule_ctx(ctx),
        entitlements = entitlements,
        executable_name = executable_name,
        ipa_post_processor = ctx.executable.ipa_post_processor,
        partials = processor_partials,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_toolchain_info.process_and_sign_template,
        provisioning_profile = getattr(ctx.file, "provisioning_profile", None),
        rule_descriptor = rule_descriptor,
        rule_label = label,
    )

    return [
        DefaultInfo(
            files = processor_result.output_files,
        ),
        MacosExtensionBundleInfo(),
        link_result.binary_provider,
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
            )
        ),
    ] + processor_result.providers

def _macos_quick_look_plugin_impl(ctx):
    """Experimental implementation of macos_quick_look_plugin."""
    extra_linkopts = [
        "-install_name",
        "\"/Library/Frameworks/{0}.qlgenerator/{0}\"".format(ctx.attr.bundle_name),
    ]
    link_result = linking_support.register_linking_action(
        ctx,
        extra_linkopts = extra_linkopts,
        stamp = ctx.attr.stamp,
    )
    binary_artifact = link_result.binary_provider.binary
    debug_outputs_provider = link_result.debug_outputs_provider

    actions = ctx.actions
    apple_toolchain_info = ctx.attr._toolchain[AppleSupportToolchainInfo]
    bin_root_path = ctx.bin_dir.path
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    executable_name = bundling_support.executable_name(ctx)
    entitlements = entitlements_support.entitlements(
        entitlements_attr = getattr(ctx.attr, "entitlements", None),
        entitlements_file = getattr(ctx.file, "entitlements", None),
    )
    features = features_support.compute_enabled_features(
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    rule_descriptor = rule_support.rule_descriptor(ctx)

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
            entitlements = entitlements,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            product_type = rule_descriptor.product_type,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            executable_name = executable_name,
            label_name = label.name,
        ),
        # TODO(kaipi): Check if clang_rt dylibs are needed in Quick Look plugins, or if
        # they can be skipped.
        partials.clang_rt_dylibs_partial(
            actions = actions,
            apple_toolchain_info = apple_toolchain_info,
            binary_artifact = binary_artifact,
            features = features,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.debug_symbols_partial(
            actions = actions,
            bin_root_path = bin_root_path,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = ctx.attr.additional_contents.keys(),
            debug_outputs_provider = debug_outputs_provider,
            dsym_info_plist_template = apple_toolchain_info.dsym_info_plist_template,
            executable_name = executable_name,
            platform_prerequisites = platform_prerequisites,
            rule_label = label,
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
            apple_toolchain_info = apple_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            environment_plist = ctx.file._environment_plist,
            executable_name = executable_name,
            launch_storyboard = None,
            platform_prerequisites = platform_prerequisites,
            plist_attrs = ["infoplists"],
            rule_attrs = ctx.attr,
            rule_descriptor = rule_descriptor,
            rule_label = label,
            top_level_attrs = [
                "strings",
                "resources",
            ],
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            apple_toolchain_info = apple_toolchain_info,
            binary_artifact = binary_artifact,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
    ]

    if ctx.file.provisioning_profile:
        processor_partials.append(
            partials.provisioning_profile_partial(
                actions = actions,
                extension = "provisionprofile",
                location = processor.location.content,
                profile_artifact = ctx.file.provisioning_profile,
                rule_label = label,
            ),
        )

    processor_result = processor.process(
        actions = actions,
        apple_toolchain_info = apple_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        codesignopts = codesigning_support.codesignopts_from_rule_ctx(ctx),
        entitlements = entitlements,
        executable_name = executable_name,
        ipa_post_processor = ctx.executable.ipa_post_processor,
        partials = processor_partials,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_toolchain_info.process_and_sign_template,
        provisioning_profile = getattr(ctx.file, "provisioning_profile", None),
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
    ] + processor_result.providers

def _macos_kernel_extension_impl(ctx):
    """Implementation of macos_kernel_extension."""
    link_result = linking_support.register_linking_action(
        ctx,
        stamp = ctx.attr.stamp,
    )
    binary_artifact = link_result.binary_provider.binary
    debug_outputs_provider = link_result.debug_outputs_provider

    actions = ctx.actions
    apple_toolchain_info = ctx.attr._toolchain[AppleSupportToolchainInfo]
    bin_root_path = ctx.bin_dir.path
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    executable_name = bundling_support.executable_name(ctx)
    entitlements = entitlements_support.entitlements(
        entitlements_attr = getattr(ctx.attr, "entitlements", None),
        entitlements_file = getattr(ctx.file, "entitlements", None),
    )
    features = features_support.compute_enabled_features(
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    rule_descriptor = rule_support.rule_descriptor(ctx)

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
            entitlements = entitlements,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            product_type = rule_descriptor.product_type,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            executable_name = executable_name,
            label_name = label.name,
        ),
        partials.clang_rt_dylibs_partial(
            actions = actions,
            apple_toolchain_info = apple_toolchain_info,
            binary_artifact = binary_artifact,
            features = features,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.debug_symbols_partial(
            actions = actions,
            bin_root_path = bin_root_path,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = ctx.attr.additional_contents.keys(),
            debug_outputs_provider = debug_outputs_provider,
            dsym_info_plist_template = apple_toolchain_info.dsym_info_plist_template,
            executable_name = executable_name,
            platform_prerequisites = platform_prerequisites,
            rule_label = label,
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
            apple_toolchain_info = apple_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            environment_plist = ctx.file._environment_plist,
            executable_name = executable_name,
            launch_storyboard = None,
            platform_prerequisites = platform_prerequisites,
            plist_attrs = ["infoplists"],
            rule_attrs = ctx.attr,
            rule_descriptor = rule_descriptor,
            rule_label = label,
            top_level_attrs = ["resources"],
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            apple_toolchain_info = apple_toolchain_info,
            binary_artifact = binary_artifact,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
    ]

    if ctx.file.provisioning_profile:
        processor_partials.append(
            partials.provisioning_profile_partial(
                actions = actions,
                extension = "provisionprofile",
                location = processor.location.content,
                profile_artifact = ctx.file.provisioning_profile,
                rule_label = label,
            ),
        )

    processor_result = processor.process(
        actions = actions,
        apple_toolchain_info = apple_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        codesign_inputs = ctx.files.codesign_inputs,
        codesignopts = codesigning_support.codesignopts_from_rule_ctx(ctx),
        entitlements = entitlements,
        executable_name = executable_name,
        ipa_post_processor = ctx.executable.ipa_post_processor,
        partials = processor_partials,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_toolchain_info.process_and_sign_template,
        provisioning_profile = getattr(ctx.file, "provisioning_profile", None),
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
    ] + processor_result.providers

def _macos_spotlight_importer_impl(ctx):
    """Implementation of macos_spotlight_importer."""
    link_result = linking_support.register_linking_action(
        ctx,
        stamp = ctx.attr.stamp,
    )
    binary_artifact = link_result.binary_provider.binary
    debug_outputs_provider = link_result.debug_outputs_provider

    actions = ctx.actions
    apple_toolchain_info = ctx.attr._toolchain[AppleSupportToolchainInfo]
    bin_root_path = ctx.bin_dir.path
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    executable_name = bundling_support.executable_name(ctx)
    entitlements = entitlements_support.entitlements(
        entitlements_attr = getattr(ctx.attr, "entitlements", None),
        entitlements_file = getattr(ctx.file, "entitlements", None),
    )
    features = features_support.compute_enabled_features(
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    rule_descriptor = rule_support.rule_descriptor(ctx)

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
            entitlements = entitlements,
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
            apple_toolchain_info = apple_toolchain_info,
            binary_artifact = binary_artifact,
            features = features,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.debug_symbols_partial(
            actions = actions,
            bin_root_path = bin_root_path,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = ctx.attr.additional_contents.keys(),
            debug_outputs_provider = debug_outputs_provider,
            dsym_info_plist_template = apple_toolchain_info.dsym_info_plist_template,
            executable_name = executable_name,
            platform_prerequisites = platform_prerequisites,
            rule_label = label,
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
            apple_toolchain_info = apple_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            environment_plist = ctx.file._environment_plist,
            executable_name = executable_name,
            launch_storyboard = None,
            platform_prerequisites = platform_prerequisites,
            plist_attrs = ["infoplists"],
            rule_attrs = ctx.attr,
            rule_descriptor = rule_descriptor,
            rule_label = label,
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            apple_toolchain_info = apple_toolchain_info,
            binary_artifact = binary_artifact,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
    ]

    if ctx.file.provisioning_profile:
        processor_partials.append(
            partials.provisioning_profile_partial(
                actions = actions,
                extension = "provisionprofile",
                location = processor.location.content,
                profile_artifact = ctx.file.provisioning_profile,
                rule_label = label,
            ),
        )

    processor_result = processor.process(
        actions = actions,
        apple_toolchain_info = apple_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        codesign_inputs = ctx.files.codesign_inputs,
        codesignopts = codesigning_support.codesignopts_from_rule_ctx(ctx),
        entitlements = entitlements,
        ipa_post_processor = ctx.executable.ipa_post_processor,
        partials = processor_partials,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_toolchain_info.process_and_sign_template,
        provisioning_profile = getattr(ctx.file, "provisioning_profile", None),
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
    ] + processor_result.providers

def _macos_xpc_service_impl(ctx):
    """Implementation of macos_xpc_service."""
    link_result = linking_support.register_linking_action(
        ctx,
        stamp = ctx.attr.stamp,
    )
    binary_artifact = link_result.binary_provider.binary
    debug_outputs_provider = link_result.debug_outputs_provider

    actions = ctx.actions
    apple_toolchain_info = ctx.attr._toolchain[AppleSupportToolchainInfo]
    bin_root_path = ctx.bin_dir.path
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    executable_name = bundling_support.executable_name(ctx)
    entitlements = entitlements_support.entitlements(
        entitlements_attr = getattr(ctx.attr, "entitlements", None),
        entitlements_file = getattr(ctx.file, "entitlements", None),
    )
    features = features_support.compute_enabled_features(
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    rule_descriptor = rule_support.rule_descriptor(ctx)

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
            entitlements = entitlements,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            product_type = rule_descriptor.product_type,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            executable_name = executable_name,
            label_name = label.name,
        ),
        partials.clang_rt_dylibs_partial(
            actions = actions,
            apple_toolchain_info = apple_toolchain_info,
            binary_artifact = binary_artifact,
            features = features,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.debug_symbols_partial(
            actions = actions,
            bin_root_path = bin_root_path,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = ctx.attr.additional_contents.keys(),
            debug_outputs_provider = debug_outputs_provider,
            dsym_info_plist_template = apple_toolchain_info.dsym_info_plist_template,
            executable_name = executable_name,
            platform_prerequisites = platform_prerequisites,
            rule_label = label,
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
            apple_toolchain_info = apple_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            environment_plist = ctx.file._environment_plist,
            executable_name = executable_name,
            launch_storyboard = None,
            platform_prerequisites = platform_prerequisites,
            plist_attrs = ["infoplists"],
            rule_attrs = ctx.attr,
            rule_descriptor = rule_descriptor,
            rule_label = label,
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            apple_toolchain_info = apple_toolchain_info,
            binary_artifact = binary_artifact,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
    ]

    if ctx.file.provisioning_profile:
        processor_partials.append(
            partials.provisioning_profile_partial(
                actions = actions,
                extension = "provisionprofile",
                location = processor.location.content,
                profile_artifact = ctx.file.provisioning_profile,
                rule_label = label,
            ),
        )

    processor_result = processor.process(
        actions = actions,
        apple_toolchain_info = apple_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        codesign_inputs = ctx.files.codesign_inputs,
        codesignopts = codesigning_support.codesignopts_from_rule_ctx(ctx),
        entitlements = entitlements,
        executable_name = executable_name,
        ipa_post_processor = ctx.executable.ipa_post_processor,
        partials = processor_partials,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_toolchain_info.process_and_sign_template,
        provisioning_profile = getattr(ctx.file, "provisioning_profile", None),
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
    ] + processor_result.providers

def _macos_command_line_application_impl(ctx):
    """Implementation of the macos_command_line_application rule."""
    link_result = linking_support.register_linking_action(
        ctx,
        stamp = ctx.attr.stamp,
    )
    binary_artifact = link_result.binary_provider.binary
    debug_outputs_provider = link_result.debug_outputs_provider

    actions = ctx.actions
    apple_toolchain_info = ctx.attr._toolchain[AppleSupportToolchainInfo]
    bin_root_path = ctx.bin_dir.path
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    executable_name = bundling_support.executable_name(ctx)
    entitlements = entitlements_support.entitlements(
        entitlements_attr = getattr(ctx.attr, "entitlements", None),
        entitlements_file = getattr(ctx.file, "entitlements", None),
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    rule_descriptor = rule_support.rule_descriptor(ctx)

    debug_outputs_partial = partials.debug_symbols_partial(
        actions = actions,
        bin_root_path = bin_root_path,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        debug_outputs_provider = debug_outputs_provider,
        dsym_info_plist_template = apple_toolchain_info.dsym_info_plist_template,
        executable_name = executable_name,
        platform_prerequisites = platform_prerequisites,
        rule_label = label,
    )

    processor_result = processor.process(
        actions = actions,
        apple_toolchain_info = apple_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        bundle_post_process_and_sign = False,
        codesign_inputs = ctx.files.codesign_inputs,
        codesignopts = codesigning_support.codesignopts_from_rule_ctx(ctx),
        entitlements = entitlements,
        executable_name = executable_name,
        ipa_post_processor = None,
        partials = [debug_outputs_partial],
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_toolchain_info.process_and_sign_template,
        provisioning_profile = getattr(ctx.file, "provisioning_profile", None),
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
        provisioning_profile = getattr(ctx.file, "provisioning_profile", None),
        resolved_codesigningtool = apple_toolchain_info.resolved_codesigningtool,
        rule_descriptor = rule_descriptor,
    )

    return [
        AppleBinaryInfo(
            binary = output_file,
            product_type = rule_descriptor.product_type,
        ),
        DefaultInfo(
            executable = output_file,
            files = depset(transitive = [
                depset([output_file]),
                processor_result.output_files,
            ]),
        ),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
            )
        ),
        link_result.binary_provider,
    ] + processor_result.providers

def _macos_dylib_impl(ctx):
    """Implementation of the macos_dylib rule."""
    link_result = linking_support.register_linking_action(
        ctx,
        stamp = ctx.attr.stamp,
    )
    binary_artifact = link_result.binary_provider.binary
    debug_outputs_provider = link_result.debug_outputs_provider

    actions = ctx.actions
    apple_toolchain_info = ctx.attr._toolchain[AppleSupportToolchainInfo]
    bin_root_path = ctx.bin_dir.path
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    executable_name = bundling_support.executable_name(ctx)
    entitlements = entitlements_support.entitlements(
        entitlements_attr = getattr(ctx.attr, "entitlements", None),
        entitlements_file = getattr(ctx.file, "entitlements", None),
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    rule_descriptor = rule_support.rule_descriptor(ctx)

    debug_outputs_partial = partials.debug_symbols_partial(
        actions = actions,
        bin_root_path = bin_root_path,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        debug_outputs_provider = debug_outputs_provider,
        dsym_info_plist_template = apple_toolchain_info.dsym_info_plist_template,
        executable_name = executable_name,
        platform_prerequisites = platform_prerequisites,
        rule_label = label,
    )

    processor_result = processor.process(
        actions = actions,
        apple_toolchain_info = apple_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        bundle_post_process_and_sign = False,
        codesign_inputs = ctx.files.codesign_inputs,
        codesignopts = codesigning_support.codesignopts_from_rule_ctx(ctx),
        entitlements = entitlements,
        executable_name = executable_name,
        ipa_post_processor = None,
        partials = [debug_outputs_partial],
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_toolchain_info.process_and_sign_template,
        provisioning_profile = getattr(ctx.file, "provisioning_profile", None),
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
        provisioning_profile = getattr(ctx.file, "provisioning_profile", None),
        resolved_codesigningtool = apple_toolchain_info.resolved_codesigningtool,
        rule_descriptor = rule_descriptor,
    )

    return [
        AppleBinaryInfo(
            binary = output_file,
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
        link_result.binary_provider,
    ] + processor_result.providers

macos_application = rule_factory.create_apple_bundling_rule(
    implementation = _macos_application_impl,
    platform_type = "macos",
    product_type = apple_product_type.application,
    doc = "Builds and bundles a macOS Application.",
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
    doc = "Builds and bundles a macOS Application Extension.",
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
    doc = "Builds a macOS Command Line Application binary.",
)

macos_dylib = rule_factory.create_apple_binary_rule(
    implementation = _macos_dylib_impl,
    platform_type = "macos",
    product_type = apple_product_type.dylib,
    doc = "Builds a macOS Dylib binary.",
)
