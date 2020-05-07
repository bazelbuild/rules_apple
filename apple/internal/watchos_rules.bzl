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
    "@build_bazel_apple_support//lib:xcode_support.bzl",
    "xcode_support",
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
    "@build_bazel_rules_apple//apple/internal:stub_support.bzl",
    "stub_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/aspects:swift_static_framework_aspect.bzl",
    "SwiftStaticFrameworkInfo",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "WatchosApplicationBundleInfo",
    "WatchosExtensionBundleInfo",
    "WatchosFrameworkBundleInfo",
    "WatchosStaticFrameworkBundleInfo",
)

def _watchos_application_impl(ctx):
    """Implementation of watchos_application."""
    rule_descriptor = rule_support.rule_descriptor(ctx)

    top_level_attrs = [
        "app_icons",
        "storyboards",
        "strings",
        "resources",
    ]

    binary_artifact = stub_support.create_stub_binary(
        ctx,
        xcode_stub_path = rule_descriptor.stub_binary_path,
    )

    bundle_id = ctx.attr.bundle_id

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

    processor_partials = [
        partials.apple_bundle_info_partial(bundle_id = bundle_id),
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.bitcode_symbols_partial(dependency_targets = [ctx.attr.extension]),
        partials.clang_rt_dylibs_partial(binary_artifact = binary_artifact),
        partials.debug_symbols_partial(debug_dependencies = [ctx.attr.extension]),
        partials.embedded_bundles_partial(
            bundle_embedded_bundles = True,
            embeddable_targets = [ctx.attr.extension],
            watch_bundles = [outputs.archive(ctx)],
        ),
        partials.resources_partial(
            bundle_id = bundle_id,
            bundle_verification_targets = bundle_verification_targets,
            plist_attrs = ["infoplists"],
            top_level_attrs = top_level_attrs,
        ),
        partials.swift_dylibs_partial(
            binary_artifact = binary_artifact,
            dependency_targets = [ctx.attr.extension],
            bundle_dylibs = True,
        ),
        partials.watchos_stub_partial(binary_artifact = binary_artifact),
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
        WatchosApplicationBundleInfo(),
    ] + processor_result.providers

def _watchos_extension_impl(ctx):
    """Implementation of watchos_extension."""
    top_level_attrs = [
        "app_icons",
        "strings",
        "resources",
    ]

    # Xcode 11 requires this flag to be passed to the linker, but it is not accepted by earlier
    # versions.
    # TODO(min(Xcode) >= 11): Make this unconditional when the minimum supported Xcode is Xcode 11.
    xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]
    if xcode_support.is_xcode_at_least_version(xcode_config, "11"):
        extra_linkopts = ["-e", "_WKExtensionMain"]

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
    else:
        extra_linkopts = []

    binary_descriptor = linking_support.register_linking_action(
        ctx,
        extra_linkopts = extra_linkopts,
    )
    binary_artifact = binary_descriptor.artifact
    debug_outputs_provider = binary_descriptor.debug_outputs_provider

    bundle_id = ctx.attr.bundle_id

    processor_partials = [
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
            plugins = [outputs.archive(ctx)],
            embeddable_targets = ctx.attr.frameworks,
        ),
        partials.extension_safe_validation_partial(is_extension_safe = True),
        # Following guidance of the watchOS 2 migration guide's recommendations for placement of a
        # framework, scoping dynamic frameworks only to the watch extension bundles:
        # https://developer.apple.com/library/archive/documentation/General/Conceptual/AppleWatch2TransitionGuide/ConfiguretheXcodeProject.html
        partials.framework_import_partial(targets = ctx.attr.deps),
        partials.resources_partial(
            bundle_id = bundle_id,
            plist_attrs = ["infoplists"],
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
        WatchosExtensionBundleInfo(),
    ] + processor_result.providers

