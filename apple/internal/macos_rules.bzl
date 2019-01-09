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

"""Experimental implementation of macOS rules."""

load(
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/internal:codesigning_actions.bzl",
    "codesigning_actions",
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
    "@build_bazel_rules_apple//apple/internal:processor.bzl",
    "processor",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_factory.bzl",
    "rule_factory",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "MacosApplicationBundleInfo",
    "MacosBundleBundleInfo",
    "MacosExtensionBundleInfo",
    "MacosKernelExtensionBundleInfo",
    "MacosSpotlightImporterBundleInfo",
    "MacosXPCServiceBundleInfo",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)

def _macos_application_impl(ctx):
    """Implementation of macos_application."""
    # TODO(kaipi): Replace the debug_outputs_provider with the provider returned from the linking
    # action, when available.
    # TODO(kaipi): Extract this into a common location to be reused and refactored later when we
    # add linking support directly into the rule.

    binary_target = ctx.attr.deps[0]
    binary_artifact = binary_target[apple_common.AppleExecutableBinary].binary
    debug_outputs_provider = binary_target[apple_common.AppleDebugOutputs]

    bundle_id = ctx.attr.bundle_id
    embedded_targets = ctx.attr.extensions + ctx.attr.xpc_services

    processor_partials = [
        partials.apple_bundle_info_partial(bundle_id = bundle_id),
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.clang_rt_dylibs_partial(binary_artifact = binary_artifact),
        partials.debug_symbols_partial(
            debug_dependencies = embedded_targets,
            debug_outputs_provider = debug_outputs_provider,
        ),
        partials.embedded_bundles_partial(
            bundle_embedded_bundles = True,
            embeddable_targets = embedded_targets,
        ),
        partials.framework_import_partial(
            targets = ctx.attr.deps + embedded_targets,
        ),
        partials.macos_additional_contents_partial(),
        partials.resources_partial(
            bundle_id = bundle_id,
            bundle_verification_targets = [struct(target = ext) for ext in embedded_targets],
            plist_attrs = ["infoplists"],
            top_level_attrs = [
                "app_icons",
                "strings",
            ],
        ),
        partials.swift_dylibs_partial(
            binary_artifact = binary_artifact,
            dependency_targets = embedded_targets,
            bundle_dylibs = True,
        ),
    ]

    if ctx.file.provisioning_profile:
        processor_partials.append(
            partials.provisioning_profile_partial(profile_artifact = ctx.file.provisioning_profile),
        )

    processor_result = processor.process(ctx, processor_partials)

    # TODO(kaipi): Add support for `bazel run` for macos_application.
    executable = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(
        executable,
        "#!/bin/bash\necho Unimplemented",
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = executable,
            files = processor_result.output_files,
        ),
        MacosApplicationBundleInfo(),
    ] + processor_result.providers

