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

"""Implementation of watchOS rules."""

load(
    "@bazel_tools//tools/cpp:toolchain_utils.bzl",
    "find_cpp_toolchain",
)
load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load("@build_bazel_apple_support//xcode:providers.bzl", "XcodeVersionInfo")
load(
    "@build_bazel_rules_apple//apple/internal:apple_bundler.bzl",
    "apple_bundler",
)
load(
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/internal:bundling_support.bzl",
    "bundle_id_suffix_default",
    "bundling_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:bundling_tasks.bzl",
    "bundling_tasks",
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
    "@build_bazel_rules_apple//apple/internal:infoplist_support.bzl",
    "infoplist_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:linking_support.bzl",
    "linking_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:location_enum.bzl",
    "location_enum",
)
load(
    "@build_bazel_rules_apple//apple/internal:outputs.bzl",
    "outputs",
)
load(
    "@build_bazel_rules_apple//apple/internal:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "AppleBundleInfo",
    "WatchosExtensionBundleInfo",
    "WatchosFrameworkBundleInfo",
    "new_appleframeworkbundleinfo",
    "new_watchosapplicationbundleinfo",
    "new_watchosextensionbundleinfo",
    "new_watchosframeworkbundleinfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:required_minimum_os.bzl",
    "required_minimum_os",
)
load(
    "@build_bazel_rules_apple//apple/internal:resources.bzl",
    "resources",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_attrs.bzl",
    "rule_attrs",
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
    "@build_bazel_rules_apple//apple/internal:swift_support.bzl",
    "swift_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:transition_support.bzl",
    "transition_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/aspects:framework_provider_aspect.bzl",
    "framework_provider_aspect",
)
load(
    "@build_bazel_rules_apple//apple/internal/aspects:resource_aspect.bzl",
    "apple_resource_aspect",
)
load(
    "@build_bazel_rules_apple//apple/internal/aspects:swift_const_values_aspect.bzl",
    "swift_const_values_aspect",
)
load(
    "@build_bazel_rules_apple//apple/internal/providers:extension_foundation_info.bzl",
    "ExtensionFoundationInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/toolchains:apple_toolchains.bzl",
    "apple_toolchain_utils",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:clang_rt_dylibs.bzl",
    "clang_rt_dylibs",
)

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

