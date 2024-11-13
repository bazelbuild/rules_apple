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
    "@bazel_skylib//lib:sets.bzl",
    "sets",
)
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
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "AppleBundleInfo",
    "ApplePlatformInfo",
    "WatchosExtensionBundleInfo",
    "new_watchosapplicationbundleinfo",
    "new_watchosextensionbundleinfo",
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
    "@build_bazel_rules_apple//apple/internal:stub_support.bzl",
    "stub_support",
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
    "@build_bazel_rules_apple//apple/internal/toolchains:apple_toolchains.bzl",
    "apple_toolchain_utils",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:clang_rt_dylibs.bzl",
    "clang_rt_dylibs",
)

visibility([
    "//apple/...",
    "//test/...",
])

def _watchos_application_impl(ctx):
    """Implementation of watchos_application."""

    if ctx.attr.deps:
        return _watchos_single_target_application_impl(ctx)
    else:
        return _watchos_extension_based_application_impl(ctx)

def _watchos_extension_based_application_impl(ctx):
    """Implementation of watchos_application for watchOS 2 extension-based application bundles."""

    minimum_os = apple_common.dotted_version(ctx.attr.minimum_os_version)
    if minimum_os >= apple_common.dotted_version("9.0"):
        fail("""
Error: Building an app extension-based watchOS 2 application for watchOS 9.0 or later.

watchOS applications for watchOS 9.0 or later MUST be single-target watchOS applications, relying on
an app delegate via deps rather than a watchOS 2 extension.

Attempting to ship an extension-based watchOS 2 application to the App Store for watchOS 9.0 or
later will be met with a rejection.

Please remove the assigned watchOS 2 app `extension` and make sure a valid watchOS application
delegate is referenced in the single-target `watchos_application`'s `deps`.
""")

    rule_descriptor = rule_support.rule_descriptor(
        platform_type = ctx.attr.platform_type,
        product_type = apple_product_type.watch2_application,
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
    cc_toolchain_forwarder = ctx.split_attr._cc_toolchain_forwarder
    features = features_support.compute_enabled_features(
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites(
        apple_fragment = ctx.fragments.apple,
        apple_platform_info = platform_support.apple_platform_info_from_rule_ctx(ctx),
        build_settings = apple_xplat_toolchain_info.build_settings,
        config_vars = ctx.var,
        cpp_fragment = ctx.fragments.cpp,
        device_families = rule_descriptor.allowed_device_families,
        explicit_minimum_os = ctx.attr.minimum_os_version,
        objc_fragment = ctx.fragments.objc,
        uses_swift = False,  # No binary deps to check.
        xcode_version_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
    )
    predeclared_outputs = ctx.outputs
    provisioning_profile = ctx.file.provisioning_profile
    resource_deps = ctx.attr.resources
    top_level_infoplists = resources.collect(
        attr = ctx.attr,
        res_attrs = ["infoplists"],
    )
    top_level_resources = resources.collect(
        attr = ctx.attr,
        res_attrs = [
            "app_icons",
            "storyboards",
            "strings",
            "resources",
        ],
    )

    entitlements = entitlements_support.process_entitlements(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        bundle_id = bundle_id,
        entitlements_file = ctx.file.entitlements,
        mac_exec_group = mac_exec_group,
        platform_prerequisites = platform_prerequisites,
        product_type = rule_descriptor.product_type,
        provisioning_profile = provisioning_profile,
        rule_label = label,
        validation_mode = ctx.attr.entitlements_validation,
    )

    # Collect all architectures found from the cc_toolchain forwarder.
    requested_archs = sets.make()
    for cc_toolchain in cc_toolchain_forwarder.values():
        requested_archs = sets.insert(requested_archs, cc_toolchain[ApplePlatformInfo].target_arch)

    if sets.length(requested_archs) == 0:
        fail("Internal Error: No architectures found for {label_name}. Please file an issue with a \
reproducible error case.".format(
            label_name = label.name,
        ))

    binary_artifact = stub_support.create_stub_binary(
        actions = actions,
        archs_for_lipo = sets.to_list(requested_archs),
        platform_prerequisites = platform_prerequisites,
        rule_label = label,
        xcode_stub_path = rule_descriptor.stub_binary_path,
    )

    bundle_verification_targets = [
        struct(
            target = ctx.attr.extension,
            parent_bundle_id_reference = [
                "NSExtension",
                "NSExtensionAttributes",
                "WKAppBundleIdentifier",
            ],
        ),
    ]

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
            bundle_id = bundle_id,
            entitlements = entitlements,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            product_type = rule_descriptor.product_type,
        ),
        partials.app_intents_metadata_bundle_partial(
            actions = actions,
            app_intents = [ctx.split_attr.deps],
            bundle_id = bundle_id,
            cc_toolchains = cc_toolchain_forwarder,
            embedded_bundles = [ctx.attr.extension],
            label = label,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
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
            mac_exec_group = mac_exec_group,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            xplat_exec_group = xplat_exec_group,
            bundle_extension = bundle_extension,
            bundle_location = processor.location.watch,
            bundle_name = bundle_name,
            embed_target_dossiers = True,
            embedded_targets = [ctx.attr.extension],
            entitlements = entitlements,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            provisioning_profile = provisioning_profile,
            rule_descriptor = rule_descriptor,
        ),
        partials.debug_symbols_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = [ctx.attr.extension],
            dsym_info_plist_template = apple_mac_toolchain_info.dsym_info_plist_template,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            plisttool = apple_mac_toolchain_info.plisttool,
            rule_label = label,
            version = ctx.attr.version,
        ),
        partials.embedded_bundles_partial(
            bundle_embedded_bundles = True,
            embeddable_targets = [ctx.attr.extension],
            platform_prerequisites = platform_prerequisites,
            watch_bundles = [archive],
        ),
        partials.resources_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
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
            top_level_infoplists = top_level_infoplists,
            top_level_resources = top_level_resources,
            version = ctx.attr.version,
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            bundle_dylibs = True,
            dependency_targets = [ctx.attr.extension],
            label_name = label.name,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.watchos_stub_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            label_name = label.name,
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
        xplat_exec_group = xplat_exec_group,
        mac_exec_group = mac_exec_group,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        entitlements = entitlements,
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
        OutputGroupInfo(**processor_result.output_groups),
        new_watchosapplicationbundleinfo(),
    ] + processor_result.providers