def _macos_bundle_impl(ctx):
    """Implementation of macos_bundle."""
    # TODO(kaipi): Replace the debug_outputs_provider with the provider returned from the linking
    # action, when available.
    # TODO(kaipi): Extract this into a common location to be reused and refactored later when we
    # add linking support directly into the rule.

    binary_target = ctx.attr.deps[0]
    binary_provider_type = apple_common.AppleLoadableBundleBinary
    binary_artifact = binary_target[binary_provider_type].binary

    bundle_id = ctx.attr.bundle_id

    processor_partials = [
        partials.apple_bundle_info_partial(bundle_id = bundle_id),
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.clang_rt_dylibs_partial(binary_artifact = binary_artifact),
        partials.debug_symbols_partial(
            debug_outputs_provider = binary_target[apple_common.AppleDebugOutputs],
        ),
        partials.embedded_bundles_partial(
            plugins = [outputs.archive(ctx)],
        ),
        partials.macos_additional_contents_partial(),
        partials.resources_partial(
            bundle_id = bundle_id,
            plist_attrs = ["infoplists"],
            top_level_attrs = [
                "app_icons",
                "strings",
            ],
        ),
        partials.swift_dylibs_partial(
            binary_artifact = binary_artifact,
        ),
    ]

    if ctx.file.provisioning_profile:
        processor_partials.append(
            partials.provisioning_profile_partial(profile_artifact = ctx.file.provisioning_profile),
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
    # TODO(kaipi): Replace the debug_outputs_provider with the provider returned from the linking
    # action, when available.
    # TODO(kaipi): Extract this into a common location to be reused and refactored later when we
    # add linking support directly into the rule.

    binary_target = ctx.attr.deps[0]
    binary_artifact = binary_target[apple_common.AppleExecutableBinary].binary

    bundle_id = ctx.attr.bundle_id

    processor_partials = [
        partials.apple_bundle_info_partial(bundle_id = bundle_id),
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.clang_rt_dylibs_partial(binary_artifact = binary_artifact),
        partials.debug_symbols_partial(
            debug_outputs_provider = binary_target[apple_common.AppleDebugOutputs],
        ),
        partials.embedded_bundles_partial(plugins = [outputs.archive(ctx)]),
        partials.macos_additional_contents_partial(),
        partials.resources_partial(
            bundle_id = bundle_id,
            plist_attrs = ["infoplists"],
            top_level_attrs = [
                "app_icons",
                "strings",
            ],
        ),
        partials.swift_dylibs_partial(
            binary_artifact = binary_artifact,
        ),
    ]

    if ctx.file.provisioning_profile:
        processor_partials.append(
            partials.provisioning_profile_partial(profile_artifact = ctx.file.provisioning_profile),
        )

    processor_result = processor.process(ctx, processor_partials)

    return [
        DefaultInfo(
            files = processor_result.output_files,
        ),
        MacosExtensionBundleInfo(),
    ] + processor_result.providers

def _macos_kernel_extension_impl(ctx):
    """Implementation of macos_kernel_extension."""
    binary_provider_struct = apple_common.link_multi_arch_binary(ctx = ctx)
    binary_provider = binary_provider_struct.binary_provider
    debug_outputs_provider = binary_provider_struct.debug_outputs_provider
    binary_artifact = binary_provider.binary

    bundle_id = ctx.attr.bundle_id

    processor_partials = [
        partials.apple_bundle_info_partial(bundle_id = bundle_id),
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.clang_rt_dylibs_partial(binary_artifact = binary_artifact),
        partials.debug_symbols_partial(
            debug_outputs_provider = debug_outputs_provider,
        ),
        partials.embedded_bundles_partial(
            plugins = [outputs.archive(ctx)],
        ),
        partials.macos_additional_contents_partial(),
        partials.resources_partial(
            bundle_id = bundle_id,
            plist_attrs = ["infoplists"],
        ),
        partials.swift_dylibs_partial(
            binary_artifact = binary_artifact,
        ),
    ]

    if ctx.file.provisioning_profile:
        processor_partials.append(
            partials.provisioning_profile_partial(profile_artifact = ctx.file.provisioning_profile),
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
    binary_provider_struct = apple_common.link_multi_arch_binary(ctx = ctx)
    binary_provider = binary_provider_struct.binary_provider
    debug_outputs_provider = binary_provider_struct.debug_outputs_provider
    binary_artifact = binary_provider.binary

    bundle_id = ctx.attr.bundle_id

    processor_partials = [
        partials.apple_bundle_info_partial(bundle_id = bundle_id),
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.clang_rt_dylibs_partial(binary_artifact = binary_artifact),
        partials.debug_symbols_partial(
            debug_outputs_provider = debug_outputs_provider,
        ),
        partials.embedded_bundles_partial(
            plugins = [outputs.archive(ctx)],
        ),
        partials.macos_additional_contents_partial(),
        partials.resources_partial(
            bundle_id = bundle_id,
            plist_attrs = ["infoplists"],
        ),
        partials.swift_dylibs_partial(
            binary_artifact = binary_artifact,
        ),
    ]

    if ctx.file.provisioning_profile:
        processor_partials.append(
            partials.provisioning_profile_partial(profile_artifact = ctx.file.provisioning_profile),
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
    binary_provider_struct = apple_common.link_multi_arch_binary(ctx = ctx)
    binary_provider = binary_provider_struct.binary_provider
    debug_outputs_provider = binary_provider_struct.debug_outputs_provider
    binary_artifact = binary_provider.binary

    bundle_id = ctx.attr.bundle_id

    processor_partials = [
        partials.apple_bundle_info_partial(bundle_id = bundle_id),
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.clang_rt_dylibs_partial(binary_artifact = binary_artifact),
        partials.debug_symbols_partial(
            debug_outputs_provider = debug_outputs_provider,
        ),
        partials.embedded_bundles_partial(
            xpc_services = [outputs.archive(ctx)],
        ),
        partials.macos_additional_contents_partial(),
        partials.resources_partial(
            bundle_id = bundle_id,
            plist_attrs = ["infoplists"],
        ),
        partials.swift_dylibs_partial(
            binary_artifact = binary_artifact,
        ),
    ]

    if ctx.file.provisioning_profile:
        processor_partials.append(
            partials.provisioning_profile_partial(profile_artifact = ctx.file.provisioning_profile),
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
    output_file = ctx.actions.declare_file(ctx.label.name)

    providers = []
    outputs = [depset([output_file])]

    binary_target = ctx.attr.deps[0]
    binary_artifact = binary_target[apple_common.AppleExecutableBinary].binary
    debug_outputs_provider = binary_target[apple_common.AppleDebugOutputs]

    debug_outputs_partial = partials.debug_symbols_partial(
        debug_outputs_provider = debug_outputs_provider,
    )

    result = partial.call(debug_outputs_partial, ctx)
    outputs.append(result.output_files)
    providers.extend(result.providers)

    codesigning_actions.sign_binary_action(ctx, binary_artifact, output_file)

    return [
        DefaultInfo(
            executable = output_file,
            files = depset(transitive = outputs),
        ),
    ] + providers

def _macos_dylib_impl(ctx):
    """Implementation of the macos_dylib rule."""
    output_file = ctx.actions.declare_file(ctx.label.name + ".dylib")

    providers = []
    outputs = [depset([output_file])]

    binary_target = ctx.attr.deps[0]
    binary_artifact = binary_target[apple_common.AppleDylibBinary].binary
    debug_outputs_provider = binary_target[apple_common.AppleDebugOutputs]

    debug_outputs_partial = partials.debug_symbols_partial(
        debug_outputs_provider = debug_outputs_provider,
    )

    result = partial.call(debug_outputs_partial, ctx)
    outputs.append(result.output_files)
    providers.extend(result.providers)

    codesigning_actions.sign_binary_action(ctx, binary_artifact, output_file)

    return [
        DefaultInfo(files = depset(transitive = outputs)),
    ] + providers

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