def _watchos_extension_impl(ctx):
    """Implementation of watchos_extension."""
    required_minimum_os.validate(
        cc_toolchain_forwarder = ctx.split_attr._cc_toolchain_forwarder,
        minimum_os_version = ctx.attr.minimum_os_version,
        platform_type = ctx.attr.platform_type,
        rule_label = ctx.label,
        xcode_version_config = ctx.attr._xcode_config[XcodeVersionInfo],
    )

    apple_xplat_toolchain_info = apple_toolchain_utils.get_xplat_toolchain(ctx)

    is_extensionkit_extension = ctx.attr.extensionkit_extension
    product_type = (
        apple_product_type.extensionkit_extension if is_extensionkit_extension else apple_product_type.app_extension
    )

    rule_descriptor = rule_support.rule_descriptor(
        platform_type = ctx.attr.platform_type,
        product_type = product_type,
    )

    actions = ctx.actions
    apple_mac_toolchain_info = apple_toolchain_utils.get_mac_toolchain(ctx)
    mac_exec_group = apple_toolchain_utils.get_mac_exec_group(ctx)
    xplat_exec_group = apple_toolchain_utils.get_xplat_exec_group(ctx)

    bundle_name, bundle_extension = bundling_support.bundle_full_name(
        custom_bundle_name = ctx.attr.bundle_name,
        label_name = ctx.label.name,
        rule_descriptor = rule_descriptor,
    )

    bundle_id = bundling_support.bundle_full_id(
        bundle_id = ctx.attr.bundle_id,
        bundle_id_suffix = ctx.attr.bundle_id_suffix,
        bundle_name = bundle_name,
        suffix_default = ctx.attr._bundle_id_suffix_default,
        shared_capabilities = ctx.attr.shared_capabilities,
    )
    cc_configured_features = features_support.cc_configured_features(
        ctx = ctx,
    )
    cc_toolchain_forwarder = ctx.split_attr._cc_toolchain_forwarder
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites(
        apple_platform_info = platform_support.apple_platform_info_from_rule_ctx(ctx),
        config_vars = ctx.var,
        cpp_fragment = ctx.fragments.cpp,
        device_families = rule_descriptor.allowed_device_families,
        explicit_minimum_os = ctx.attr.minimum_os_version,
        uses_swift = swift_support.uses_swift(ctx.attr.deps),
        xcode_version_config = ctx.attr._xcode_config[XcodeVersionInfo],
    )
    predeclared_outputs = ctx.outputs
    provisioning_profile = ctx.file.provisioning_profile
    resource_deps = ctx.attr.deps + ctx.attr.resources
    top_level_infoplists = resources.collect(
        attr = ctx.attr,
        res_attrs = ["infoplists"],
        rule_label = ctx.label,
    )
    top_level_resources = resources.collect(
        attr = ctx.attr,
        res_attrs = [
            "app_icons",
            "strings",
            "resources",
        ],
        rule_label = ctx.label,
    )

    entitlements = entitlements_support.process_entitlements(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_id = bundle_id,
        cc_configured_features = cc_configured_features,
        cc_toolchains = cc_toolchain_forwarder,
        entitlements_file = ctx.file.entitlements,
        mac_exec_group = mac_exec_group,
        platform_prerequisites = platform_prerequisites,
        product_type = rule_descriptor.product_type,
        provisioning_profile = provisioning_profile,
        rule_label = label,
        secure_features = ctx.attr.secure_features,
        validation_mode = ctx.attr.entitlements_validation,
        xplat_exec_group = xplat_exec_group,
    )

    extra_linkopts = [
        "-fapplication-extension",
        "-e",
        "_NSExtensionMain",
    ]

    link_result = linking_support.register_binary_linking_action(
        ctx,
        avoid_deps = ctx.attr.frameworks,
        bundle_name = bundle_name,
        cc_configured_features = cc_configured_features,
        cc_toolchains = cc_toolchain_forwarder,
        entitlements = entitlements,
        exported_symbols_lists = ctx.files.exported_symbols_lists,
        extra_linkopts = extra_linkopts,
        platform_prerequisites = platform_prerequisites,
        rule_descriptor = rule_descriptor,
        stamp = ctx.attr.stamp,
    )
    binary_artifact = link_result.binary
    debug_outputs = linking_support.debug_outputs_by_architecture(link_result.outputs)

    archive = outputs.archive(
        actions = actions,
        build_settings = apple_xplat_toolchain_info.build_settings,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        predeclared_outputs = predeclared_outputs,
    )

    bundle_location = ""
    embedded_bundles_args = {}
    if rule_descriptor.product_type == apple_product_type.app_extension:
        bundle_location = location_enum.plugin
        embedded_bundles_args["plugins"] = [archive]
    elif rule_descriptor.product_type == apple_product_type.extensionkit_extension:
        bundle_location = location_enum.extension
        embedded_bundles_args["extensions"] = [archive]
    else:
        fail("Internal Error: Unexpectedly found product_type " + rule_descriptor.product_type)

    extension_foundation = infoplist_support.extension_foundation_infoplist(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        bundle_id = bundle_id,
        is_extensionkit_extension = is_extensionkit_extension,
        label = label,
        mac_exec_group = mac_exec_group,
        platform_prerequisites = platform_prerequisites,
        split_attr_deps = ctx.split_attr.deps,
    )
    extra_resource_providers = extension_foundation.resource_providers
    pending_bundling_tasks = [
        bundling_tasks.apple_bundle_info(
            actions = actions,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            cc_toolchains = cc_toolchain_forwarder,
            entitlements = entitlements,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            product_type = rule_descriptor.product_type,
        ),
        bundling_tasks.app_intents_metadata_bundle(
            actions = actions,
            app_intents = [ctx.split_attr.deps],
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            bundle_id = bundle_id,
            cc_toolchains = cc_toolchain_forwarder,
            embedded_bundles = ctx.attr.frameworks,
            frameworks = ctx.attr.frameworks,
            label = label,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            xplat_exec_group = xplat_exec_group,
        ),
        bundling_tasks.binary(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            label_name = label.name,
        ),
        bundling_tasks.child_bundle_info_validation(
            frameworks = ctx.attr.frameworks,
            platform_prerequisites = platform_prerequisites,
            product_type = rule_descriptor.product_type,
            resource_validation_infos = ctx.attr.deps,
            rule_label = label,
        ),
        bundling_tasks.clang_rt_dylibs(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            cc_configured_features = cc_configured_features,
            dylibs = clang_rt_dylibs.get_from_toolchain(ctx),
            label_name = label.name,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
        ),
        bundling_tasks.codesigning_dossier(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_location = bundle_location,
            bundle_name = bundle_name,
            embedded_targets = ctx.attr.frameworks,
            entitlements = entitlements,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            provisioning_profile = provisioning_profile,
            rule_descriptor = rule_descriptor,
            rule_label = label,
            xplat_exec_group = xplat_exec_group,
        ),
        bundling_tasks.debug_symbols(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = ctx.attr.frameworks + resource_deps,
            dsym_outputs = debug_outputs.dsym_outputs,
            linkmaps = debug_outputs.linkmaps,
            platform_prerequisites = platform_prerequisites,
        ),
        bundling_tasks.embedded_bundles(
            build_settings = apple_xplat_toolchain_info.build_settings,
            embeddable_targets = ctx.attr.frameworks,
            **embedded_bundles_args
        ),
        bundling_tasks.extension_safe_validation(
            is_extension_safe = True,
            rule_label = label,
            targets_to_validate = ctx.attr.frameworks,
        ),
        bundling_tasks.resources(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            environment_plist = ctx.file._environment_plist,
            extra_resource_providers = extra_resource_providers,
            extensionkit_keys_required = is_extensionkit_extension,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            resource_deps = resource_deps,
            resource_locales = ctx.attr.resource_locales,
            rule_descriptor = rule_descriptor,
            rule_label = label,
            targets_to_avoid = ctx.attr.frameworks,
            top_level_infoplists = top_level_infoplists,
            top_level_resources = top_level_resources,
            version = ctx.attr.version,
            xplat_exec_group = xplat_exec_group,
        ),
        bundling_tasks.swift_dylibs(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            binary_artifact = binary_artifact,
            dependency_targets = ctx.attr.frameworks,
            label_name = label.name,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            xplat_exec_group = xplat_exec_group,
        ),
    ]

    if platform_prerequisites.platform.is_device:
        pending_bundling_tasks.append(
            bundling_tasks.provisioning_profile(
                actions = actions,
                profile_artifact = provisioning_profile,
                rule_label = label,
            ),
        )

    bundler_result = apple_bundler.process(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        bundling_tasks = pending_bundling_tasks,
        cc_configured_features = cc_configured_features,
        entitlements = entitlements,
        ipa_post_processor = ctx.executable.ipa_post_processor,
        mac_exec_group = mac_exec_group,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_mac_toolchain_info.process_and_sign_template,
        provisioning_profile = provisioning_profile,
        rule_descriptor = rule_descriptor,
        rule_label = label,
        xplat_exec_group = xplat_exec_group,
    )

    result_providers = [
        DefaultInfo(
            files = bundler_result.output_files,
        ),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                bundler_result.output_groups,
            )
        ),
        new_watchosextensionbundleinfo(),
    ] + bundler_result.providers

    if extension_foundation and extension_foundation.swiftconstvalues_files:
        result_providers.append(ExtensionFoundationInfo(
            swiftconstvalues_files = depset(extension_foundation.swiftconstvalues_files),
        ))

    return result_providers

