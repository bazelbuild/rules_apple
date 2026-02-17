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

"""Implementation of iOS rules."""

load("@bazel_skylib//lib:collections.bzl", "collections")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
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
    "@build_bazel_rules_apple//apple/internal:cc_info_support.bzl",
    "cc_info_support",
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
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "AppleBundleInfo",
    "ApplePlatformInfo",
    "IosAppClipBundleInfo",
    "IosExtensionBundleInfo",
    "IosFrameworkBundleInfo",
    "WatchosApplicationBundleInfo",
    "new_appleexecutablebinaryinfo",
    "new_appleframeworkbundleinfo",
    "new_iosappclipbundleinfo",
    "new_iosapplicationbundleinfo",
    "new_iosextensionbundleinfo",
    "new_iosframeworkbundleinfo",
    "new_iosimessageextensionbundleinfo",
    "new_iosstaticframeworkbundleinfo",
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
    "@build_bazel_rules_apple//apple/internal:secure_features_support.bzl",
    "secure_features_support",
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
    "@build_bazel_rules_apple//apple/internal/aspects:app_intents_aspect.bzl",
    "app_intents_aspect",
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
    "@build_bazel_rules_apple//apple/internal/aspects:swift_generated_header_aspect.bzl",
    "swift_generated_header_aspect",
)
load(
    "@build_bazel_rules_apple//apple/internal/providers:swift_generated_header_info.bzl",
    "SwiftGeneratedHeaderInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/toolchains:apple_toolchains.bzl",
    "apple_toolchain_utils",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:clang_rt_dylibs.bzl",
    "clang_rt_dylibs",
)
load("@build_bazel_rules_swift//swift:providers.bzl", "SwiftInfo")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

