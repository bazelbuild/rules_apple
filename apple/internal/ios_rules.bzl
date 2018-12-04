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

"""Experimental implementation of iOS rules."""

load(
    "@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:product_support.bzl",
    "apple_product_type",
    "product_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:run_actions.bzl",
    "run_actions",
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
    "@build_bazel_rules_apple//apple/internal:rule_support.bzl",
    "rule_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:stub_support.bzl",
    "stub_support",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "IosApplicationBundleInfo",
    "IosExtensionBundleInfo",
    "IosFrameworkBundleInfo",
    "IosImessageApplicationBundleInfo",
    "IosImessageExtensionBundleInfo",
    "IosStaticFrameworkBundleInfo",
    "IosStickerPackExtensionBundleInfo",
)

def ios_application_impl(ctx):
    """Experimental implementation of ios_application."""
    top_level_attrs = [
        "app_icons",
        "launch_images",
        "launch_storyboard",
        "strings",
    ]

    # TODO(kaipi): Replace the debug_outputs_provider with the provider returned from the linking
    # action, when available.
    # TODO(kaipi): Extract this into a common location to be reused and refactored later when we
    # add linking support directly into the rule.
    binary_target = ctx.attr.deps[0]
    binary_artifact = binary_target[apple_common.AppleExecutableBinary].binary

    bundle_id = ctx.attr.bundle_id
    bundle_verification_targets = [struct(target = ext) for ext in ctx.attr.extensions]
    embeddable_targets = ctx.attr.frameworks + ctx.attr.extensions
    if ctx.attr.watch_application:
        embeddable_targets.append(ctx.attr.watch_application)

        bundle_verification_targets.append(
            struct(
                target = ctx.attr.watch_application,
                parent_bundle_id_reference = ["WKCompanionAppBundleIdentifier"],
            ),
        )

    processor_partials = [
        partials.app_assets_validation_partial(
            app_icons = ctx.files.app_icons,
            launch_images = ctx.files.launch_images,
        ),
        partials.apple_bundle_info_partial(bundle_id = bundle_id),
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.embedded_bundles_partial(
            bundle_embedded_bundles = True,
            embeddable_targets = embeddable_targets,
        ),
        partials.framework_import_partial(
            targets = ctx.attr.deps + ctx.attr.extensions + ctx.attr.frameworks,
        ),
        partials.resources_partial(
            bundle_id = bundle_id,
            bundle_verification_targets = bundle_verification_targets,
            plist_attrs = ["infoplists"],
            targets_to_avoid = ctx.attr.frameworks,
            top_level_attrs = top_level_attrs,
        ),
        partials.settings_bundle_partial(),
    ]

    if ctx.attr.watch_application:
        processor_partials.append(
            partials.watchos_stub_partial(package_watchkit_support = True),
        )

    stub_binary = None
    if product_support.contains_stub_binary(ctx):
        stub_binary = binary_artifact
    else:
        # Only add binary processing partials if the target does not use stub binaries.
        processor_partials.extend([
            partials.bitcode_symbols_partial(
                binary_artifact = binary_artifact,
                debug_outputs_provider = binary_target[apple_common.AppleDebugOutputs],
                dependency_targets = embeddable_targets,
                package_bitcode = True,
            ),
            partials.clang_rt_dylibs_partial(binary_artifact = binary_artifact),
            partials.debug_symbols_partial(
                debug_dependencies = embeddable_targets,
                debug_outputs_provider = binary_target[apple_common.AppleDebugOutputs],
            ),
            partials.swift_dylibs_partial(
                binary_artifact = binary_artifact,
                dependency_targets = embeddable_targets,
                bundle_dylibs = True,
                # TODO(kaipi): Revisit if we can add this only for non enterprise optimized
                # builds, or at least only for device builds.
                package_swift_support = True,
            ),
        ])

    processor_partials.append(
        # We need to add this partial everytime in case any of the extensions uses a stub binary and
        # the stub needs to be packaged in the support directories.
        partials.messages_stub_partial(
            binary_artifact = stub_binary,
            package_messages_support = True,
        ),
    )

    if platform_support.is_device_build(ctx):
        processor_partials.append(
            partials.provisioning_profile_partial(profile_artifact = ctx.file.provisioning_profile),
        )

    processor_result = processor.process(ctx, processor_partials)

    return [
        DefaultInfo(
            files = processor_result.output_files,
            runfiles = ctx.runfiles(
                files = run_actions.start_simulator(ctx),
            ),
        ),
        IosApplicationBundleInfo(),
    ] + processor_result.providers