def _watchos_application_impl(ctx):
    """Implementation of watchos_application."""
    required_minimum_os.validate(
        cc_toolchain_forwarder = ctx.split_attr._cc_toolchain_forwarder,
        minimum_os_version = ctx.attr.minimum_os_version,
        platform_type = ctx.attr.platform_type,
        rule_label = ctx.label,
        xcode_version_config = ctx.attr._xcode_config[XcodeVersionInfo],
    )

    rule_descriptor = rule_support.rule_descriptor(
        platform_type = ctx.attr.platform_type,
        product_type = apple_product_type.application,
    )

    actions = ctx.actions
    apple_mac_toolchain_info = apple_toolchain_utils.get_mac_toolchain(ctx)
    apple_xplat_toolchain_info = apple_toolchain_utils.get_xplat_toolchain(ctx)
    mac_exec_group = apple_toolchain_utils.get_mac_exec_group(ctx)
    xplat_exec_group = apple_toolchain_utils.get_xplat_exec_group(ctx)

    bundle_name, bundle_extension = bundling_support.bundle_full_name(
        custom_bundle_name = ctx.attr.bundle_name,
        label_name = ctx.label.name,
        rule_descriptor = rule_descriptor,
    )
    bundle_id = bundling_support.bundle_full_id(
        bundle_id = ctx.attr.bundle_id,
        bundle_id_suffix = ctx.attr.bundle_id_suffix,
        bundle_name = bundle_name,
        suffix_default = ctx.attr._bundle_id_suffix_default,
        shared_capabilities = ctx.attr.shared_capabilities,
    )
    bundle_verification_targets = [struct(target = ext) for ext in ctx.attr.extensions]
    cc_configured_features = features_support.cc_configured_features(
        ctx = ctx,
    )
    cc_toolchain_forwarder = ctx.split_attr._cc_toolchain_forwarder
    embeddable_targets = ctx.attr.frameworks + ctx.attr.extensions
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites(
        apple_platform_info = platform_support.apple_platform_info_from_rule_ctx(ctx),
        config_vars = ctx.var,
        cpp_fragment = ctx.fragments.cpp,
        device_families = rule_descriptor.allowed_device_families,
        explicit_minimum_os = ctx.attr.minimum_os_version,
        uses_swift = swift_support.uses_swift(ctx.attr.deps),
        xcode_version_config = ctx.attr._xcode_config[XcodeVersionInfo],
    )
    predeclared_outputs = ctx.outputs
    provisioning_profile = ctx.file.provisioning_profile
    resource_deps = ctx.attr.deps + ctx.attr.resources
    top_level_infoplists = resources.collect(
        attr = ctx.attr,
        res_attrs = ["infoplists"],
        rule_label = ctx.label,
    )
    top_level_resources = resources.collect(
        attr = ctx.attr,
        res_attrs = [
            "app_icons",
            "storyboards",
            "strings",
            "resources",
        ],
        rule_label = ctx.label,
    )

    entitlements = entitlements_support.process_entitlements(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_id = bundle_id,
        cc_configured_features = cc_configured_features,
        cc_toolchains = cc_toolchain_forwarder,
        entitlements_file = ctx.file.entitlements,
        mac_exec_group = mac_exec_group,
        platform_prerequisites = platform_prerequisites,
        product_type = rule_descriptor.product_type,
        provisioning_profile = provisioning_profile,
        rule_label = label,
        secure_features = ctx.attr.secure_features,
        validation_mode = ctx.attr.entitlements_validation,
        xplat_exec_group = xplat_exec_group,
    )

    link_result = linking_support.register_binary_linking_action(
        ctx,
        avoid_deps = ctx.attr.frameworks,
        bundle_name = bundle_name,
        cc_configured_features = cc_configured_features,
        cc_toolchains = cc_toolchain_forwarder,
        entitlements = entitlements,
        exported_symbols_lists = ctx.files.exported_symbols_lists,
        extra_linkopts = [],
        platform_prerequisites = platform_prerequisites,
        rule_descriptor = rule_descriptor,
        stamp = ctx.attr.stamp,
    )
    binary_artifact = link_result.binary
    debug_outputs = linking_support.debug_outputs_by_architecture(link_result.outputs)

    archive = outputs.archive(
        actions = actions,
        build_settings = apple_xplat_toolchain_info.build_settings,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        predeclared_outputs = predeclared_outputs,
    )

    pending_bundling_tasks = [
        bundling_tasks.apple_bundle_info(
            actions = actions,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            cc_toolchains = cc_toolchain_forwarder,
            entitlements = entitlements,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            product_type = rule_descriptor.product_type,
        ),
        bundling_tasks.app_intents_metadata_bundle(
            actions = actions,
            app_intents = [ctx.split_attr.deps],
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            bundle_id = bundle_id,
            cc_toolchains = cc_toolchain_forwarder,
            embedded_bundles = embeddable_targets,
            frameworks = ctx.attr.frameworks,
            label = label,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            xplat_exec_group = xplat_exec_group,
        ),
        bundling_tasks.binary(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            label_name = label.name,
        ),
        bundling_tasks.clang_rt_dylibs(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            cc_configured_features = cc_configured_features,
            dylibs = clang_rt_dylibs.get_from_toolchain(ctx),
            label_name = label.name,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
        ),
        bundling_tasks.child_bundle_info_validation(
            frameworks = ctx.attr.frameworks,
            platform_prerequisites = platform_prerequisites,
            product_type = rule_descriptor.product_type,
            resource_validation_infos = ctx.attr.deps,
            rule_label = label,
        ),
        bundling_tasks.codesigning_dossier(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_location = location_enum.watch,
            bundle_name = bundle_name,
            embedded_targets = embeddable_targets,
            entitlements = entitlements,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            provisioning_profile = provisioning_profile,
            rule_descriptor = rule_descriptor,
            rule_label = label,
            xplat_exec_group = xplat_exec_group,
        ),
        bundling_tasks.debug_symbols(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = embeddable_targets + resource_deps,
            dsym_outputs = debug_outputs.dsym_outputs,
            linkmaps = debug_outputs.linkmaps,
            platform_prerequisites = platform_prerequisites,
        ),
        bundling_tasks.embedded_bundles(
            build_settings = apple_xplat_toolchain_info.build_settings,
            bundle_embedded_bundles = True,
            embeddable_targets = embeddable_targets,
            watch_bundles = [archive],
        ),
        bundling_tasks.framework_import(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            build_settings = apple_xplat_toolchain_info.build_settings,
            cc_configured_features = cc_configured_features,
            label_name = label.name,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            provisioning_profile = provisioning_profile,
            rule_descriptor = rule_descriptor,
            targets = ctx.attr.deps + ctx.attr.extensions + ctx.attr.frameworks,
        ),
        bundling_tasks.resources(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            bundle_verification_targets = bundle_verification_targets,
            environment_plist = ctx.file._environment_plist,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            resource_deps = resource_deps,
            resource_locales = ctx.attr.resource_locales,
            rule_descriptor = rule_descriptor,
            rule_label = label,
            targets_to_avoid = ctx.attr.frameworks,
            top_level_infoplists = top_level_infoplists,
            top_level_resources = top_level_resources,
            version = ctx.attr.version,
            xplat_exec_group = xplat_exec_group,
        ),
        bundling_tasks.swift_dylibs(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            binary_artifact = binary_artifact,
            bundle_dylibs = True,
            dependency_targets = embeddable_targets,
            label_name = label.name,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            xplat_exec_group = xplat_exec_group,
        ),
    ]

    if platform_prerequisites.platform.is_device:
        pending_bundling_tasks.append(
            bundling_tasks.provisioning_profile(
                actions = actions,
                profile_artifact = provisioning_profile,
                rule_label = label,
            ),
        )

    bundler_result = apple_bundler.process(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        bundling_tasks = pending_bundling_tasks,
        cc_configured_features = cc_configured_features,
        entitlements = entitlements,
        ipa_post_processor = ctx.executable.ipa_post_processor,
        mac_exec_group = mac_exec_group,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_mac_toolchain_info.process_and_sign_template,
        provisioning_profile = provisioning_profile,
        rule_descriptor = rule_descriptor,
        rule_label = label,
        xplat_exec_group = xplat_exec_group,
    )

    executable = outputs.executable(
        actions = actions,
        label_name = label.name,
    )

    run_support.register_simulator_executable(
        actions = actions,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        output = executable,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        runner_template = ctx.file._runner_template,
    )

    return [
        DefaultInfo(
            executable = executable,
            files = bundler_result.output_files,
            runfiles = ctx.runfiles(
                files = [archive],
            ),
        ),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                bundler_result.output_groups,
            )
        ),
        new_watchosapplicationbundleinfo(),
    ] + bundler_result.providers