def _ios_application_impl(ctx):
    """Implementation of ios_application."""
    rule_descriptor = rule_support.rule_descriptor(
        platform_type = ctx.attr.platform_type,
        product_type = apple_product_type.application,
    )

    actions = ctx.actions
    apple_mac_toolchain_info = apple_toolchain_utils.get_mac_toolchain(ctx)
    mac_exec_group = apple_toolchain_utils.get_mac_exec_group(ctx)
    apple_xplat_toolchain_info = apple_toolchain_utils.get_xplat_toolchain(ctx)
    xplat_exec_group = apple_toolchain_utils.get_xplat_exec_group(ctx)

    extra_requested_features = []
    if ctx.attr.testonly:
        extra_requested_features.append("exported_symbols")

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
        extra_requested_features = extra_requested_features,
    )
    cc_toolchain_forwarder = ctx.split_attr._cc_toolchain_forwarder
    embeddable_targets = ctx.attr.frameworks + ctx.attr.extensions + ctx.attr.app_clips
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites(
        apple_fragment = ctx.fragments.apple,
        apple_platform_info = platform_support.apple_platform_info_from_rule_ctx(ctx),
        build_settings = apple_xplat_toolchain_info.build_settings,
        config_vars = ctx.var,
        cpp_fragment = ctx.fragments.cpp,
        device_families = ctx.attr.families,
        explicit_minimum_os = ctx.attr.minimum_os_version,
        objc_fragment = ctx.fragments.objc,
        uses_swift = swift_support.uses_swift(ctx.attr.deps),
        xcode_version_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
    )
    predeclared_outputs = ctx.outputs
    provisioning_profile = ctx.file.provisioning_profile
    resource_deps = ctx.attr.deps + ctx.attr.resources
    top_level_infoplists = resources.collect(
        attr = ctx.attr,
        res_attrs = ["infoplists"],
        rule_label = label,
    )

    top_level_resources = resources.collect(
        attr = ctx.attr,
        res_attrs = [
            "app_icons",
            "launch_storyboard",
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

    extra_linkopts = []

    if ctx.attr.sdk_frameworks:
        extra_linkopts.extend(
            collections.before_each("-framework", ctx.attr.sdk_frameworks),
        )

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
    linking_contexts = [output.linking_context for output in link_result.outputs]

    default_launch_screen = True
    if ctx.attr.default_launch_screen == False and ctx.attr.testonly:
        # If we're at the current default of "False", set it to "True" unless we're an app declared
        # as `testonly`. This change does require manual migration of iOS UI tests due to the change
        # shifting default rendering from scaled to native when a launch_storyboard isn't set.
        default_launch_screen = False

    launch_screen_values = infoplist_support.launch_screen_values(
        default_launch_screen = default_launch_screen,
        launch_storyboard = ctx.file.launch_storyboard,
        platform_prerequisites = platform_prerequisites,
    )

    if ctx.attr.watch_application:
        watch_app = ctx.attr.watch_application

        embeddable_targets.append(watch_app)

        bundle_verification_targets.append(
            struct(
                target = watch_app,
                parent_bundle_id_reference = ["WKCompanionAppBundleIdentifier"],
            ),
        )

    processor_partials = [
        partials.app_assets_validation_partial(
            app_icons = ctx.files.app_icons,
            platform_prerequisites = platform_prerequisites,
            product_type = rule_descriptor.product_type,
        ),
        partials.app_intents_metadata_bundle_partial(
            actions = actions,
            app_intents = [ctx.split_attr.deps],
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            bundle_id = bundle_id,
            cc_toolchains = cc_toolchain_forwarder,
            embedded_bundles = embeddable_targets,
            frameworks = ctx.attr.frameworks,
            label = label,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.apple_bundle_info_partial(
            actions = actions,
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
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            label_name = label.name,
        ),
        partials.codesigning_dossier_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            bundle_extension = bundle_extension,
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
        partials.child_bundle_info_validation_partial(
            frameworks = ctx.attr.frameworks,
            platform_prerequisites = platform_prerequisites,
            product_type = rule_descriptor.product_type,
            resource_validation_infos = ctx.attr.deps,
            rule_label = label,
        ),
        partials.clang_rt_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            cc_configured_features = cc_configured_features,
            dylibs = clang_rt_dylibs.get_from_toolchain(ctx),
            label_name = label.name,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.debug_symbols_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = embeddable_targets + resource_deps,
            dsym_outputs = debug_outputs.dsym_outputs,
            linkmaps = debug_outputs.linkmaps,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.embedded_bundles_partial(
            bundle_embedded_bundles = True,
            embeddable_targets = embeddable_targets,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.framework_import_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            cc_configured_features = cc_configured_features,
            label_name = label.name,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            provisioning_profile = provisioning_profile,
            rule_descriptor = rule_descriptor,
            targets = ctx.attr.deps + ctx.attr.extensions + ctx.attr.frameworks,
        ),
        partials.resources_partial(
            actions = actions,
            additional_forced_root_infoplist_values = launch_screen_values.forced_plists,
            additional_overridable_root_infoplist_values = launch_screen_values.overridable_plists,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            bundle_verification_targets = bundle_verification_targets,
            environment_plist = ctx.file._environment_plist,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            primary_icon_name = ctx.attr.primary_app_icon,
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
        partials.settings_bundle_partial(
            actions = actions,
            platform_prerequisites = platform_prerequisites,
            rule_label = label,
            settings_bundle = ctx.attr.settings_bundle,
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            bundle_dylibs = True,
            dependency_targets = embeddable_targets,
            label_name = label.name,
            mac_exec_group = mac_exec_group,
            package_swift_support_if_needed = True,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.apple_symbols_file_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            dependency_targets = embeddable_targets,
            dsym_outputs = debug_outputs.dsym_outputs,
            label_name = label.name,
            include_symbols_in_bundle = ctx.attr.include_symbols_in_bundle,
            platform_prerequisites = platform_prerequisites,
        ),
    ]

    if ctx.attr.watch_application:
        # Add the stub binary if the associated watchOS application is a watchOS 2 application.
        watch_bundle_info = ctx.attr.watch_application[AppleBundleInfo]
        if watch_bundle_info.product_type == apple_product_type.watch2_application:
            processor_partials.append(
                partials.watchos_stub_partial(
                    actions = actions,
                    label_name = label.name,
                    watch_application = ctx.attr.watch_application,
                ),
            )

    processor_partials.append(
        # We need to add this partial everytime in case any of the extensions uses a stub binary and
        # the stub needs to be packaged in the support directories.
        partials.messages_stub_partial(
            actions = actions,
            extensions = ctx.attr.extensions,
            label_name = label.name,
            package_messages_support = True,
        ),
    )

    if platform_prerequisites.platform.is_device:
        processor_partials.append(
            partials.provisioning_profile_partial(
                actions = actions,
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
        entitlements = entitlements,
        cc_configured_features = cc_configured_features,
        ipa_post_processor = ctx.executable.ipa_post_processor,
        mac_exec_group = mac_exec_group,
        partials = processor_partials,
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

    # TODO(b/254511920): Consider creating a custom build config for iOS simulator device/version.
    run_support.register_simulator_executable(
        actions = actions,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        output = executable,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        runner_template = ctx.file._runner_template,
        simulator_device = ctx.fragments.objc.ios_simulator_device,
        simulator_version = ctx.fragments.objc.ios_simulator_version,
    )

    archive = outputs.archive(
        actions = actions,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
    )

    dsyms = outputs.dsyms(
        processor_result = processor_result,
    )

    return [
        # TODO(b/121155041): Should we do the same for ios_framework and ios_extension?
        coverage_common.instrumented_files_info(ctx, dependency_attributes = ["deps"]),
        DefaultInfo(
            executable = executable,
            files = processor_result.output_files,
            runfiles = ctx.runfiles(
                files = [archive],
                transitive_files = dsyms,
            ),
        ),
        new_iosapplicationbundleinfo(),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
            )
        ),
        new_appleexecutablebinaryinfo(
            binary = binary_artifact,
            binary_linking_context = cc_common.merge_linking_contexts(
                linking_contexts = linking_contexts,
            ),
        ),
    ] + processor_result.providers

def _ios_app_clip_impl(ctx):
    """Implementation of ios_app_clip."""
    rule_descriptor = rule_support.rule_descriptor(
        platform_type = ctx.attr.platform_type,
        product_type = apple_product_type.app_clip,
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
    embeddable_targets = ctx.attr.frameworks
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites(
        apple_fragment = ctx.fragments.apple,
        apple_platform_info = platform_support.apple_platform_info_from_rule_ctx(ctx),
        build_settings = apple_xplat_toolchain_info.build_settings,
        config_vars = ctx.var,
        cpp_fragment = ctx.fragments.cpp,
        device_families = ctx.attr.families,
        explicit_minimum_os = ctx.attr.minimum_os_version,
        objc_fragment = ctx.fragments.objc,
        uses_swift = swift_support.uses_swift(ctx.attr.deps),
        xcode_version_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
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
            "launch_storyboard",
            "strings",
            "resources",
        ],
        rule_label = ctx.label,
    )

    entitlements = entitlements_support.process_entitlements(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        mac_exec_group = mac_exec_group,
        bundle_id = bundle_id,
        cc_configured_features = cc_configured_features,
        cc_toolchains = cc_toolchain_forwarder,
        entitlements_file = ctx.file.entitlements,
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
        platform_prerequisites = platform_prerequisites,
        rule_descriptor = rule_descriptor,
        stamp = ctx.attr.stamp,
    )
    binary_artifact = link_result.binary
    debug_outputs = linking_support.debug_outputs_by_architecture(link_result.outputs)
    linking_contexts = [output.linking_context for output in link_result.outputs]

    launch_screen_values = infoplist_support.launch_screen_values(
        default_launch_screen = True,
        launch_storyboard = ctx.file.launch_storyboard,
        platform_prerequisites = platform_prerequisites,
    )

    archive_for_embedding = outputs.archive_for_embedding(
        actions = actions,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        label_name = label.name,
        rule_descriptor = rule_descriptor,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
    )

    processor_partials = [
        partials.app_assets_validation_partial(
            app_icons = ctx.files.app_icons,
            platform_prerequisites = platform_prerequisites,
            product_type = rule_descriptor.product_type,
        ),
        partials.apple_bundle_info_partial(
            actions = actions,
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
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            label_name = label.name,
        ),
        partials.child_bundle_info_validation_partial(
            frameworks = ctx.attr.frameworks,
            platform_prerequisites = platform_prerequisites,
            product_type = rule_descriptor.product_type,
            resource_validation_infos = ctx.attr.deps,
            rule_label = label,
        ),
        partials.codesigning_dossier_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_location = processor.location.app_clip,
            bundle_name = bundle_name,
            embedded_targets = embeddable_targets,
            entitlements = entitlements,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            provisioning_profile = getattr(ctx.file, "provisioning_profile", None),
            rule_descriptor = rule_descriptor,
            rule_label = label,
            xplat_exec_group = xplat_exec_group,
        ),
        partials.clang_rt_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            cc_configured_features = cc_configured_features,
            dylibs = clang_rt_dylibs.get_from_toolchain(ctx),
            mac_exec_group = mac_exec_group,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.debug_symbols_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = embeddable_targets + resource_deps,
            dsym_outputs = debug_outputs.dsym_outputs,
            linkmaps = debug_outputs.linkmaps,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.embedded_bundles_partial(
            app_clips = [archive_for_embedding],
            bundle_embedded_bundles = True,
            embeddable_targets = embeddable_targets,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.framework_import_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            cc_configured_features = cc_configured_features,
            label_name = label.name,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            provisioning_profile = getattr(ctx.file, "provisioning_profile", None),
            rule_descriptor = rule_descriptor,
            targets = ctx.attr.deps + ctx.attr.frameworks,
        ),
        partials.resources_partial(
            actions = actions,
            additional_forced_root_infoplist_values = launch_screen_values.forced_plists,
            additional_overridable_root_infoplist_values = launch_screen_values.overridable_plists,
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
            xplat_exec_group = xplat_exec_group,
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            bundle_dylibs = True,
            dependency_targets = embeddable_targets,
            label_name = label.name,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
        ),
    ]

    if platform_prerequisites.platform.is_device:
        processor_partials.append(
            partials.provisioning_profile_partial(
                actions = actions,
                profile_artifact = ctx.file.provisioning_profile,
                rule_label = label,
            ),
        )

    processor_result = processor.process(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        cc_configured_features = cc_configured_features,
        entitlements = entitlements,
        mac_exec_group = mac_exec_group,
        partials = processor_partials,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_mac_toolchain_info.process_and_sign_template,
        provisioning_profile = getattr(ctx.file, "provisioning_profile", None),
        rule_descriptor = rule_descriptor,
        rule_label = label,
        xplat_exec_group = xplat_exec_group,
    )

    executable = outputs.executable(
        actions = actions,
        label_name = label.name,
    )

    # TODO(b/254511920): Consider creating a custom build config for iOS simulator device/version.
    run_support.register_simulator_executable(
        actions = actions,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        output = executable,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        runner_template = ctx.file._runner_template,
        simulator_device = ctx.fragments.objc.ios_simulator_device,
        simulator_version = ctx.fragments.objc.ios_simulator_version,
    )

    archive = outputs.archive(
        actions = actions,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
    )

    return [
        # TODO(b/121155041): Should we do the same for ios_framework?
        coverage_common.instrumented_files_info(ctx, dependency_attributes = ["deps"]),
        DefaultInfo(
            executable = executable,
            files = processor_result.output_files,
            runfiles = ctx.runfiles(
                files = [archive],
            ),
        ),
        new_iosappclipbundleinfo(),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
            )
        ),
        new_appleexecutablebinaryinfo(
            binary = binary_artifact,
            binary_linking_context = cc_common.merge_linking_contexts(
                linking_contexts = linking_contexts,
            ),
        ),
    ] + processor_result.providers

def _ios_framework_impl(ctx):
    """Implementation of ios_framework."""
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
        apple_fragment = ctx.fragments.apple,
        apple_platform_info = platform_support.apple_platform_info_from_rule_ctx(ctx),
        build_settings = apple_xplat_toolchain_info.build_settings,
        config_vars = ctx.var,
        cpp_fragment = ctx.fragments.cpp,
        device_families = ctx.attr.families,
        explicit_minimum_os = ctx.attr.minimum_os_version,
        objc_fragment = ctx.fragments.objc,
        uses_swift = swift_support.uses_swift(ctx.attr.deps),
        xcode_version_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
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
        # Frameworks do not have entitlements.
        entitlements = None,
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
        bundle_name = bundle_name,
        bundle_extension = bundle_extension,
        label_name = label.name,
        rule_descriptor = rule_descriptor,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
    )

    processor_partials = [
        partials.app_intents_metadata_bundle_partial(
            actions = actions,
            app_intents = [ctx.split_attr.deps],
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            bundle_id = bundle_id,
            cc_toolchains = cc_toolchain_forwarder,
            embedded_bundles = ctx.attr.frameworks,
            frameworks = ctx.attr.frameworks,
            label = label,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.apple_bundle_info_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            cc_toolchains = cc_toolchain_forwarder,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            product_type = rule_descriptor.product_type,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            label_name = label.name,
        ),
        partials.child_bundle_info_validation_partial(
            frameworks = ctx.attr.frameworks,
            platform_prerequisites = platform_prerequisites,
            product_type = rule_descriptor.product_type,
            resource_validation_infos = ctx.attr.deps,
            rule_label = label,
        ),
        partials.debug_symbols_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = ctx.attr.frameworks + resource_deps,
            dsym_outputs = debug_outputs.dsym_outputs,
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
            binary_artifact = binary_artifact,
            cc_configured_features = cc_configured_features,
            cc_linking_contexts = linking_contexts,
            cc_toolchain = find_cpp_toolchain(ctx),
            rule_label = label,
        ),
        partials.resources_partial(
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
        partials.swift_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            dependency_targets = ctx.attr.frameworks,
            label_name = label.name,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.apple_symbols_file_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            dependency_targets = ctx.attr.frameworks,
            dsym_outputs = debug_outputs.dsym_outputs,
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
        cc_configured_features = cc_configured_features,
        ipa_post_processor = ctx.executable.ipa_post_processor,
        mac_exec_group = mac_exec_group,
        partials = processor_partials,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_mac_toolchain_info.process_and_sign_template,
        provisioning_profile = provisioning_profile,
        rule_descriptor = rule_descriptor,
        rule_label = label,
        xplat_exec_group = xplat_exec_group,
    )

    return [
        DefaultInfo(files = processor_result.output_files),
        new_appleframeworkbundleinfo(),
        new_iosframeworkbundleinfo(),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
            )
        ),
    ] + processor_result.providers

