# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Implementation of tvOS rules."""

load(
    "@build_bazel_rules_apple//apple/internal/aspects:swift_dynamic_framework_aspect.bzl",
    "SwiftDynamicFrameworkInfo",
)
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
    "@build_bazel_rules_apple//apple/internal/aspects:swift_static_framework_aspect.bzl",
    "SwiftStaticFrameworkInfo",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleSupportToolchainInfo",
    "TvosApplicationBundleInfo",
    "TvosExtensionBundleInfo",
    "TvosFrameworkBundleInfo",
    "TvosStaticFrameworkBundleInfo",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "SwiftInfo",
)

def _tvos_application_impl(ctx):
    """Experimental implementation of tvos_application."""
    top_level_attrs = [
        "app_icons",
        "launch_images",
        "strings",
        "resources",
    ]

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
    bundle_verification_targets = [struct(target = ext) for ext in ctx.attr.extensions]
    embeddable_targets = ctx.attr.extensions + ctx.attr.frameworks
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
    swift_dylib_dependencies = ctx.attr.extensions + ctx.attr.frameworks

    processor_partials = [
        partials.app_assets_validation_partial(
            app_icons = ctx.files.app_icons,
            launch_images = ctx.files.launch_images,
            platform_prerequisites = platform_prerequisites,
            product_type = rule_descriptor.product_type,
        ),
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
        partials.bitcode_symbols_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            debug_outputs_provider = debug_outputs_provider,
            dependency_targets = embeddable_targets,
            label_name = label.name,
            package_bitcode = True,
            platform_prerequisites = platform_prerequisites,
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
            debug_dependencies = embeddable_targets,
            debug_outputs_provider = debug_outputs_provider,
            dsym_info_plist_template = apple_toolchain_info.dsym_info_plist_template,
            executable_name = executable_name,
            package_symbols = True,
            platform_prerequisites = platform_prerequisites,
            rule_label = label,
        ),
        partials.embedded_bundles_partial(
            bundle_embedded_bundles = True,
            embeddable_targets = embeddable_targets,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.framework_import_partial(
            actions = actions,
            apple_toolchain_info = apple_toolchain_info,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            provisioning_profile = getattr(ctx.file, "provisioning_profile", None),
            rule_descriptor = rule_descriptor,
            targets = ctx.attr.deps + embeddable_targets,
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
            targets_to_avoid = ctx.attr.frameworks,
            top_level_attrs = top_level_attrs,
        ),
        partials.settings_bundle_partial(
            actions = actions,
            platform_prerequisites = platform_prerequisites,
            rule_label = label,
            settings_bundle = ctx.attr.settings_bundle,
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            apple_toolchain_info = apple_toolchain_info,
            binary_artifact = binary_artifact,
            bundle_dylibs = True,
            dependency_targets = swift_dylib_dependencies,
            label_name = label.name,
            package_swift_support_if_needed = True,
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
        apple_toolchain_info = apple_toolchain_info,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        codesign_inputs = ctx.files.codesign_inputs,
        codesignopts = codesigning_support.codesignopts_from_rule_ctx(ctx),
        executable_name = executable_name,
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

    return [
        DefaultInfo(
            executable = executable,
            files = processor_result.output_files,
            runfiles = ctx.runfiles(
                files = [archive, apple_toolchain_info.std_redirect_dylib],
            ),
        ),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
            )
        ),
        TvosApplicationBundleInfo(),
        # Propagate the binary provider so that this target can be used as bundle_loader in test
        # rules.
        link_result.binary_provider,
    ] + processor_result.providers