def _watchos_framework_impl(ctx):
    """Implementation of the watchos_framework rule."""
    required_minimum_os.validate(
        cc_toolchain_forwarder = ctx.split_attr._cc_toolchain_forwarder,
        minimum_os_version = ctx.attr.minimum_os_version,
        platform_type = ctx.attr.platform_type,
        rule_label = ctx.label,
        xcode_version_config = ctx.attr._xcode_config[XcodeVersionInfo],
    )

    rule_descriptor = rule_support.rule_descriptor(
        platform_type = ctx.attr.platform_type,
        product_type = apple_product_type.framework,
    )

    actions = ctx.actions
    apple_mac_toolchain_info = apple_toolchain_utils.get_mac_toolchain(ctx)
    mac_exec_group = apple_toolchain_utils.get_mac_exec_group(ctx)
    apple_xplat_toolchain_info = apple_toolchain_utils.get_xplat_toolchain(ctx)
    xplat_exec_group = apple_toolchain_utils.get_xplat_exec_group(ctx)
    bundle_name, bundle_extension = bundling_support.bundle_full_name(
        custom_bundle_name = ctx.attr.bundle_name,
        label_name = ctx.label.name,
        rule_descriptor = rule_descriptor,
    )
    bundle_id = bundling_support.bundle_full_id(
        base_bundle_id = ctx.attr.base_bundle_id,
        bundle_id = ctx.attr.bundle_id,
        bundle_id_suffix = ctx.attr.bundle_id_suffix,
        bundle_name = bundle_name,
        suffix_default = ctx.attr._bundle_id_suffix_default,
    )
    cc_configured_features = features_support.cc_configured_features(
        ctx = ctx,
        extra_requested_features = ["link_dylib"],
    )
    cc_toolchain_forwarder = ctx.split_attr._cc_toolchain_forwarder
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites(
        apple_platform_info = platform_support.apple_platform_info_from_rule_ctx(ctx),
        config_vars = ctx.var,
        cpp_fragment = ctx.fragments.cpp,
        device_families = ctx.attr.families,
        explicit_minimum_os = ctx.attr.minimum_os_version,
        uses_swift = swift_support.uses_swift(ctx.attr.deps),
        xcode_version_config = ctx.attr._xcode_config[XcodeVersionInfo],
    )
    predeclared_outputs = ctx.outputs
    provisioning_profile = ctx.file.provisioning_profile
    resource_deps = ctx.attr.deps + ctx.attr.resources
    signed_frameworks = []
    if provisioning_profile:
        signed_frameworks = [
            bundle_name + rule_descriptor.bundle_extension,
        ]
    top_level_infoplists = resources.collect(
        attr = ctx.attr,
        res_attrs = ["infoplists"],
        rule_label = ctx.label,
    )
    top_level_resources = resources.collect(
        attr = ctx.attr,
        res_attrs = ["resources"],
        rule_label = ctx.label,
    )

    link_result = linking_support.register_binary_linking_action(
        ctx,
        avoid_deps = ctx.attr.frameworks,
        bundle_name = bundle_name,
        cc_configured_features = cc_configured_features,
        cc_toolchains = cc_toolchain_forwarder,
        entitlements = None,  # Frameworks do not have entitlements.
        exported_symbols_lists = ctx.files.exported_symbols_lists,
        extra_linkopts = [
            "-install_name",
            "@rpath/{name}{extension}/{name}".format(
                extension = bundle_extension,
                name = bundle_name,
            ),
        ],
        platform_prerequisites = platform_prerequisites,
        rule_descriptor = rule_descriptor,
        stamp = ctx.attr.stamp,
    )
    binary_artifact = link_result.binary
    debug_outputs = linking_support.debug_outputs_by_architecture(link_result.outputs)
    linking_contexts = [output.linking_context for output in link_result.outputs]

    archive_for_embedding = outputs.archive_for_embedding(
        actions = actions,
        build_settings = apple_xplat_toolchain_info.build_settings,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        label_name = label.name,
        predeclared_outputs = predeclared_outputs,
        rule_descriptor = rule_descriptor,
    )

    pending_bundling_tasks = [
        bundling_tasks.app_intents_metadata_bundle(
            actions = actions,
            app_intents = [ctx.split_attr.deps],
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            bundle_id = bundle_id,
            cc_toolchains = cc_toolchain_forwarder,
            embedded_bundles = ctx.attr.frameworks,
            frameworks = ctx.attr.frameworks,
            label = label,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            xplat_exec_group = xplat_exec_group,
        ),
        bundling_tasks.apple_bundle_info(
            actions = actions,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            cc_toolchains = cc_toolchain_forwarder,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            product_type = rule_descriptor.product_type,
        ),
        bundling_tasks.binary(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            label_name = label.name,
        ),
        bundling_tasks.child_bundle_info_validation(
            frameworks = ctx.attr.frameworks,
            platform_prerequisites = platform_prerequisites,
            product_type = rule_descriptor.product_type,
            resource_validation_infos = ctx.attr.deps,
            rule_label = label,
        ),
        bundling_tasks.debug_symbols(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = ctx.attr.frameworks + resource_deps,
            dsym_outputs = debug_outputs.dsym_outputs,
            linkmaps = debug_outputs.linkmaps,
            platform_prerequisites = platform_prerequisites,
        ),
        bundling_tasks.embedded_bundles(
            build_settings = apple_xplat_toolchain_info.build_settings,
            embeddable_targets = ctx.attr.frameworks,
            frameworks = [archive_for_embedding],
            signed_frameworks = depset(signed_frameworks),
        ),
        bundling_tasks.extension_safe_validation(
            is_extension_safe = ctx.attr.extension_safe,
            rule_label = label,
            targets_to_validate = ctx.attr.frameworks,
        ),
        bundling_tasks.framework_provider(
            actions = actions,
            binary_artifact = binary_artifact,
            cc_configured_features = cc_configured_features,
            cc_linking_contexts = linking_contexts,
            cc_toolchain = find_cpp_toolchain(ctx),
            rule_label = label,
        ),
        bundling_tasks.resources(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            environment_plist = ctx.file._environment_plist,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            resource_deps = resource_deps,
            resource_locales = ctx.attr.resource_locales,
            rule_descriptor = rule_descriptor,
            rule_label = label,
            targets_to_avoid = ctx.attr.frameworks,
            top_level_infoplists = top_level_infoplists,
            top_level_resources = top_level_resources,
            version = ctx.attr.version,
            version_keys_required = False,
            xplat_exec_group = xplat_exec_group,
        ),
        bundling_tasks.swift_dylibs(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            binary_artifact = binary_artifact,
            dependency_targets = ctx.attr.frameworks,
            label_name = label.name,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            xplat_exec_group = xplat_exec_group,
        ),
    ]

    bundler_result = apple_bundler.process(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        bundling_tasks = pending_bundling_tasks,
        cc_configured_features = cc_configured_features,
        mac_exec_group = mac_exec_group,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_mac_toolchain_info.process_and_sign_template,
        provisioning_profile = provisioning_profile,
        rule_descriptor = rule_descriptor,
        rule_label = label,
        xplat_exec_group = xplat_exec_group,
    )

    return [
        DefaultInfo(files = bundler_result.output_files),
        new_appleframeworkbundleinfo(),
        new_watchosframeworkbundleinfo(),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                bundler_result.output_groups,
            )
        ),
    ] + bundler_result.providers