def _watchos_extension_impl(ctx):
    """Implementation of watchos_extension."""

    # TODO(b/155313625): Set the product type as apple_product_type.extension if the attrs set on
    # the rule match a criteria appropriate for watchOS extensions (i.e. SiriKit, Notification
    # Center, WidgetKit).
    rule_descriptor = rule_support.rule_descriptor(
        platform_type = ctx.attr.platform_type,
        product_type = apple_product_type.watch2_extension,
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
    cc_toolchain_forwarder = ctx.split_attr._cc_toolchain_forwarder
    features = features_support.compute_enabled_features(
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites(
        apple_fragment = ctx.fragments.apple,
        apple_platform_info = platform_support.apple_platform_info_from_rule_ctx(ctx),
        build_settings = apple_xplat_toolchain_info.build_settings,
        config_vars = ctx.var,
        cpp_fragment = ctx.fragments.cpp,
        device_families = rule_descriptor.allowed_device_families,
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
        mac_exec_group = mac_exec_group,
        platform_prerequisites = platform_prerequisites,
        product_type = rule_descriptor.product_type,
        provisioning_profile = provisioning_profile,
        rule_label = label,
        validation_mode = ctx.attr.entitlements_validation,
    )

    extra_linkopts = [
        "-fapplication-extension",
        "-e",
        "_WKExtensionMain",
    ]

    # This is required when building with watchOS SDK 6.0 or higher but with a minimum
    # deployment version lower than 6.0. See
    # https://developer.apple.com/documentation/xcode_release_notes/xcode_11_release_notes.
    minimum_os = apple_common.dotted_version(ctx.attr.minimum_os_version)
    if minimum_os < apple_common.dotted_version("6.0"):
        extra_linkopts.append(
            # The linker will search for this library relative to sysroot, which will already
            # be the watchOS SDK directory.
            #
            # This is a force-load (unlike Xcode, which uses a standard `-l`) because we can't
            # easily control where it appears in the link order relative to WatchKit.framework
            # (where this symbol also lives, in watchOS 6+), so we need to guarantee that the
            # linker doesn't skip the static library's implementation of `WKExtensionMain` if
            # it already resolved the symbol from the framework.
            "-Wl,-force_load,/usr/lib/libWKExtensionMainLegacy.a",
        )

    link_result = linking_support.register_binary_linking_action(
        ctx,
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
            bundle_id = bundle_id,
            entitlements = entitlements,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            product_type = rule_descriptor.product_type,
        ),
        partials.app_intents_metadata_bundle_partial(
            actions = actions,
            app_intents = [ctx.split_attr.deps],
            bundle_id = bundle_id,
            cc_toolchains = cc_toolchain_forwarder,
            embedded_bundles = [],
            label = label,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            label_name = ctx.label.name,
        ),
        partials.clang_rt_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            features = features,
            label_name = label.name,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            dylibs = clang_rt_dylibs.get_from_toolchain(ctx),
        ),
        partials.codesigning_dossier_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            xplat_exec_group = xplat_exec_group,
            mac_exec_group = mac_exec_group,
            bundle_extension = bundle_extension,
            bundle_location = processor.location.plugin,
            bundle_name = bundle_name,
            embed_target_dossiers = True,
            entitlements = entitlements,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            provisioning_profile = provisioning_profile,
            rule_descriptor = rule_descriptor,
        ),
        partials.debug_symbols_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            dsym_binaries = debug_outputs.dsym_binaries,
            dsym_info_plist_template = apple_mac_toolchain_info.dsym_info_plist_template,
            linkmaps = debug_outputs.linkmaps,
            platform_prerequisites = platform_prerequisites,
            mac_exec_group = mac_exec_group,
            plisttool = apple_mac_toolchain_info.plisttool,
            rule_label = label,
            version = ctx.attr.version,
        ),
        partials.embedded_bundles_partial(
            platform_prerequisites = platform_prerequisites,
            plugins = [archive],
        ),
        # Following guidance of the watchOS 2 migration guide's recommendations for placement of a
        # framework, scoping dynamic frameworks only to the watch extension bundles:
        # https://developer.apple.com/library/archive/documentation/General/Conceptual/AppleWatch2TransitionGuide/ConfiguretheXcodeProject.html
        partials.framework_import_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            features = features,
            label_name = label.name,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            provisioning_profile = provisioning_profile,
            rule_descriptor = rule_descriptor,
            targets = ctx.attr.deps,
        ),
        partials.resources_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            mac_exec_group = mac_exec_group,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            environment_plist = ctx.file._environment_plist,
            platform_prerequisites = platform_prerequisites,
            resource_deps = resource_deps,
            resource_locales = ctx.attr.resource_locales,
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
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        xplat_exec_group = xplat_exec_group,
        mac_exec_group = mac_exec_group,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        entitlements = entitlements,
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
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
            )
        ),
        new_watchosextensionbundleinfo(),
        # TODO(b/228856372): Remove when downstream users are migrated off this provider.
        link_result.debug_outputs_provider,
    ] + processor_result.providers

