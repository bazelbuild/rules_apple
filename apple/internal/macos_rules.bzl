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
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBinaryInfo",
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
    binary_descriptor = linking_support.register_linking_action(ctx)
    binary_artifact = binary_descriptor.artifact
    debug_outputs_provider = binary_descriptor.debug_outputs_provider

    embedded_targets = ctx.attr.extensions + ctx.attr.xpc_services

    actions = ctx.actions
    bin_root_path = ctx.bin_dir.path
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    bundle_verification_targets = [struct(target = ext) for ext in embedded_targets]
    entitlements = getattr(ctx.attr, "entitlements", None)
    executable_name = bundling_support.executable_name(ctx)
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    product_type = ctx.attr._product_type
    rule_descriptor = rule_support.rule_descriptor(ctx)
    rule_executables = ctx.executable
    rule_single_files = ctx.file

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
            product_type = product_type,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            executable_name = executable_name,
            label_name = label.name,
        ),
        partials.clang_rt_dylibs_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            clangrttool = ctx.executable._clangrttool,
            features = ctx.features,
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
            package_symbols = True,
            platform_prerequisites = platform_prerequisites,
            rule_label = label,
            rule_single_files = rule_single_files,
        ),
        partials.embedded_bundles_partial(
            bundle_embedded_bundles = True,
            embeddable_targets = embedded_targets,
            platform_prerequisites = platform_prerequisites,
        ),
        partials.framework_import_partial(
            actions = actions,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            rule_executables = rule_executables,
            targets = ctx.attr.deps + embedded_targets,
        ),
        partials.macos_additional_contents_partial(
            additional_contents = ctx.attr.additional_contents,
        ),
        partials.resources_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            executable_name = executable_name,
            bundle_verification_targets = bundle_verification_targets,
            platform_prerequisites = platform_prerequisites,
            plist_attrs = ["infoplists"],
            rule_attrs = ctx.attr,
            rule_descriptor = rule_descriptor,
            rule_executables = rule_executables,
            rule_label = label,
            rule_single_files = rule_single_files,
            top_level_attrs = [
                "app_icons",
                "strings",
                "resources",
            ],
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_dylibs = True,
            dependency_targets = embedded_targets,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            swift_stdlib_tool = ctx.executable._swift_stdlib_tool,
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

    processor_result = processor.process(ctx, processor_partials)

    executable = outputs.executable(
        actions = actions,
        label_name = label.name,
    )
    run_support.register_macos_executable(
        actions = actions,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        file = ctx.file,
        output = executable,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
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
        binary_descriptor.provider,
    ] + processor_result.providers

def _macos_bundle_impl(ctx):
    """Implementation of macos_bundle."""
    binary_descriptor = linking_support.register_linking_action(ctx)
    binary_artifact = binary_descriptor.artifact
    debug_outputs_provider = binary_descriptor.debug_outputs_provider

    actions = ctx.actions
    bin_root_path = ctx.bin_dir.path
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    entitlements = getattr(ctx.attr, "entitlements", None)
    executable_name = bundling_support.executable_name(ctx)
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    product_type = ctx.attr._product_type
    rule_descriptor = rule_support.rule_descriptor(ctx)
    rule_single_files = ctx.file

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
            product_type = product_type,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            executable_name = executable_name,
            label_name = label.name,
        ),
        partials.clang_rt_dylibs_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            clangrttool = ctx.executable._clangrttool,
            features = ctx.features,
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
            platform_prerequisites = platform_prerequisites,
            rule_label = label,
            rule_single_files = rule_single_files,
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
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            executable_name = executable_name,
            platform_prerequisites = platform_prerequisites,
            plist_attrs = ["infoplists"],
            rule_attrs = ctx.attr,
            rule_descriptor = rule_descriptor,
            rule_executables = ctx.executable,
            rule_label = label,
            rule_single_files = rule_single_files,
            top_level_attrs = [
                "app_icons",
                "strings",
                "resources",
            ],
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            swift_stdlib_tool = ctx.executable._swift_stdlib_tool,
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

    processor_result = processor.process(ctx, processor_partials)

    return [
        DefaultInfo(
            files = processor_result.output_files,
        ),
        MacosBundleBundleInfo(),
    ] + processor_result.providers