watchos_application = rule_factory.create_apple_rule(
    cfg = transition_support.apple_rule_transition,
    doc = "Builds and bundles a watchOS Application.",
    implementation = _watchos_application_impl,
    is_executable = True,
    predeclared_outputs = {"archive": "%{name}.zip"},
    attrs = [
        apple_support.platform_constraint_attrs(),
        rule_attrs.app_icon_attrs(),
        rule_attrs.binary_linking_attrs(
            deps_cfg = transition_support.apple_platform_split_transition,
            extra_deps_aspects = [
                swift_const_values_aspect,
                apple_resource_aspect,
                framework_provider_aspect,
            ],
            is_deps_mandatory = True,
            is_test_supporting_rule = False,
        ),
        rule_attrs.common_bundle_attrs(),
        rule_attrs.common_tool_attrs(),
        rule_attrs.device_family_attrs(
            allowed_families = rule_attrs.defaults.allowed_families.watchos,
        ),
        rule_attrs.infoplist_attrs(),
        rule_attrs.ipa_post_processor_attrs(),
        rule_attrs.platform_attrs(
            add_environment_plist = True,
            platform_type = "watchos",
        ),
        rule_attrs.signing_attrs(
            default_bundle_id_suffix = bundle_id_suffix_default.watchos_app,
        ),
        rule_attrs.simulator_runner_template_attr(),
        {
            "extensions": attr.label_list(
                providers = [[AppleBundleInfo, WatchosExtensionBundleInfo]],
                doc = """
A list of watchOS application extensions to include in the final application bundle.
""",
            ),
            "frameworks": attr.label_list(
                aspects = [framework_provider_aspect],
                providers = [[AppleBundleInfo, WatchosFrameworkBundleInfo]],
                doc = """
A list of framework targets (see
[`watchos_framework`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-watchos.md#watchos_framework))
that this target depends on.
""",
            ),
            "storyboards": attr.label_list(
                allow_files = [".storyboard"],
                doc = """
A list of `.storyboard` files, often localizable. These files are compiled and placed in the root of
the final application bundle, unless a file's immediate containing directory is named `*.lproj`, in
which case it will be placed under a directory with the same name in the bundle.
""",
            ),
        },
    ],
)