def _ios_extension_impl(ctx):
    """Implementation of ios_extension."""

    product_type = apple_product_type.app_extension
    if ctx.attr.extensionkit_extension:
        product_type = apple_product_type.extensionkit_extension

    rule_descriptor = rule_support.rule_descriptor(
        platform_type = ctx.attr.platform_type,
        product_type = product_type,
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
        apple_fragment = ctx.fragments.apple,
        apple_platform_info = platform_support.apple_platform_info_from_rule_ctx(ctx),
        build_settings = apple_xplat_toolchain_info.build_settings,
        config_vars = ctx.var,
        cpp_fragment = ctx.fragments.cpp,
        device_families = ctx.attr.families,
        explicit_minimum_os = ctx.attr.minimum_os_version,
        objc_fragment = ctx.fragments.objc,
        uses_swift = swift_support.uses_swift(ctx.attr.deps),
        xcode_version_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
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
    if ctx.attr.sdk_frameworks:
        extra_linkopts.extend(
            collections.before_each("-framework", ctx.attr.sdk_frameworks),
        )

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

    archive_for_embedding = outputs.archive_for_embedding(
        actions = actions,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        label_name = label.name,
        rule_descriptor = rule_descriptor,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
    )

    bundle_location = ""
    embedded_bundles_args = {}
    if rule_descriptor.product_type == apple_product_type.app_extension:
        bundle_location = processor.location.plugin
        embedded_bundles_args["plugins"] = [archive_for_embedding]
    elif rule_descriptor.product_type == apple_product_type.extensionkit_extension:
        bundle_location = processor.location.extension
        embedded_bundles_args["extensions"] = [archive_for_embedding]
    else:
        fail("Internal Error: Unexpectedly found product_type " + rule_descriptor.product_type)

    processor_partials = [
        partials.app_assets_validation_partial(
            app_icons = ctx.files.app_icons,
            platform_prerequisites = platform_prerequisites,
            product_type = rule_descriptor.product_type,
        ),
        partials.app_intents_metadata_bundle_partial(
            actions = actions,
            app_intents = [ctx.split_attr.deps],
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            bundle_id = bundle_id,
            cc_toolchains = cc_toolchain_forwarder,
            embedded_bundles = ctx.attr.frameworks,
            frameworks = ctx.attr.frameworks,
            label = label,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.apple_bundle_info_partial(
            actions = actions,
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
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            label_name = label.name,
        ),
        partials.child_bundle_info_validation_partial(
            frameworks = ctx.attr.frameworks,
            platform_prerequisites = platform_prerequisites,
            product_type = rule_descriptor.product_type,
            resource_validation_infos = ctx.attr.deps,
            rule_label = label,
        ),
        partials.codesigning_dossier_partial(
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
        partials.clang_rt_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            cc_configured_features = cc_configured_features,
            dylibs = clang_rt_dylibs.get_from_toolchain(ctx),
            label_name = label.name,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.debug_symbols_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = ctx.attr.frameworks + resource_deps,
            dsym_outputs = debug_outputs.dsym_outputs,
            linkmaps = debug_outputs.linkmaps,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.embedded_bundles_partial(
            embeddable_targets = ctx.attr.frameworks,
            platform_prerequisites = platform_prerequisites,
            **embedded_bundles_args
        ),
        partials.extension_safe_validation_partial(
            is_extension_safe = True,
            rule_label = label,
            targets_to_validate = ctx.attr.frameworks,
        ),
        partials.resources_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            environment_plist = ctx.file._environment_plist,
            extensionkit_keys_required = ctx.attr.extensionkit_extension,
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
        partials.swift_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            dependency_targets = ctx.attr.frameworks,
            label_name = label.name,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.apple_symbols_file_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            dependency_targets = ctx.attr.frameworks,
            dsym_outputs = debug_outputs.dsym_outputs,
            label_name = label.name,
            include_symbols_in_bundle = False,
            platform_prerequisites = platform_prerequisites,
        ),
    ]

    if platform_prerequisites.platform.is_device:
        processor_partials.append(
            partials.provisioning_profile_partial(
                actions = actions,
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
        cc_configured_features = cc_configured_features,
        entitlements = entitlements,
        ipa_post_processor = ctx.executable.ipa_post_processor,
        mac_exec_group = mac_exec_group,
        partials = processor_partials,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_mac_toolchain_info.process_and_sign_template,
        provisioning_profile = provisioning_profile,
        rule_descriptor = rule_descriptor,
        rule_label = label,
        xplat_exec_group = xplat_exec_group,
    )

    return [
        DefaultInfo(
            files = processor_result.output_files,
        ),
        new_iosextensionbundleinfo(),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
            )
        ),
    ] + processor_result.providers

def _ios_static_framework_impl(ctx):
    """Implementation of ios_static_framework."""
    rule_descriptor = rule_support.rule_descriptor(
        platform_type = ctx.attr.platform_type,
        product_type = apple_product_type.static_framework,
    )

    actions = ctx.actions
    apple_mac_toolchain_info = apple_toolchain_utils.get_mac_toolchain(ctx)
    mac_exec_group = apple_toolchain_utils.get_mac_exec_group(ctx)
    apple_xplat_toolchain_info = apple_toolchain_utils.get_xplat_toolchain(ctx)
    xplat_exec_group = apple_toolchain_utils.get_xplat_exec_group(ctx)
    avoid_deps = ctx.attr.avoid_deps
    cc_configured_features = features_support.cc_configured_features(
        ctx = ctx,
    )
    cc_toolchain_forwarder = ctx.split_attr._cc_toolchain_forwarder
    deps = ctx.attr.deps
    label = ctx.label
    predeclared_outputs = ctx.outputs
    split_deps = ctx.split_attr.deps
    bundle_name, bundle_extension = bundling_support.bundle_full_name(
        custom_bundle_name = ctx.attr.bundle_name,
        label_name = ctx.label.name,
        rule_descriptor = rule_descriptor,
    )
    platform_prerequisites = platform_support.platform_prerequisites(
        apple_fragment = ctx.fragments.apple,
        apple_platform_info = platform_support.apple_platform_info_from_rule_ctx(ctx),
        build_settings = apple_xplat_toolchain_info.build_settings,
        config_vars = ctx.var,
        cpp_fragment = ctx.fragments.cpp,
        device_families = ctx.attr.families,
        explicit_minimum_os = ctx.attr.minimum_os_version,
        objc_fragment = ctx.fragments.objc,
        uses_swift = swift_support.uses_swift(ctx.attr.deps),
        xcode_version_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
    )
    resource_deps = ctx.attr.deps + ctx.attr.resources
    secure_features = ctx.attr.secure_features

    # Check that the requested secure features are supported and enabled for the toolchain.
    secure_features_support.validate_secure_features_support(
        cc_configured_features = cc_configured_features,
        cc_toolchain_forwarder = cc_toolchain_forwarder,
        rule_label = label,
        secure_features = secure_features,
    )

    archive_result = linking_support.register_static_library_archive_action(
        ctx = ctx,
        cc_configured_features = cc_configured_features,
        cc_toolchains = cc_toolchain_forwarder,
    )
    binary_artifact = archive_result.library

    processor_partials = [
        partials.apple_bundle_info_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            cc_toolchains = cc_toolchain_forwarder,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            product_type = rule_descriptor.product_type,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            label_name = label.name,
        ),
    ]

    swift_generated_headers = {}
    swift_infos = {}
    if swift_support.uses_swift(deps):
        for split_attr_key, cc_toolchain in cc_toolchain_forwarder.items():
            apple_platform_info = cc_toolchain[ApplePlatformInfo]
            for dep in split_deps[split_attr_key]:
                if SwiftInfo in dep:
                    swift_infos[apple_platform_info.target_arch] = dep[SwiftInfo]
                if SwiftGeneratedHeaderInfo in dep:
                    header = dep[SwiftGeneratedHeaderInfo]
                    swift_generated_headers[apple_platform_info.target_arch] = header

    # If there's any Swift dependencies on the static framework rule, treat it as a Swift static
    # framework.
    if swift_infos:
        processor_partials.append(
            partials.swift_framework_partial(
                actions = actions,
                avoid_deps = avoid_deps,
                bundle_name = bundle_name,
                generated_headers = swift_generated_headers,
                is_legacy_static_framework = True,
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
                is_legacy_static_framework = True,
                label_name = label.name,
                sdk_dylibs = cc_info_support.get_sdk_dylibs(deps = deps),
                sdk_frameworks = cc_info_support.get_sdk_frameworks(deps = deps),
            ),
        )

    if not ctx.attr.exclude_resources:
        processor_partials.append(partials.resources_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            avoid_root_infoplist = True,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            environment_plist = ctx.file._environment_plist,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            resource_deps = resource_deps,
            resource_locales = ctx.attr.resource_locales,
            rule_descriptor = rule_descriptor,
            rule_label = label,
            version = ctx.attr.version,
            xplat_exec_group = xplat_exec_group,
        ))

    processor_result = processor.process(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        cc_configured_features = cc_configured_features,
        mac_exec_group = mac_exec_group,
        partials = processor_partials,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        process_and_sign_template = apple_mac_toolchain_info.process_and_sign_template,
        rule_descriptor = rule_descriptor,
        rule_label = label,
        xplat_exec_group = xplat_exec_group,
    )

    return [
        DefaultInfo(files = processor_result.output_files),
        new_iosstaticframeworkbundleinfo(),
        OutputGroupInfo(**processor_result.output_groups),
    ] + processor_result.providers

