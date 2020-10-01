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
    "@build_bazel_rules_apple//apple/internal:entitlements_support.bzl",
    "entitlements_support",
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
    "@build_bazel_rules_apple//apple:providers.bzl",
    "WatchosApplicationBundleInfo",
    "WatchosExtensionBundleInfo",
)

def _watchos_application_impl(ctx):
    """Implementation of watchos_application."""
    top_level_attrs = [
        "app_icons",
        "storyboards",
        "strings",
        "resources",
    ]

    actions = ctx.actions
    bin_root_path = ctx.bin_dir.path
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    entitlements = entitlements_support.entitlements(
        entitlements_attr = getattr(ctx.attr, "entitlements", None),
        entitlements_file = getattr(ctx.file, "entitlements", None),
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    rule_descriptor = rule_support.rule_descriptor(ctx)
    rule_executables = ctx.executable

    binary_artifact = stub_support.create_stub_binary(
        ctx,
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
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            label_name = label.name,
        ),
        partials.bitcode_symbols_partial(
            actions = actions,
            dependency_targets = [ctx.attr.extension],
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
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
            debug_dependencies = [ctx.attr.extension],
            dsym_info_plist_template = ctx.file._dsym_info_plist_template,
            platform_prerequisites = platform_prerequisites,
            rule_label = label,
        ),
        partials.embedded_bundles_partial(
            bundle_embedded_bundles = True,
            embeddable_targets = [ctx.attr.extension],
            platform_prerequisites = platform_prerequisites,
            watch_bundles = [archive],
        ),
        partials.resources_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            bundle_verification_targets = bundle_verification_targets,
            environment_plist = ctx.file._environment_plist,
            launch_storyboard = None,
            platform_prerequisites = platform_prerequisites,
            plist_attrs = ["infoplists"],
            rule_attrs = ctx.attr,
            rule_descriptor = rule_descriptor,
            rule_executables = rule_executables,
            rule_label = label,
            top_level_attrs = top_level_attrs,
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_dylibs = True,
            dependency_targets = [ctx.attr.extension],
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            swift_stdlib_tool = ctx.executable._swift_stdlib_tool,
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
                profile_artifact = ctx.file.provisioning_profile,
                rule_label = label,
            ),
        )

    processor_result = processor.process(
        ctx = ctx,
        actions = actions,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        entitlements = entitlements,
        partials = processor_partials,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        provisioning_profile = getattr(ctx.file, "provisioning_profile", None),
        rule_descriptor = rule_descriptor,
        rule_executables = rule_executables,
        rule_label = label,
    )

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

    actions = ctx.actions
    bin_root_path = ctx.bin_dir.path
    bundle_id = ctx.attr.bundle_id
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    entitlements = entitlements_support.entitlements(
        entitlements_attr = getattr(ctx.attr, "entitlements", None),
        entitlements_file = getattr(ctx.file, "entitlements", None),
    )
    label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)
    predeclared_outputs = ctx.outputs
    rule_descriptor = rule_support.rule_descriptor(ctx)
    rule_executables = ctx.executable

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
        partials.binary_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            bundle_name = bundle_name,
            label_name = ctx.label.name,
        ),
        partials.bitcode_symbols_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            debug_outputs_provider = debug_outputs_provider,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
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
            debug_outputs_provider = debug_outputs_provider,
            dsym_info_plist_template = ctx.file._dsym_info_plist_template,
            platform_prerequisites = platform_prerequisites,
            rule_label = label,
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
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            rule_executables = rule_executables,
            targets = ctx.attr.deps,
        ),
        partials.resources_partial(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_id = bundle_id,
            bundle_name = bundle_name,
            environment_plist = ctx.file._environment_plist,
            launch_storyboard = None,
            platform_prerequisites = platform_prerequisites,
            plist_attrs = ["infoplists"],
            rule_attrs = ctx.attr,
            rule_descriptor = rule_descriptor,
            rule_executables = rule_executables,
            rule_label = label,
            top_level_attrs = top_level_attrs,
        ),
        partials.swift_dylibs_partial(
            actions = actions,
            binary_artifact = binary_artifact,
            label_name = label.name,
            platform_prerequisites = platform_prerequisites,
            swift_stdlib_tool = ctx.executable._swift_stdlib_tool,
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
        ctx = ctx,
        actions = actions,
        bundle_extension = bundle_extension,
        bundle_name = bundle_name,
        entitlements = entitlements,
        partials = processor_partials,
        platform_prerequisites = platform_prerequisites,
        predeclared_outputs = predeclared_outputs,
        provisioning_profile = getattr(ctx.file, "provisioning_profile", None),
        rule_descriptor = rule_descriptor,
        rule_executables = rule_executables,
        rule_label = label,
    )

    return [
        DefaultInfo(
            files = processor_result.output_files,
        ),
        WatchosExtensionBundleInfo(),
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
