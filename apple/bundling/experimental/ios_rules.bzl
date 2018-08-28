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
    "product_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:partials.bzl",
    "partials",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:processor.bzl",
    "processor",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental/partials:embedded_bundles.bzl",
    "collect_embedded_bundle_provider",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "IosApplicationBundleInfo",
    "IosExtensionBundleInfo",
    "IosFrameworkBundleInfo",
    "IosStaticFrameworkBundleInfo",
)

def ios_application_impl(ctx):
    """Experimental implementation of ios_application."""

    # TODO(kaipi): Handle other things related to iOS apps, like frameworks,
    # extensions and SwiftSupport.
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
        partials.apple_bundle_info_partial(),
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.embedded_bundles_partial(targets = embeddable_targets),
        partials.framework_import_partial(
            targets = ctx.attr.deps + ctx.attr.extensions + ctx.attr.frameworks,
        ),
        partials.resources_partial(
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
                debug_dependencies = ctx.attr.frameworks + ctx.attr.extensions,
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

    # TODO(kaipi): Add support for `bazel run` for ios_application.
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

    processor_partials = [
        partials.apple_bundle_info_partial(),
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
        partials.extension_safe_validation_partial(is_extension_safe = ctx.attr.extension_safe),
        partials.framework_headers_partial(hdrs = ctx.files.hdrs),
        partials.framework_provider_partial(),
        partials.resources_partial(
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

    # This can't be made into a partial as it needs the output archive reference.
    # TODO(kaipi): Remove direct reference to ctx.outputs.archive.
    embedded_bundles_provider = collect_embedded_bundle_provider(
        frameworks = [ctx.outputs.archive],
        targets = ctx.attr.frameworks,
    )

    return [
        DefaultInfo(files = processor_result.output_files),
        embedded_bundles_provider,
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

    processor_partials = [
        partials.app_assets_validation_partial(
            app_icons = ctx.files.app_icons,
        ),
        partials.apple_bundle_info_partial(),
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.extension_safe_validation_partial(is_extension_safe = True),
        partials.resources_partial(
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

    # This can't be made into a partial as it needs the output archive
    # reference.
    # TODO(kaipi): Remove direct reference to ctx.outputs.archive.
    embedded_bundles_provider = collect_embedded_bundle_provider(
        plugins = [ctx.outputs.archive],
        targets = ctx.attr.frameworks,
    )

    return [
        DefaultInfo(
            files = processor_result.output_files,
        ),
        embedded_bundles_provider,
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