def _ios_imessage_extension_impl(ctx):
    """Implementation of ios_imessage_extension."""
    rule_descriptor = rule_support.rule_descriptor(
        platform_type = ctx.attr.platform_type,
        product_type = apple_product_type.messages_extension,
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
        apple_fragment = ctx.fragments.apple,
        apple_platform_info = platform_support.apple_platform_info_from_rule_ctx(ctx),
        build_settings = apple_xplat_toolchain_info.build_settings,
        config_vars = ctx.var,
        cpp_fragment = ctx.fragments.cpp,
        device_families = ctx.attr.families,
        explicit_minimum_os = ctx.attr.minimum_os_version,
        objc_fragment = ctx.fragments.objc,
        uses_swift = swift_support.uses_swift(ctx.attr.deps),
        xcode_version_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
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

    archive_for_embedding = outputs.archive_for_embedding(
        actions = actions,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        label_name = label.name,
        rule_descriptor = rule_descriptor,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
    )

    processor_partials = [
        partials.app_assets_validation_partial(
            app_icons = ctx.files.app_icons,
            platform_prerequisites = platform_prerequisites,
            product_type = rule_descriptor.product_type,
        ),
        partials.apple_bundle_info_partial(
            actions = actions,
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
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            label_name = label.name,
        ),
        partials.child_bundle_info_validation_partial(
            frameworks = ctx.attr.frameworks,
            platform_prerequisites = platform_prerequisites,
            product_type = rule_descriptor.product_type,
            resource_validation_infos = ctx.attr.deps,
            rule_label = label,
        ),
        partials.codesigning_dossier_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_location = processor.location.plugin,
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
        partials.clang_rt_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            cc_configured_features = cc_configured_features,
            dylibs = clang_rt_dylibs.get_from_toolchain(ctx),
            label_name = label.name,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.debug_symbols_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = ctx.attr.frameworks,
            dsym_outputs = debug_outputs.dsym_outputs,
            linkmaps = debug_outputs.linkmaps,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.embedded_bundles_partial(
            embeddable_targets = ctx.attr.frameworks,
            platform_prerequisites = platform_prerequisites,
            plugins = [archive_for_embedding],
        ),
        partials.extension_safe_validation_partial(
            is_extension_safe = True,
            rule_label = label,
            targets_to_validate = ctx.attr.frameworks,
        ),
        partials.resources_partial(
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
            xplat_exec_group = xplat_exec_group,
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            dependency_targets = ctx.attr.frameworks,
            label_name = label.name,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
        ),
    ]

    if platform_prerequisites.platform.is_device:
        processor_partials.append(
            partials.provisioning_profile_partial(
                actions = actions,
                profile_artifact = provisioning_profile,
                rule_label = label,
            ),
        )

    processor_result = processor.process(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        mac_exec_group = mac_exec_group,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        xplat_exec_group = xplat_exec_group,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        cc_configured_features = cc_configured_features,
        entitlements = entitlements,
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
        new_iosextensionbundleinfo(),
        new_iosimessageextensionbundleinfo(),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
            )
        ),
    ] + processor_result.providers