def ios_framework_impl(ctx):
    """Experimental implementation of ios_framework."""
    # TODO(kaipi): Add support for packaging headers.

    # TODO(kaipi): Replace the debug_outputs_provider with the provider returned from the linking
    # action, when available.
    # TODO(kaipi): Extract this into a common location to be reused and refactored later when we
    # add linking support directly into the rule.
    binary_target = ctx.attr.deps[0]
    binary_artifact = binary_target[apple_common.AppleDylibBinary].binary

    bundle_id = ctx.attr.bundle_id

    processor_partials = [
        partials.apple_bundle_info_partial(bundle_id = bundle_id),
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.bitcode_symbols_partial(
            binary_artifact = binary_artifact,
            debug_outputs_provider = binary_target[apple_common.AppleDebugOutputs],
            dependency_targets = ctx.attr.frameworks,
        ),
        # TODO(kaipi): Check if clang_rt dylibs are needed in Frameworks, or if
        # the can be skipped.
        partials.clang_rt_dylibs_partial(binary_artifact = binary_artifact),
        partials.debug_symbols_partial(
            debug_dependencies = ctx.attr.frameworks,
            debug_outputs_provider = binary_target[apple_common.AppleDebugOutputs],
        ),
        partials.embedded_bundles_partial(
            frameworks = [ctx.outputs.archive],
            embeddable_targets = ctx.attr.frameworks,
        ),
        partials.extension_safe_validation_partial(is_extension_safe = ctx.attr.extension_safe),
        partials.framework_headers_partial(hdrs = ctx.files.hdrs),
        partials.framework_provider_partial(),
        partials.resources_partial(
            bundle_id = bundle_id,
            plist_attrs = ["infoplists"],
            targets_to_avoid = ctx.attr.frameworks,
            version_keys_required = False,
        ),
        partials.swift_dylibs_partial(
            binary_artifact = binary_artifact,
            dependency_targets = ctx.attr.frameworks,
        ),
    ]

    processor_result = processor.process(ctx, processor_partials)

    return [
        DefaultInfo(files = processor_result.output_files),
        IosFrameworkBundleInfo(),
    ] + processor_result.providers

def ios_extension_impl(ctx):
    """Experimental implementation of ios_extension."""
    top_level_attrs = [
        "app_icons",
        "strings",
    ]

    # TODO(kaipi): Replace the debug_outputs_provider with the provider returned from the linking
    # action, when available.
    # TODO(kaipi): Extract this into a common location to be reused and refactored later when we
    # add linking support directly into the rule.
    binary_target = ctx.attr.deps[0]
    binary_artifact = binary_target[apple_common.AppleExecutableBinary].binary

    bundle_id = ctx.attr.bundle_id

    processor_partials = [
        partials.app_assets_validation_partial(
            app_icons = ctx.files.app_icons,
        ),
        partials.apple_bundle_info_partial(bundle_id = bundle_id),
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.embedded_bundles_partial(
            plugins = [ctx.outputs.archive],
            embeddable_targets = ctx.attr.frameworks,
        ),
        partials.extension_safe_validation_partial(is_extension_safe = True),
        partials.resources_partial(
            bundle_id = bundle_id,
            plist_attrs = ["infoplists"],
            targets_to_avoid = ctx.attr.frameworks,
            top_level_attrs = top_level_attrs,
        ),
    ]

    if product_support.contains_stub_binary(ctx):
        processor_partials.append(
            partials.messages_stub_partial(binary_artifact = binary_artifact),
        )
    else:
        # Only add binary processing partials if the target does not use stub binaries.
        processor_partials.extend([
            partials.bitcode_symbols_partial(
                binary_artifact = binary_artifact,
                debug_outputs_provider = binary_target[apple_common.AppleDebugOutputs],
                dependency_targets = ctx.attr.frameworks,
            ),
            partials.clang_rt_dylibs_partial(binary_artifact = binary_artifact),
            partials.debug_symbols_partial(
                debug_dependencies = ctx.attr.frameworks,
                debug_outputs_provider = binary_target[apple_common.AppleDebugOutputs],
            ),
            partials.swift_dylibs_partial(
                binary_artifact = binary_artifact,
                dependency_targets = ctx.attr.frameworks,
            ),
        ])

    if platform_support.is_device_build(ctx):
        processor_partials.append(
            partials.provisioning_profile_partial(profile_artifact = ctx.file.provisioning_profile),
        )

    processor_result = processor.process(ctx, processor_partials)

    return [
        DefaultInfo(
            files = processor_result.output_files,
        ),
        IosExtensionBundleInfo(),
    ] + processor_result.providers