def _watchos_single_target_application_impl(ctx):
    """Implementation of watchos_application for single target watch applications."""

    minimum_os = apple_common.dotted_version(ctx.attr.minimum_os_version)
    if minimum_os < apple_common.dotted_version("7.0"):
        fail("Single-target watchOS applications require a minimum_os_version of 7.0 or greater.")

    if ctx.attr.extension:
        fail("""
Single-target watchOS applications do not support watchOS 2 extensions or their delegates.

Please remove the assigned watchOS 2 app `extension` and make sure a valid watchOS application
delegate is referenced in the single-target `watchos_application`'s `deps`.
""")

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
    cc_toolchain_forwarder = ctx.split_attr._cc_toolchain_forwarder
    embeddable_targets = ctx.attr.deps
    features = features_support.compute_enabled_features(
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites(
        apple_fragment = ctx.fragments.apple,
        apple_platform_info = platform_support.apple_platform_info_from_rule_ctx(ctx),
        build_settings = apple_xplat_toolchain_info.build_settings,
        config_vars = ctx.var,
        cpp_fragment = ctx.fragments.cpp,
        device_families = rule_descriptor.allowed_device_families,
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
    )
    top_level_resources = resources.collect(
        attr = ctx.attr,
        res_attrs = [
            "app_icons",
            "storyboards",
            "strings",
            "resources",
        ],
    )

    entitlements = entitlements_support.process_entitlements(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        mac_exec_group = mac_exec_group,
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
            bundle_id = bundle_id,
            entitlements = entitlements,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            product_type = rule_descriptor.product_type,
        ),
        partials.app_intents_metadata_bundle_partial(
            actions = actions,
            app_intents = [ctx.split_attr.deps],
            bundle_id = bundle_id,
            cc_toolchains = cc_toolchain_forwarder,
            embedded_bundles = [],
            label = label,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            label_name = label.name,
        ),
        partials.clang_rt_dylibs_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            binary_artifact = binary_artifact,
            features = features,
            label_name = label.name,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            dylibs = clang_rt_dylibs.get_from_toolchain(ctx),
        ),
        partials.codesigning_dossier_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            xplat_exec_group = xplat_exec_group,
            mac_exec_group = mac_exec_group,
            bundle_extension = bundle_extension,
            bundle_location = processor.location.watch,
            bundle_name = bundle_name,
            embed_target_dossiers = True,
            embedded_targets = embeddable_targets,
            entitlements = entitlements,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            provisioning_profile = provisioning_profile,
            rule_descriptor = rule_descriptor,
        ),
        partials.debug_symbols_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = embeddable_targets,
            dsym_binaries = debug_outputs.dsym_binaries,
            dsym_info_plist_template = apple_mac_toolchain_info.dsym_info_plist_template,
            linkmaps = debug_outputs.linkmaps,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            plisttool = apple_mac_toolchain_info.plisttool,
            rule_label = label,
            version = ctx.attr.version,
        ),
        partials.embedded_bundles_partial(
            bundle_embedded_bundles = True,
            embeddable_targets = embeddable_targets,
            platform_prerequisites = platform_prerequisites,
            watch_bundles = [archive],
        ),
        partials.framework_import_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            features = features,
            label_name = label.name,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            provisioning_profile = provisioning_profile,
            rule_descriptor = rule_descriptor,
            targets = ctx.attr.deps,
        ),
        partials.resources_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
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
            top_level_infoplists = top_level_infoplists,
            top_level_resources = top_level_resources,
            version = ctx.attr.version,
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
                profile_artifact = provisioning_profile,
                rule_label = label,
            ),
        )

    processor_result = processor.process(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        xplat_exec_group = xplat_exec_group,
        mac_exec_group = mac_exec_group,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        entitlements = entitlements,
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
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
            )
        ),
        new_watchosapplicationbundleinfo(),
    ] + processor_result.providers