ios_application = rule_factory.create_apple_rule(
    cfg = transition_support.apple_rule_transition,
    doc = "Builds and bundles an iOS Application.",
    implementation = _ios_application_impl,
    is_executable = True,
    predeclared_outputs = {"archive": "%{name}.ipa"},
    attrs = [
        apple_support.platform_constraint_attrs(),
        rule_attrs.app_icon_attrs(
            icon_extension = ".appiconset",
            icon_parent_extension = ".xcassets",
            supports_alternate_icons = True,
        ),
        rule_attrs.binary_linking_attrs(
            deps_cfg = transition_support.apple_platform_split_transition,
            extra_deps_aspects = [
                app_intents_aspect,
                apple_resource_aspect,
                framework_provider_aspect,
            ],
            is_test_supporting_rule = False,
        ),
        rule_attrs.common_bundle_attrs(),
        rule_attrs.common_tool_attrs(),
        rule_attrs.device_family_attrs(
            allowed_families = rule_attrs.defaults.allowed_families.ios,
            is_mandatory = True,
        ),
        rule_attrs.infoplist_attrs(),
        rule_attrs.ipa_post_processor_attrs(),
        rule_attrs.platform_attrs(
            platform_type = "ios",
            add_environment_plist = True,
        ),
        rule_attrs.settings_bundle_attrs(),
        rule_attrs.signing_attrs(),
        rule_attrs.simulator_runner_template_attr(),
        {
            "app_clips": attr.label_list(
                providers = [[AppleBundleInfo, IosAppClipBundleInfo]],
                doc = """
A list of iOS app clips to include in the final application bundle.
""",
            ),
            "default_launch_screen": attr.bool(
                default = False,
                doc = """
If `True`, indicates if this target should declare an empty default launch screen if the
`launch_storyboard` is set to `None`, rendering the app clip at App Store native resolution rather
than scaled resolution. This attribute has no effect unless the app is declared as `testonly`, in
which case it is `False` by default to temporarily accommodate migrating test apps with UI.

This will always be `True` by default in a future iteration of the rules.
""",
            ),
            "extensions": attr.label_list(
                providers = [[AppleBundleInfo, IosExtensionBundleInfo]],
                doc = """
A list of iOS application extensions to include in the final application bundle.
""",
            ),
            "frameworks": attr.label_list(
                aspects = [framework_provider_aspect],
                providers = [[AppleBundleInfo, IosFrameworkBundleInfo]],
                doc = """
A list of framework targets (see
[`ios_framework`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-ios.md#ios_framework))
that this target depends on.
""",
            ),
            "include_symbols_in_bundle": attr.bool(
                default = False,
                doc = """
    If true and --output_groups=+dsyms is specified, generates `$UUID.symbols`
    files from all `{binary: .dSYM, ...}` pairs for the application and its
    dependencies, then packages them under the `Symbols/` directory in the
    final application bundle.
    """,
            ),
            "launch_storyboard": attr.label(
                allow_single_file = [".storyboard", ".xib"],
                doc = """
The `.storyboard` or `.xib` file that should be used as the launch screen for the application. The
provided file will be compiled into the appropriate format (`.storyboardc` or `.nib`) and placed in
the root of the final bundle. The generated file will also be registered in the bundle's
Info.plist under the key `UILaunchStoryboardName`.
""",
            ),
            # TODO(b/162600187): `sdk_frameworks` was never documented on `ios_application` but it
            # leaked through due to the old macro passing it to the underlying `apple_binary`.
            # Support this temporarily for a limited set of product types until we can migrate teams
            # off the attribute, once explicit build targets are used to propagate linking
            # information for system frameworks.
            "sdk_frameworks": attr.string_list(
                allow_empty = True,
                doc = """
Names of SDK frameworks to link with (e.g., `AddressBook`, `QuartzCore`).
`UIKit` and `Foundation` are always included, even if this attribute is
provided and does not list them.

This attribute is discouraged; in general, targets should list system
framework dependencies in the library targets where that framework is used,
not in the top-level bundle.
""",
            ),
            "watch_application": attr.label(
                providers = [[AppleBundleInfo, WatchosApplicationBundleInfo]],
                doc = """
A `watchos_application` target that represents an Apple Watch application or a
`watchos_single_target_application` target that represents a single-target Apple Watch application
that should be embedded in the application bundle.
""",
            ),
        },
    ],
)