def ios_static_framework_impl(ctx):
    """Experimental implementation of ios_static_framework."""

    # TODO(kaipi): Replace the debug_outputs_provider with the provider returned from the linking
    # action, when available.
    # TODO(kaipi): Extract this into a common location to be reused and refactored later when we
    # add linking support directly into the rule.
    binary_target = ctx.attr.deps[0]
    binary_artifact = binary_target[apple_common.AppleStaticLibrary].archive

    processor_partials = [
        partials.apple_bundle_info_partial(),
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.static_framework_header_modulemap_partial(
            hdrs = ctx.files.hdrs,
            binary_objc_provider = binary_target[apple_common.Objc],
        ),
    ]

    if not ctx.attr.exclude_resources:
        processor_partials.append(partials.resources_partial())

    processor_result = processor.process(ctx, processor_partials)

    return [
        DefaultInfo(files = processor_result.output_files),
        IosStaticFrameworkBundleInfo(),
    ] + processor_result.providers

def _ios_imessage_application_impl(ctx):
    """Experimental implementation of ios_imessage_application."""
    rule_descriptor = rule_support.rule_descriptor(ctx)

    top_level_attrs = [
        "app_icons",
        "strings",
    ]

    binary_artifact = stub_support.create_stub_binary(
        ctx,
        xcode_stub_path = rule_descriptor.stub_binary_path,
    )

    bundle_id = ctx.attr.bundle_id

    bundle_verification_targets = [struct(target = ctx.attr.extension)]
    embeddable_targets = [ctx.attr.extension]

    processor_partials = [
        partials.app_assets_validation_partial(
            app_icons = ctx.files.app_icons,
        ),
        partials.apple_bundle_info_partial(bundle_id = bundle_id),
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.embedded_bundles_partial(
            bundle_embedded_bundles = True,
            embeddable_targets = embeddable_targets,
        ),
        partials.framework_import_partial(targets = [ctx.attr.extension]),
        partials.messages_stub_partial(
            binary_artifact = binary_artifact,
            package_messages_support = True,
        ),
        partials.resources_partial(
            bundle_id = bundle_id,
            bundle_verification_targets = bundle_verification_targets,
            plist_attrs = ["infoplists"],
            top_level_attrs = top_level_attrs,
        ),
    ]

    if platform_support.is_device_build(ctx):
        processor_partials.append(
            partials.provisioning_profile_partial(profile_artifact = ctx.file.provisioning_profile),
        )

    processor_result = processor.process(ctx, processor_partials)

    return [
        DefaultInfo(
            files = processor_result.output_files,
        ),
        IosImessageApplicationBundleInfo(),
    ] + processor_result.providers