def _macos_extension_impl(ctx):
    """Experimental implementation of macos_extension."""
    extra_linkopts = []
    if not ctx.attr.provides_main:
        extra_linkopts.extend(["-e", "_NSExtensionMain"])
    binary_descriptor = linking_support.register_linking_action(ctx, extra_linkopts)
    binary_artifact = binary_descriptor.artifact
    debug_outputs_provider = binary_descriptor.debug_outputs_provider

    actions = ctx.actions
    bin_root_path = ctx.bin_dir.path
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    entitlements = getattr(ctx.attr, "entitlements", None)
    executable_name = bundling_support.executable_name(ctx)
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    product_type = ctx.attr._product_type
    rule_descriptor = rule_support.rule_descriptor(ctx)
    rule_single_files = ctx.file

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
            product_type = product_type,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            executable_name = executable_name,
            label_name = label.name,
        ),
        partials.clang_rt_dylibs_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            clangrttool = ctx.executable._clangrttool,
            features = ctx.features,
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
            platform_prerequisites = platform_prerequisites,
            rule_label = label,
            rule_single_files = rule_single_files,
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
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            executable_name = executable_name,
            platform_prerequisites = platform_prerequisites,
            plist_attrs = ["infoplists"],
            rule_attrs = ctx.attr,
            rule_descriptor = rule_descriptor,
            rule_executables = ctx.executable,
            rule_label = label,
            rule_single_files = rule_single_files,
            top_level_attrs = [
                "app_icons",
                "strings",
                "resources",
            ],
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            swift_stdlib_tool = ctx.executable._swift_stdlib_tool,
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

    processor_result = processor.process(ctx, processor_partials)

    return [
        DefaultInfo(
            files = processor_result.output_files,
        ),
        MacosExtensionBundleInfo(),
        binary_descriptor.provider,
    ] + processor_result.providers

def _macos_quick_look_plugin_impl(ctx):
    """Experimental implementation of macos_quick_look_plugin."""
    extra_linkopts = [
        "-install_name",
        "\"/Library/Frameworks/{0}.qlgenerator/{0}\"".format(ctx.attr.bundle_name),
    ]
    binary_descriptor = linking_support.register_linking_action(ctx, extra_linkopts)
    binary_artifact = binary_descriptor.artifact
    debug_outputs_provider = binary_descriptor.debug_outputs_provider

    actions = ctx.actions
    bin_root_path = ctx.bin_dir.path
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    entitlements = getattr(ctx.attr, "entitlements", None)
    executable_name = bundling_support.executable_name(ctx)
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    product_type = ctx.attr._product_type
    rule_descriptor = rule_support.rule_descriptor(ctx)
    rule_single_files = ctx.file

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
            product_type = product_type,
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
            binary_artifact = binary_artifact,
            clangrttool = ctx.executable._clangrttool,
            features = ctx.features,
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
            platform_prerequisites = platform_prerequisites,
            rule_label = label,
            rule_single_files = rule_single_files,
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
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            executable_name = executable_name,
            platform_prerequisites = platform_prerequisites,
            plist_attrs = ["infoplists"],
            rule_attrs = ctx.attr,
            rule_descriptor = rule_descriptor,
            rule_executables = ctx.executable,
            rule_label = label,
            rule_single_files = rule_single_files,
            top_level_attrs = [
                "strings",
                "resources",
            ],
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            swift_stdlib_tool = ctx.executable._swift_stdlib_tool,
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

    processor_result = processor.process(ctx, processor_partials)

    return [
        DefaultInfo(files = processor_result.output_files),
        MacosQuickLookPluginBundleInfo(),
    ] + processor_result.providers

def _macos_kernel_extension_impl(ctx):
    """Implementation of macos_kernel_extension."""
    binary_descriptor = linking_support.register_linking_action(ctx)
    binary_artifact = binary_descriptor.artifact
    debug_outputs_provider = binary_descriptor.debug_outputs_provider

    actions = ctx.actions
    bin_root_path = ctx.bin_dir.path
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    entitlements = getattr(ctx.attr, "entitlements", None)
    executable_name = bundling_support.executable_name(ctx)
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    product_type = ctx.attr._product_type
    rule_descriptor = rule_support.rule_descriptor(ctx)
    rule_single_files = ctx.file

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
            product_type = product_type,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            executable_name = executable_name,
            label_name = label.name,
        ),
        partials.clang_rt_dylibs_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            clangrttool = ctx.executable._clangrttool,
            features = ctx.features,
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
            platform_prerequisites = platform_prerequisites,
            rule_label = label,
            rule_single_files = rule_single_files,
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
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            executable_name = executable_name,
            platform_prerequisites = platform_prerequisites,
            plist_attrs = ["infoplists"],
            rule_attrs = ctx.attr,
            rule_descriptor = rule_descriptor,
            rule_executables = ctx.executable,
            rule_label = label,
            rule_single_files = rule_single_files,
            top_level_attrs = ["resources"],
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            swift_stdlib_tool = ctx.executable._swift_stdlib_tool,
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

    processor_result = processor.process(ctx, processor_partials)

    return [
        DefaultInfo(
            files = processor_result.output_files,
        ),
        MacosKernelExtensionBundleInfo(),
    ] + processor_result.providers