ios_app_clip = rule_factory.create_apple_rule(
    cfg = transition_support.apple_rule_transition,
    doc = "Builds and bundles an iOS App Clip.",
    implementation = _ios_app_clip_impl,
    is_executable = True,
    predeclared_outputs = {"archive": "%{name}.ipa"},
    attrs = [
        apple_support.platform_constraint_attrs(),
        rule_attrs.app_icon_attrs(
            icon_extension = ".appiconset",
            icon_parent_extension = ".xcassets",
        ),
        rule_attrs.binary_linking_attrs(
            deps_cfg = transition_support.apple_platform_split_transition,
            extra_deps_aspects = [
                apple_resource_aspect,
                framework_provider_aspect,
            ],
            is_test_supporting_rule = False,
        ),
        rule_attrs.common_bundle_attrs(),
        rule_attrs.common_tool_attrs(),
        rule_attrs.device_family_attrs(
            allowed_families = rule_attrs.defaults.allowed_families.ios,
            is_mandatory = True,
        ),
        rule_attrs.infoplist_attrs(),
        rule_attrs.platform_attrs(
            platform_type = "ios",
            add_environment_plist = True,
        ),
        rule_attrs.signing_attrs(
            default_bundle_id_suffix = bundle_id_suffix_default.bundle_name,
        ),
        rule_attrs.simulator_runner_template_attr(),
        {
            "frameworks": attr.label_list(
                aspects = [framework_provider_aspect],
                providers = [[AppleBundleInfo, IosFrameworkBundleInfo]],
                doc = """
A list of framework targets (see
[`ios_framework`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-ios.md#ios_framework))
that this target depends on.
""",
            ),
            "launch_storyboard": attr.label(
                allow_single_file = [".storyboard", ".xib"],
                doc = """
The `.storyboard` or `.xib` file that should be used as the launch screen for the app clip. The
provided file will be compiled into the appropriate format (`.storyboardc` or `.nib`) and placed in
the root of the final bundle. The generated file will also be registered in the bundle's
Info.plist under the key `UILaunchStoryboardName`.
""",
            ),
        },
    ],
)