def _ios_imessage_extension_impl(ctx):
    """Experimental implementation of ios_imessage_extension."""
    top_level_attrs = [
        "app_icons",
        "strings",
    ]

    binary_provider_struct = apple_common.link_multi_arch_binary(ctx = ctx)
    binary_provider = binary_provider_struct.binary_provider
    debug_outputs_provider = binary_provider_struct.debug_outputs_provider
    binary_artifact = binary_provider.binary

    bundle_id = ctx.attr.bundle_id

    processor_partials = [
        # TODO(kaipi): Refactor this partial into a more generic interface to account for
        # sticker_assets as a top level attribute.
        partials.app_assets_validation_partial(
            app_icons = ctx.files.app_icons,
        ),
        partials.apple_bundle_info_partial(bundle_id = bundle_id),
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.bitcode_symbols_partial(
            binary_artifact = binary_artifact,
            debug_outputs_provider = debug_outputs_provider,
            dependency_targets = ctx.attr.frameworks,
        ),
        partials.clang_rt_dylibs_partial(binary_artifact = binary_artifact),
        partials.debug_symbols_partial(
            debug_dependencies = ctx.attr.frameworks,
            debug_outputs_provider = debug_outputs_provider,
        ),
        partials.embedded_bundles_partial(
            plugins = [ctx.outputs.archive],
            embeddable_targets = ctx.attr.frameworks,
        ),
        partials.extension_safe_validation_partial(is_extension_safe = True),
        partials.resources_partial(
            bundle_id = bundle_id,
            plist_attrs = ["infoplists"],
            targets_to_avoid = ctx.attr.frameworks,
            top_level_attrs = top_level_attrs,
        ),
        partials.swift_dylibs_partial(
            binary_artifact = binary_artifact,
            dependency_targets = ctx.attr.frameworks,
        ),
    ]

    if platform_support.is_device_build(ctx):
        processor_partials.append(
            partials.provisioning_profile_partial(profile_artifact = ctx.file.provisioning_profile),
        )

    processor_result = processor.process(ctx, processor_partials)

    return [
        DefaultInfo(
            files = processor_result.output_files,
        ),
        IosExtensionBundleInfo(),
        IosImessageExtensionBundleInfo(),
    ] + processor_result.providers

def _ios_sticker_pack_extension_impl(ctx):
    """Experimental implementation of ios_sticker_pack_extension."""
    rule_descriptor = rule_support.rule_descriptor(ctx)

    top_level_attrs = [
        "sticker_assets",
        "strings",
    ]

    binary_artifact = stub_support.create_stub_binary(
        ctx,
        xcode_stub_path = rule_descriptor.stub_binary_path,
    )

    bundle_id = ctx.attr.bundle_id

    processor_partials = [
        # TODO(kaipi): Refactor this partial into a more generic interface to account for
        # sticker_assets as a top level attribute.
        partials.app_assets_validation_partial(
            app_icons = ctx.files.sticker_assets,
        ),
        partials.apple_bundle_info_partial(bundle_id = bundle_id),
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.embedded_bundles_partial(
            plugins = [outputs.archive(ctx)],
        ),
        partials.resources_partial(
            bundle_id = bundle_id,
            plist_attrs = ["infoplists"],
            top_level_attrs = top_level_attrs,
        ),
        partials.messages_stub_partial(binary_artifact = binary_artifact),
    ]

    if platform_support.is_device_build(ctx):
        processor_partials.append(
            partials.provisioning_profile_partial(profile_artifact = ctx.file.provisioning_profile),
        )

    processor_result = processor.process(ctx, processor_partials)

    return [
        DefaultInfo(
            files = processor_result.output_files,
        ),
        IosExtensionBundleInfo(),
        IosStickerPackExtensionBundleInfo(),
    ] + processor_result.providers

# Rule definitions for rules that use the Skylark linking API and the new rule_factory support.
# TODO(b/118104491): Move these definitions into apple/ios.bzl, when there's no need to override
# attributes.

ios_imessage_application = rule_factory.create_apple_bundling_rule(
    implementation = _ios_imessage_application_impl,
    platform_type = "ios",
    product_type = apple_product_type.messages_application,
    doc = "Builds and bundles an iOS iMessage Application.",
)

ios_imessage_extension = rule_factory.create_apple_bundling_rule(
    implementation = _ios_imessage_extension_impl,
    platform_type = "ios",
    product_type = apple_product_type.messages_extension,
    doc = "Builds and bundles an iOS iMessage Extension.",
)

ios_sticker_pack_extension = rule_factory.create_apple_bundling_rule(
    implementation = _ios_sticker_pack_extension_impl,
    platform_type = "ios",
    product_type = apple_product_type.messages_sticker_pack_extension,
    doc = "Builds and bundles an iOS Sticker Pack Extension.",
)
