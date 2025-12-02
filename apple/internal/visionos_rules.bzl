# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""Implementation of visionOS rules."""

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
    "new_appleexecutablebinaryinfo",
    "new_visionosapplicationbundleinfo",
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
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

def _visionos_application_impl(ctx):
    """Implementation of visionos_application."""
    xcode_version_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]
    rule_descriptor = rule_support.rule_descriptor(
        platform_type = ctx.attr.platform_type,
        product_type = apple_product_type.application,
    )

    # Add the disable_legacy_signing feature to the list of features, forcing dossier signing as a
    # requirement of this rule.
    #
    # TODO - b/463682069: Move this ctx.features/features.append(...) to be rolled into the
    # make_cc_configured_features_init call below, and make it so that "features" isn't an argument
    # passed to the processor partial, we can just query the features configuration directly.
    # Right now we have too many sources of truth for ctx.features, some of which disagree.
    #
    # TODO - b/72148898: Remove disable_legacy_signing when dossier based signing is the default.
    requested_features = ctx.features
    requested_features.append("disable_legacy_signing")

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
    cc_toolchain_forwarder = ctx.split_attr._cc_toolchain_forwarder
    features = features_support.compute_enabled_features(
        requested_features = requested_features,
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
        xcode_version_config = xcode_version_config,
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
            "resources",
            "strings",
        ],
        rule_label = ctx.label,
    )

    entitlements = entitlements_support.process_entitlements(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_id = bundle_id,
        cc_configured_features_init = features_support.make_cc_configured_features_init(ctx),
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

    extra_requested_features = []
    if ctx.attr.testonly:
        extra_requested_features.append("exported_symbols")

    link_result = linking_support.register_binary_linking_action(
        ctx,
        build_settings = apple_xplat_toolchain_info.build_settings,
        bundle_name = bundle_name,
        cc_toolchains = cc_toolchain_forwarder,
        entitlements = entitlements,
        exported_symbols_lists = ctx.files.exported_symbols_lists,
        extra_requested_features = extra_requested_features,
        platform_prerequisites = platform_prerequisites,
        rule_descriptor = rule_descriptor,
        stamp = ctx.attr.stamp,
    )
    binary_artifact = link_result.binary
    debug_outputs = linking_support.debug_outputs_by_architecture(link_result.outputs)
    linking_contexts = [output.linking_context for output in link_result.outputs]

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
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            entitlements = entitlements,
            label_name = label.name,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
            provisioning_profile = provisioning_profile,
            rule_descriptor = rule_descriptor,
            xplat_exec_group = xplat_exec_group,
        ),
        partials.debug_symbols_partial(
            actions = actions,
            apple_mac_toolchain_info = apple_mac_toolchain_info,
            apple_xplat_toolchain_info = apple_xplat_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            debug_dependencies = ctx.attr.deps,
            dsym_outputs = debug_outputs.dsym_outputs,
            dsym_info_plist_template = apple_mac_toolchain_info.dsym_info_plist_template,
            linkmaps = debug_outputs.linkmaps,
            mac_exec_group = mac_exec_group,
            platform_prerequisites = platform_prerequisites,
            rule_label = label,
            version = ctx.attr.version,
            xplat_exec_group = xplat_exec_group,
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
            primary_icon_name = ctx.attr.primary_app_icon,
            resource_deps = resource_deps,
            resource_locales = ctx.attr.resource_locales,
            rule_descriptor = rule_descriptor,
            rule_label = label,
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
            label_name = label.name,
            mac_exec_group = mac_exec_group,
            package_swift_support_if_needed = True,
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
        entitlements = entitlements,
        features = features,
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

    run_support.register_simulator_executable(
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

    dsyms = outputs.dsyms(
        platform_prerequisites = platform_prerequisites,
        processor_result = processor_result,
    )

    return [
        DefaultInfo(
            executable = executable,
            files = processor_result.output_files,
            runfiles = ctx.runfiles(
                files = [archive],
                transitive_files = dsyms,
            ),
        ),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
            )
        ),
        new_visionosapplicationbundleinfo(),
        new_appleexecutablebinaryinfo(
            binary = binary_artifact,
            binary_linking_context = cc_common.merge_linking_contexts(
                linking_contexts = linking_contexts,
            ),
        ),
    ] + processor_result.providers

visionos_application = rule_factory.create_apple_rule(
    cfg = transition_support.apple_rule_transition,
    doc = "Builds and bundles a visionOS Application.",
    implementation = _visionos_application_impl,
    is_executable = True,
    # Required to supply a "dummy archive" for the tree artifact processor.
    predeclared_outputs = {"archive": "%{name}.zip"},
    attrs = [
        apple_support.platform_constraint_attrs(),
        rule_attrs.app_icon_attrs(
            supports_alternate_icons = True,
        ),
        rule_attrs.binary_linking_attrs(
            deps_cfg = transition_support.apple_platform_split_transition,
            extra_deps_aspects = [
                apple_resource_aspect,
            ],
            is_test_supporting_rule = False,
        ),
        rule_attrs.common_bundle_attrs(),
        rule_attrs.common_tool_attrs(),
        rule_attrs.device_family_attrs(
            allowed_families = rule_attrs.defaults.allowed_families.visionos,
        ),
        rule_attrs.infoplist_attrs(),
        rule_attrs.platform_attrs(
            add_environment_plist = True,
            platform_type = "visionos",
        ),
        rule_attrs.signing_attrs(
            default_bundle_id_suffix = bundle_id_suffix_default.bundle_name,
        ),
        rule_attrs.simulator_runner_template_attr(),
        {
            "_force_bundle_outputs": attr.bool(
                default = True,
                doc = """
Internal attribute read by Apple rule transitions to set the
`force_bundle_outputs` build setting.
""",
            ),
        },
    ],
)