ios_extension = rule_factory.create_apple_rule(
    cfg = transition_support.apple_rule_transition,
    doc = "Builds and bundles an iOS Application Extension.",
    implementation = _ios_extension_impl,
    predeclared_outputs = {"archive": "%{name}.zip"},
    attrs = [
        apple_support.platform_constraint_attrs(),
        rule_attrs.app_icon_attrs(
            icon_extension = ".appiconset",
            icon_parent_extension = ".xcassets",
        ),
        rule_attrs.binary_linking_attrs(
            deps_cfg = transition_support.apple_platform_split_transition,
            extra_deps_aspects = [
                app_intents_aspect,
                apple_resource_aspect,
                framework_provider_aspect,
            ],
            is_test_supporting_rule = False,
        ),
        rule_attrs.common_bundle_attrs(),
        rule_attrs.common_tool_attrs(),
        rule_attrs.device_family_attrs(
            allowed_families = rule_attrs.defaults.allowed_families.ios,
            is_mandatory = True,
        ),
        rule_attrs.extensionkit_attrs(),
        rule_attrs.infoplist_attrs(),
        rule_attrs.ipa_post_processor_attrs(),
        rule_attrs.platform_attrs(
            platform_type = "ios",
            add_environment_plist = True,
        ),
        rule_attrs.signing_attrs(
            default_bundle_id_suffix = bundle_id_suffix_default.bundle_name,
        ),
        {
            "frameworks": attr.label_list(
                providers = [[AppleBundleInfo, IosFrameworkBundleInfo]],
                doc = """
A list of framework targets (see
[`ios_framework`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-ios.md#ios_framework))
that this target depends on.
""",
            ),
            # TODO(b/162600187): `sdk_frameworks` was never documented on `ios_application` but it
            # leaked through due to the old macro passing it to the underlying `apple_binary`.
            # Support this temporarily for a limited set of product types until we can migrate teams
            # off the attribute, once explicit build targets are used to propagate linking
            # information for system frameworks.
            "sdk_frameworks": attr.string_list(
                allow_empty = True,
                doc = """
Names of SDK frameworks to link with (e.g., `AddressBook`, `QuartzCore`).
`UIKit` and `Foundation` are always included, even if this attribute is
provided and does not list them.

This attribute is discouraged; in general, targets should list system
framework dependencies in the library targets where that framework is used,
not in the top-level bundle.
""",
            ),
        },
    ],
)