watchos_extension = rule_factory.create_apple_rule(
    cfg = transition_support.apple_rule_transition,
    doc = "Builds and bundles a watchOS Extension.",
    implementation = _watchos_extension_impl,
    predeclared_outputs = {"archive": "%{name}.zip"},
    attrs = [
        apple_support.platform_constraint_attrs(),
        rule_attrs.binary_linking_attrs(
            deps_cfg = transition_support.apple_platform_split_transition,
            extra_deps_aspects = [
                swift_const_values_aspect,
                apple_resource_aspect,
                framework_provider_aspect,
            ],
            is_test_supporting_rule = False,
        ),
        rule_attrs.common_bundle_attrs(),
        rule_attrs.common_tool_attrs(),
        rule_attrs.device_family_attrs(
            allowed_families = rule_attrs.defaults.allowed_families.watchos,
        ),
        rule_attrs.extensionkit_attrs(),
        rule_attrs.infoplist_attrs(),
        rule_attrs.ipa_post_processor_attrs(),
        rule_attrs.platform_attrs(
            add_environment_plist = True,
            platform_type = "watchos",
        ),
        rule_attrs.signing_attrs(
            default_bundle_id_suffix = bundle_id_suffix_default.bundle_name,
        ),
        {
            "frameworks": attr.label_list(
                providers = [[AppleBundleInfo, WatchosFrameworkBundleInfo]],
                doc = """
A list of framework targets (see
[`watchos_framework`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-watchos.md#watchos_framework))
that this target depends on.
""",
            ),
        },
    ],
)