def _tvos_dynamic_framework_impl(ctx):
    """Experimental implementation of tvos_dynamic_framework."""

    # This rule should only have one swift_library dependency. This means len(ctx.attr.deps) should be 2
    # because of the swift_runtime_linkopts dep that comes with the swift_libray
    swiftdeps = [x for x in ctx.attr.deps if SwiftInfo in x]
    if len(swiftdeps) != 1 or len(ctx.attr.deps) > 2:
        fail(
            """\
    error: Swift dynamic frameworks expect a single swift_library dependency.
    """,
        )

    binary_target = [deps for deps in ctx.attr.deps if deps.label.name.endswith("swift_runtime_linkopts")][0]
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
    entitlements = entitlements_support.entitlements(
        entitlements_attr = getattr(ctx.attr, "entitlements", None),
        entitlements_file = getattr(ctx.file, "entitlements", None),
    )
    executable_name = bundling_support.executable_name(ctx)
    features = features_support.compute_enabled_features(
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    rule_descriptor = rule_support.rule_descriptor(ctx)

    signed_frameworks = []
    if getattr(ctx.file, "provisioning_profile", None):
        signed_frameworks = [
            bundle_name + rule_descriptor.bundle_extension,
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
        partials.bitcode_symbols_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            debug_outputs_provider = debug_outputs_provider,
            dependency_targets = ctx.attr.frameworks,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
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
            debug_dependencies = ctx.attr.frameworks,
            debug_outputs_provider = debug_outputs_provider,
            dsym_info_plist_template = apple_toolchain_info.dsym_info_plist_template,
            executable_name = executable_name,
            platform_prerequisites = platform_prerequisites,
            rule_label = label,
        ),
        partials.embedded_bundles_partial(
            frameworks = [archive],
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
            binary_provider = link_result.binary_provider,
            bundle_name = bundle_name,
            bundle_only = False,
            rule_label = label,
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
            targets_to_avoid = ctx.attr.frameworks,
            top_level_attrs = ["resources"],
            version_keys_required = False,
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            apple_toolchain_info = apple_toolchain_info,
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

    providers = processor_result.providers
    additional_providers = []
    for provider in providers:
        if type(provider) == "AppleDynamicFramework":
            # Make the ObjC provider using the framework_files depset found
            # in the AppleDynamicFramework provider. This is to make the
            # tvos_dynamic_framework usable as a dependency in swift_library
            objc_provider = apple_common.new_objc_provider(
                dynamic_framework_file = provider.framework_files,
            )
            additional_providers.append(objc_provider)
    providers.extend(additional_providers)

    return [
        DefaultInfo(files = processor_result.output_files),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
            )
        ),
        TvosFrameworkBundleInfo(),
    ] + providers

def _tvos_framework_impl(ctx):
    """Experimental implementation of tvos_framework."""
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

    signed_frameworks = []
    if getattr(ctx.file, "provisioning_profile", None):
        signed_frameworks = [
            bundle_name + rule_descriptor.bundle_extension,
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
        partials.bitcode_symbols_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            debug_outputs_provider = debug_outputs_provider,
            dependency_targets = ctx.attr.frameworks,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
        # TODO(kaipi): Check if clang_rt dylibs are needed in Frameworks, or if
        # the can be skipped.
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
            debug_dependencies = ctx.attr.frameworks,
            debug_outputs_provider = debug_outputs_provider,
            dsym_info_plist_template = apple_toolchain_info.dsym_info_plist_template,
            executable_name = executable_name,
            platform_prerequisites = platform_prerequisites,
            rule_label = label,
        ),
        partials.embedded_bundles_partial(
            frameworks = [archive],
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
            binary_provider = link_result.binary_provider,
            bundle_name = bundle_name,
            bundle_only = False,
            rule_label = label,
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
            targets_to_avoid = ctx.attr.frameworks,
            top_level_attrs = ["resources"],
            version_keys_required = False,
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            apple_toolchain_info = apple_toolchain_info,
            binary_artifact = binary_artifact,
            dependency_targets = ctx.attr.frameworks,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
        ),
    ]

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
        DefaultInfo(files = processor_result.output_files),
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
            )
        ),
        TvosFrameworkBundleInfo(),
    ] + processor_result.providers