ios_framework = rule_factory.create_apple_rule(
    cfg = transition_support.apple_rule_transition,
    doc = "Builds and bundles an iOS Dynamic Framework.",
    implementation = _ios_framework_impl,
    predeclared_outputs = {"archive": "%{name}.zip"},
    attrs = [
        apple_support.platform_constraint_attrs(),
        rule_attrs.binary_linking_attrs(
            deps_cfg = transition_support.apple_platform_split_transition,
            extra_deps_aspects = [
                app_intents_aspect,
                apple_resource_aspect,
                framework_provider_aspect,
            ],
            is_test_supporting_rule = False,
        ),
        rule_attrs.common_bundle_attrs(),
        rule_attrs.common_tool_attrs(),
        rule_attrs.device_family_attrs(
            allowed_families = rule_attrs.defaults.allowed_families.ios,
            is_mandatory = True,
        ),
        rule_attrs.infoplist_attrs(),
        rule_attrs.ipa_post_processor_attrs(),
        rule_attrs.platform_attrs(
            platform_type = "ios",
            add_environment_plist = True,
        ),
        rule_attrs.signing_attrs(
            default_bundle_id_suffix = bundle_id_suffix_default.bundle_name,
            supports_capabilities = False,
        ),
        {
            "frameworks": attr.label_list(
                providers = [[AppleBundleInfo, IosFrameworkBundleInfo]],
                doc = """
A list of framework targets (see
[`ios_framework`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-ios.md#ios_framework))
that this target depends on.
""",
            ),
            "extension_safe": attr.bool(
                default = False,
                doc = """
If true, compiles and links this framework with `-application-extension`, restricting the binary to
use only extension-safe APIs.
""",
            ),
            # TODO(b/251214758): Remove this attribute when all usages of ios_frameworks with hdrs
            # are migrated to apple_xcframework.
            "hdrs": attr.label_list(
                allow_files = [".h"],
            ),
        },
    ],
)

ios_static_framework = rule_factory.create_apple_rule(
    cfg = transition_support.apple_rule_transition,
    doc = "Builds and bundles an iOS Static Framework.",
    implementation = _ios_static_framework_impl,
    predeclared_outputs = {"archive": "%{name}.zip"},
    attrs = [
        apple_support.platform_constraint_attrs(),
        rule_attrs.binary_linking_attrs(
            deps_cfg = transition_support.apple_platform_split_transition,
            extra_deps_aspects = [
                apple_resource_aspect,
                framework_provider_aspect,
                swift_generated_header_aspect,
            ],
            is_test_supporting_rule = False,
        ),
        rule_attrs.common_bundle_attrs(),
        rule_attrs.common_tool_attrs(),
        rule_attrs.device_family_attrs(
            allowed_families = rule_attrs.defaults.allowed_families.ios,
            is_mandatory = False,
        ),
        rule_attrs.platform_attrs(
            platform_type = "ios",
            add_environment_plist = True,
        ),
        {
            "_emitswiftinterface": attr.bool(
                default = True,
                doc = "Private attribute to generate Swift interfaces for static frameworks.",
            ),
            "avoid_deps": attr.label_list(
                cfg = transition_support.apple_platform_split_transition,
                doc = """
A list of library targets on which this framework depends in order to compile, but the transitive
closure of which will not be linked into the framework's binary.
""",
            ),
            "exclude_resources": attr.bool(
                default = False,
                doc = """
Indicates whether resources should be excluded from the bundle. This can be used to avoid
unnecessarily bundling resources if the static framework is being distributed in a different
fashion, such as a Cocoapod.
""",
            ),
            "hdrs": attr.label_list(
                allow_files = [".h"],
                doc = """
A list of `.h` files that will be publicly exposed by this framework. These headers should have
framework-relative imports, and if non-empty, an umbrella header named `%{bundle_name}.h` will also
be generated that imports all of the headers listed here.
""",
            ),
            "secure_features": attr.string_list(
                doc = """
A list of strings representing Apple Enhanced Security crosstool features that should be enabled for
this target.
""",
            ),
        },
    ],
)

ios_imessage_extension = rule_factory.create_apple_rule(
    cfg = transition_support.apple_rule_transition,
    doc = "Builds and bundles an iOS iMessage Extension.",
    implementation = _ios_imessage_extension_impl,
    predeclared_outputs = {"archive": "%{name}.zip"},
    attrs = [
        apple_support.platform_constraint_attrs(),
        rule_attrs.app_icon_attrs(
            icon_extension = ".appiconset",
            icon_parent_extension = ".xcassets",
        ),
        rule_attrs.binary_linking_attrs(
            deps_cfg = transition_support.apple_platform_split_transition,
            extra_deps_aspects = [
                apple_resource_aspect,
                framework_provider_aspect,
            ],
            is_test_supporting_rule = False,
        ),
        rule_attrs.common_bundle_attrs(),
        rule_attrs.common_tool_attrs(),
        rule_attrs.device_family_attrs(
            allowed_families = rule_attrs.defaults.allowed_families.ios,
            is_mandatory = True,
        ),
        rule_attrs.infoplist_attrs(),
        rule_attrs.ipa_post_processor_attrs(),
        rule_attrs.platform_attrs(
            platform_type = "ios",
            add_environment_plist = True,
        ),
        rule_attrs.signing_attrs(
            default_bundle_id_suffix = bundle_id_suffix_default.bundle_name,
        ),
        {
            "frameworks": attr.label_list(
                providers = [[AppleBundleInfo, IosFrameworkBundleInfo]],
                doc = """
A list of framework targets (see
[`ios_framework`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-ios.md#ios_framework))
that this target depends on.
""",
            ),
        },
    ],
)