watchos_application = rule_factory.create_apple_rule(
    cfg = transition_support.apple_rule_transition,
    doc = "Builds and bundles a watchOS Application.",
    implementation = _watchos_application_impl,
    predeclared_outputs = {"archive": "%{name}.zip"},
    attrs = [
        apple_support.platform_constraint_attrs(),
        rule_attrs.app_icon_attrs(),
        rule_attrs.binary_linking_attrs(
            base_cfg = transition_support.apple_rule_transition,
            deps_cfg = transition_support.apple_platform_split_transition,
            extra_deps_aspects = [
                app_intents_aspect,
                apple_resource_aspect,
                framework_provider_aspect,
            ],
            is_test_supporting_rule = False,
            requires_legacy_cc_toolchain = True,
        ),
        rule_attrs.cc_toolchain_forwarder_attrs(
            deps_cfg = transition_support.apple_platform_split_transition,
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
        {
            # TODO(b/155313625): Deprecate this in favor of a "real" `extensions` attr and check for
            # the incoming AppleBundleInfo product_type.
            "extension": attr.label(
                providers = [
                    [AppleBundleInfo, WatchosExtensionBundleInfo],
                ],
                doc = """
The watchOS 2 `watchos_extension` that is required to be bundled within a watchOS 2 application.

It is considered an error if the watchOS 2 application extension is assigned to a single target
watchOS application, which is constructed if the `watchos_application` target is assigned `deps`.

This attribute will not support additional types of `watchos_extension`s in the future.
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
            base_cfg = transition_support.apple_rule_transition,
            deps_cfg = transition_support.apple_platform_split_transition,
            extra_deps_aspects = [
                app_intents_aspect,
                apple_resource_aspect,
                framework_provider_aspect,
            ],
            is_test_supporting_rule = False,
            requires_legacy_cc_toolchain = True,
        ),
        rule_attrs.cc_toolchain_forwarder_attrs(
            deps_cfg = transition_support.apple_platform_split_transition,
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
            default_bundle_id_suffix = bundle_id_suffix_default.watchos2_app_extension,
        ),
    ],
)