def _macos_spotlight_importer_impl(ctx):
    """Implementation of macos_spotlight_importer."""
    binary_descriptor = linking_support.register_linking_action(ctx)
    binary_artifact = binary_descriptor.artifact
    debug_outputs_provider = binary_descriptor.debug_outputs_provider

    actions = ctx.actions
    bin_root_path = ctx.bin_dir.path
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    entitlements = getattr(ctx.attr, "entitlements", None)
    executable_name = bundling_support.executable_name(ctx)
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    product_type = ctx.attr._product_type
    rule_descriptor = rule_support.rule_descriptor(ctx)
    rule_single_files = ctx.file

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
            product_type = product_type,
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
            binary_artifact = binary_artifact,
            clangrttool = ctx.executable._clangrttool,
            features = ctx.features,
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
            platform_prerequisites = platform_prerequisites,
            rule_label = label,
            rule_single_files = rule_single_files,
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
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            executable_name = executable_name,
            platform_prerequisites = platform_prerequisites,
            plist_attrs = ["infoplists"],
            rule_attrs = ctx.attr,
            rule_descriptor = rule_descriptor,
            rule_executables = ctx.executable,
            rule_label = label,
            rule_single_files = rule_single_files,
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            swift_stdlib_tool = ctx.executable._swift_stdlib_tool,
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

    processor_result = processor.process(ctx, processor_partials)

    return [
        DefaultInfo(
            files = processor_result.output_files,
        ),
        MacosSpotlightImporterBundleInfo(),
    ] + processor_result.providers

def _macos_xpc_service_impl(ctx):
    """Implementation of macos_xpc_service."""
    binary_descriptor = linking_support.register_linking_action(ctx)
    binary_artifact = binary_descriptor.artifact
    debug_outputs_provider = binary_descriptor.debug_outputs_provider

    actions = ctx.actions
    bin_root_path = ctx.bin_dir.path
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    entitlements = getattr(ctx.attr, "entitlements", None)
    executable_name = bundling_support.executable_name(ctx)
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    product_type = ctx.attr._product_type
    rule_descriptor = rule_support.rule_descriptor(ctx)
    rule_single_files = ctx.file

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
            product_type = product_type,
        ),
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            executable_name = executable_name,
            label_name = label.name,
        ),
        partials.clang_rt_dylibs_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            clangrttool = ctx.executable._clangrttool,
            features = ctx.features,
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
            platform_prerequisites = platform_prerequisites,
            rule_label = label,
            rule_single_files = rule_single_files,
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
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            executable_name = executable_name,
            platform_prerequisites = platform_prerequisites,
            plist_attrs = ["infoplists"],
            rule_attrs = ctx.attr,
            rule_descriptor = rule_descriptor,
            rule_executables = ctx.executable,
            rule_label = label,
            rule_single_files = rule_single_files,
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            swift_stdlib_tool = ctx.executable._swift_stdlib_tool,
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

    processor_result = processor.process(ctx, processor_partials)

    return [
        DefaultInfo(
            files = processor_result.output_files,
        ),
        MacosXPCServiceBundleInfo(),
    ] + processor_result.providers

def _macos_command_line_application_impl(ctx):
    """Implementation of the macos_command_line_application rule."""
    actions = ctx.actions
    bin_root_path = ctx.bin_dir.path
    binary_descriptor = linking_support.register_linking_action(ctx)
    binary_artifact = binary_descriptor.artifact
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    debug_outputs_provider = binary_descriptor.debug_outputs_provider
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    label = ctx.label
    rule_single_files = ctx.file

    debug_outputs_partial = partials.debug_symbols_partial(
        actions = actions,
        bin_root_path = bin_root_path,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        debug_outputs_provider = debug_outputs_provider,
        platform_prerequisites = platform_prerequisites,
        rule_label = label,
        rule_single_files = rule_single_files,
    )

    processor_result = processor.process(
        ctx,
        [debug_outputs_partial],
        bundle_post_process_and_sign = False,
    )
    output_file = actions.declare_file(label.name)
    codesigning_support.sign_binary_action(ctx, binary_artifact, output_file)

    return [
        AppleBinaryInfo(
            binary = output_file,
            product_type = ctx.attr._product_type,
        ),
        DefaultInfo(
            executable = output_file,
            files = depset(transitive = [
                depset([output_file]),
                processor_result.output_files,
            ]),
        ),
        binary_descriptor.provider,
    ] + processor_result.providers

def _macos_dylib_impl(ctx):
    """Implementation of the macos_dylib rule."""
    actions = ctx.actions
    bin_root_path = ctx.bin_dir.path
    binary_descriptor = linking_support.register_linking_action(ctx)
    binary_artifact = binary_descriptor.artifact
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    debug_outputs_provider = binary_descriptor.debug_outputs_provider
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    label = ctx.label
    rule_single_files = ctx.file

    debug_outputs_partial = partials.debug_symbols_partial(
        actions = actions,
        bin_root_path = bin_root_path,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        debug_outputs_provider = debug_outputs_provider,
        platform_prerequisites = platform_prerequisites,
        rule_label = label,
        rule_single_files = rule_single_files,
    )

    processor_result = processor.process(
        ctx,
        [debug_outputs_partial],
        bundle_post_process_and_sign = False,
    )
    output_file = actions.declare_file(label.name + ".dylib")
    codesigning_support.sign_binary_action(ctx, binary_artifact, output_file)

    return [
        AppleBinaryInfo(
            binary = output_file,
            product_type = ctx.attr._product_type,
        ),
        DefaultInfo(files = depset(transitive = [
            depset([output_file]),
            processor_result.output_files,
        ])),
        binary_descriptor.provider,
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