def _tvos_extension_impl(ctx):
    """Experimental implementation of tvos_extension."""
    top_level_attrs = [
        "app_icons",
        "strings",
        "resources",
    ]

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
        partials.bitcode_symbols_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            debug_outputs_provider = debug_outputs_provider,
            dependency_targets = ctx.attr.frameworks,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
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
            debug_dependencies = ctx.attr.frameworks,
            debug_outputs_provider = debug_outputs_provider,
            dsym_info_plist_template = apple_toolchain_info.dsym_info_plist_template,
            executable_name = executable_name,
            platform_prerequisites = platform_prerequisites,
            rule_label = label,
        ),
        partials.embedded_bundles_partial(
            embeddable_targets = ctx.attr.frameworks,
            platform_prerequisites = platform_prerequisites,
            plugins = [archive],
        ),
        partials.extension_safe_validation_partial(
            is_extension_safe = True,
            rule_label = label,
            targets_to_validate = ctx.attr.frameworks,
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
            targets_to_avoid = ctx.attr.frameworks,
            top_level_attrs = top_level_attrs,
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            apple_toolchain_info = apple_toolchain_info,
            binary_artifact = binary_artifact,
            dependency_targets = ctx.attr.frameworks,
            label_name = label.name,
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
        OutputGroupInfo(
            **outputs.merge_output_groups(
                link_result.output_groups,
                processor_result.output_groups,
            )
        ),
        TvosExtensionBundleInfo(),
        # Propagate the binary provider so that this target can be used as bundle_loader in test
        # rules.
        link_result.binary_provider,
    ] + processor_result.providers

def _tvos_static_framework_impl(ctx):
    """Implementation of tvos_static_framework."""

    binary_target = ctx.attr.deps[0]
    binary_artifact = binary_target[apple_common.AppleStaticLibrary].archive

    actions = ctx.actions
    apple_toolchain_info = ctx.attr._toolchain[AppleSupportToolchainInfo]
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

    processor_partials = [
        partials.apple_bundle_info_partial(
            actions = actions,
            bundle_extension = bundle_extension,
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
    ]

    # If there's any Swift dependencies on the static framework rule, treat it as a Swift static
    # framework.
    if SwiftStaticFrameworkInfo in binary_target:
        processor_partials.append(
            partials.swift_static_framework_partial(
                actions = actions,
                bundle_name = bundle_name,
                label_name = label.name,
                swift_static_framework_info = binary_target[SwiftStaticFrameworkInfo],
            ),
        )
    else:
        processor_partials.append(
            partials.static_framework_header_modulemap_partial(
                actions = actions,
                binary_objc_provider = binary_target[apple_common.Objc],
                bundle_name = bundle_name,
                hdrs = ctx.files.hdrs,
                label_name = label.name,
                umbrella_header = ctx.file.umbrella_header,
            ),
        )

    if not ctx.attr.exclude_resources:
        rule_descriptor = rule_support.rule_descriptor(ctx)

        processor_partials.append(partials.resources_partial(
            actions = actions,
            apple_toolchain_info = apple_toolchain_info,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            environment_plist = ctx.file._environment_plist,
            executable_name = executable_name,
            launch_storyboard = None,
            platform_prerequisites = platform_prerequisites,
            rule_attrs = ctx.attr,
            rule_descriptor = rule_descriptor,
            rule_label = label,
        ))

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
        DefaultInfo(files = processor_result.output_files),
        OutputGroupInfo(**processor_result.output_groups),
        TvosStaticFrameworkBundleInfo(),
    ] + processor_result.providers

tvos_application = rule_factory.create_apple_bundling_rule(
    implementation = _tvos_application_impl,
    platform_type = "tvos",
    product_type = apple_product_type.application,
    doc = "Builds and bundles a tvOS Application.",
)
tvos_dynamic_framework = rule_factory.create_apple_bundling_rule(
    implementation = _tvos_dynamic_framework_impl,
    platform_type = "tvos",
    product_type = apple_product_type.framework,
    doc = "Builds and bundles a tvOS dynamic framework that is consumable by Xcode.",
)
tvos_extension = rule_factory.create_apple_bundling_rule(
    implementation = _tvos_extension_impl,
    platform_type = "tvos",
    product_type = apple_product_type.app_extension,
    doc = "Builds and bundles a tvOS Extension.",
)

tvos_framework = rule_factory.create_apple_bundling_rule(
    implementation = _tvos_framework_impl,
    platform_type = "tvos",
    product_type = apple_product_type.framework,
    doc = "Builds and bundles a tvOS Dynamic Framework.",
)

tvos_static_framework = rule_factory.create_apple_bundling_rule(
    implementation = _tvos_static_framework_impl,
    platform_type = "tvos",
    product_type = apple_product_type.static_framework,
    doc = "Builds and bundles a tvOS Static Framework.",
)