watchos_framework = rule_factory.create_apple_rule(
    cfg = transition_support.apple_rule_transition,
    doc = "Builds and bundles a watchOS Dynamic Framework.",
    implementation = _watchos_framework_impl,
    predeclared_outputs = {"archive": "%{name}.zip"},
    attrs = [
        apple_support.platform_constraint_attrs(),
        rule_attrs.binary_linking_attrs(
            deps_cfg = transition_support.apple_platform_split_transition,
            extra_deps_aspects = [
                swift_const_values_aspect,
                apple_resource_aspect,
                framework_provider_aspect,
            ],
            is_test_supporting_rule = False,
        ),
        rule_attrs.common_bundle_attrs(),
        rule_attrs.common_tool_attrs(),
        rule_attrs.device_family_attrs(
            allowed_families = rule_attrs.defaults.allowed_families.watchos,
        ),
        rule_attrs.infoplist_attrs(),
        rule_attrs.platform_attrs(
            add_environment_plist = True,
            platform_type = "watchos",
        ),
        rule_attrs.signing_attrs(
            default_bundle_id_suffix = bundle_id_suffix_default.bundle_name,
            supports_capabilities = False,
        ),
        {
            "extension_safe": attr.bool(
                default = False,
                doc = """
If true, compiles and links this framework with `-application-extension`, restricting the binary to
use only extension-safe APIs.
""",
            ),
            "frameworks": attr.label_list(
                providers = [[AppleBundleInfo, WatchosFrameworkBundleInfo]],
                doc = """
A list of framework targets (see
[`watchos_framework`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-watchos.md#watchos_framework))
that this target depends on.
""",
            ),
        },
    ],
)