def _watchos_framework_impl(ctx):
    """Experimental implementation of watchos_framework."""
    binary_descriptor = linking_support.register_linking_action(ctx)
    binary_artifact = binary_descriptor.artifact
    binary_provider = binary_descriptor.provider
    debug_outputs_provider = binary_descriptor.debug_outputs_provider

    bundle_id = ctx.attr.bundle_id

    signed_frameworks = []
    if getattr(ctx.file, "provisioning_profile", None):
        rule_descriptor = rule_support.rule_descriptor(ctx)
        signed_frameworks = [
            bundling_support.bundle_name(ctx) + rule_descriptor.bundle_extension,
        ]

    processor_partials = [
        partials.apple_bundle_info_partial(bundle_id = bundle_id),
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.bitcode_symbols_partial(
            binary_artifact = binary_artifact,
            debug_outputs_provider = debug_outputs_provider,
            dependency_targets = ctx.attr.frameworks,
        ),
        # TODO(kaipi): Check if clang_rt dylibs are needed in Frameworks, or if
        # the can be skipped.
        partials.clang_rt_dylibs_partial(binary_artifact = binary_artifact),
        partials.debug_symbols_partial(
            debug_dependencies = ctx.attr.frameworks,
            debug_outputs_provider = debug_outputs_provider,
        ),
        partials.embedded_bundles_partial(
            frameworks = [outputs.archive(ctx)],
            embeddable_targets = ctx.attr.frameworks,
            signed_frameworks = depset(signed_frameworks),
        ),
        partials.extension_safe_validation_partial(is_extension_safe = ctx.attr.extension_safe),
        partials.framework_headers_partial(hdrs = ctx.files.hdrs),
        partials.framework_provider_partial(binary_provider = binary_provider),
        partials.resources_partial(
            bundle_id = bundle_id,
            plist_attrs = ["infoplists"],
            targets_to_avoid = ctx.attr.frameworks,
            version_keys_required = False,
            top_level_attrs = ["resources"],
        ),
        partials.swift_dylibs_partial(
            binary_artifact = binary_artifact,
            dependency_targets = ctx.attr.frameworks,
        ),
    ]

    processor_result = processor.process(ctx, processor_partials)

    return [
        DefaultInfo(files = processor_result.output_files),
        WatchosFrameworkBundleInfo(),
    ] + processor_result.providers

def _watchos_static_framework_impl(ctx):
    """Implementation of watchos_static_framework."""

    # TODO(kaipi): Replace the debug_outputs_provider with the provider returned from the linking
    # action, when available.
    # TODO(kaipi): Extract this into a common location to be reused and refactored later when we
    # add linking support directly into the rule.
    binary_target = ctx.attr.deps[0]
    binary_artifact = binary_target[apple_common.AppleStaticLibrary].archive

    processor_partials = [
        partials.apple_bundle_info_partial(),
        partials.binary_partial(binary_artifact = binary_artifact),
    ]

    # If there's any Swift dependencies on the static framework rule, treat it as a Swift static
    # framework.
    if SwiftStaticFrameworkInfo in binary_target:
        processor_partials.append(
            partials.swift_static_framework_partial(
                swift_static_framework_info = binary_target[SwiftStaticFrameworkInfo],
            ),
        )
    else:
        processor_partials.append(
            partials.static_framework_header_modulemap_partial(
                hdrs = ctx.files.hdrs,
                umbrella_header = ctx.file.umbrella_header,
                binary_objc_provider = binary_target[apple_common.Objc],
            ),
        )

    if not ctx.attr.exclude_resources:
        processor_partials.append(partials.resources_partial())

    processor_result = processor.process(ctx, processor_partials)

    return [
        DefaultInfo(files = processor_result.output_files),
        WatchosStaticFrameworkBundleInfo(),
    ] + processor_result.providers

watchos_application = rule_factory.create_apple_bundling_rule(
    implementation = _watchos_application_impl,
    platform_type = "watchos",
    product_type = apple_product_type.watch2_application,
    doc = "Builds and bundles an watchOS Application.",
)

watchos_extension = rule_factory.create_apple_bundling_rule(
    implementation = _watchos_extension_impl,
    platform_type = "watchos",
    product_type = apple_product_type.watch2_extension,
    doc = "Builds and bundles an watchOS Extension.",
)

watchos_framework = rule_factory.create_apple_bundling_rule(
    implementation = _watchos_framework_impl,
    platform_type = "watchos",
    product_type = apple_product_type.framework,
    doc = "Builds and bundles a watchOS Dynamic Framework.",
)

watchos_static_framework = rule_factory.create_apple_bundling_rule(
    implementation = _watchos_static_framework_impl,
    platform_type = "watchos",
    product_type = apple_product_type.static_framework,
    doc = "Builds and bundles a watchOS Static Framework.",
)
