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
    "MacosApplicationBundleInfo",
    "MacosBundleBundleInfo",
    "MacosExtensionBundleInfo",
)

def macos_application_impl(ctx):
    """Experimental implementation of macos_application."""
    # TODO(kaipi): Replace the debug_outputs_provider with the provider returned from the linking
    # action, when available.
    # TODO(kaipi): Extract this into a common location to be reused and refactored later when we
    # add linking support directly into the rule.

    binary_target = ctx.attr.deps[0]
    binary_artifact = binary_target[apple_common.AppleExecutableBinary].binary
    debug_outputs_provider = binary_target[apple_common.AppleDebugOutputs]

    processor_partials = [
        partials.apple_bundle_info_partial(),
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.clang_rt_dylibs_partial(binary_artifact = binary_artifact),
        partials.debug_symbols_partial(
            debug_dependencies = ctx.attr.extensions,
            debug_outputs_provider = debug_outputs_provider,
        ),
        partials.embedded_bundles_partial(targets = ctx.attr.extensions),
        partials.macos_additional_contents_partial(),
        partials.resources_partial(
            bundle_verification_targets = [struct(target = ext) for ext in ctx.attr.extensions],
            plist_attrs = ["infoplists"],
            top_level_attrs = [
                "app_icons",
                "strings",
            ],
        ),
        partials.swift_dylibs_partial(
            binary_artifact = binary_artifact,
            dependency_targets = ctx.attr.extensions,
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

def macos_bundle_impl(ctx):
    """Experimental implementation of macos_bundle."""
    # TODO(kaipi): Replace the debug_outputs_provider with the provider returned from the linking
    # action, when available.
    # TODO(kaipi): Extract this into a common location to be reused and refactored later when we
    # add linking support directly into the rule.

    binary_target = ctx.attr.deps[0]
    binary_artifact = binary_target[apple_common.AppleLoadableBundleBinary].binary

    processor_partials = [
        partials.apple_bundle_info_partial(),
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.clang_rt_dylibs_partial(binary_artifact = binary_artifact),
        partials.debug_symbols_partial(
            debug_outputs_provider = binary_target[apple_common.AppleDebugOutputs],
        ),
        partials.macos_additional_contents_partial(),
        partials.resources_partial(
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

    # This can't be made into a partial as it needs the output archive
    # reference.
    # TODO(kaipi): Remove direct reference to ctx.outputs.archive.
    embedded_bundles_provider = collect_embedded_bundle_provider(
        plugins = [ctx.outputs.archive],
    )

    return [
        DefaultInfo(
            files = processor_result.output_files,
        ),
        embedded_bundles_provider,
        MacosBundleBundleInfo(),
    ] + processor_result.providers

def macos_extension_impl(ctx):
    """Experimental implementation of macos_extension."""
    # TODO(kaipi): Replace the debug_outputs_provider with the provider returned from the linking
    # action, when available.
    # TODO(kaipi): Extract this into a common location to be reused and refactored later when we
    # add linking support directly into the rule.

    binary_target = ctx.attr.deps[0]
    binary_artifact = binary_target[apple_common.AppleExecutableBinary].binary

    processor_partials = [
        partials.apple_bundle_info_partial(),
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.clang_rt_dylibs_partial(binary_artifact = binary_artifact),
        partials.debug_symbols_partial(
            debug_outputs_provider = binary_target[apple_common.AppleDebugOutputs],
        ),
        partials.macos_additional_contents_partial(),
        partials.resources_partial(
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

    # This can't be made into a partial as it needs the output archive
    # reference.
    # TODO(kaipi): Remove direct reference to ctx.outputs.archive.
    embedded_bundles_provider = collect_embedded_bundle_provider(
        plugins = [ctx.outputs.archive],
    )

    return [
        DefaultInfo(
            files = processor_result.output_files,
        ),
        embedded_bundles_provider,
        MacosExtensionBundleInfo(),
    ] + processor_result.providers
