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
# limitations under the Lice

"""Internal helper definitions used by macOS command line rules."""

load(
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/internal:apple_toolchains.bzl",
    "AppleMacToolsToolchainInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:bundling_support.bzl",
    "bundling_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/internal:linking_support.bzl",
    "linking_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:resource_actions.bzl",
    "resource_actions",
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
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBinaryInfoplistInfo",
    "AppleBundleVersionInfo",
)
load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)

def _macos_binary_infoplist_impl(ctx):
    """Implementation of the internal `macos_command_line_infoplist` rule.

    This rule is an internal implementation detail of
    `macos_command_line_application` and should not be used directly by clients.
    It merges Info.plists as would occur for a bundle but then propagates an
    `objc` provider with the necessary linkopts to embed the plist in a binary.

    Args:
      ctx: The rule context.

    Returns:
      A `struct` containing the `objc` provider that should be propagated to a
      binary that should have this plist embedded.
    """
    actions = ctx.actions
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    bundle_id = ctx.attr.bundle_id
    executable_name = bundling_support.executable_name(ctx)
    rule_descriptor = rule_support.rule_descriptor(ctx)
    rule_label = ctx.label
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)

    infoplists = ctx.files.infoplists
    if ctx.attr.version and AppleBundleVersionInfo in ctx.attr.version:
        version_found = True
    else:
        version_found = False

    if not bundle_id and not infoplists and not version_found:
        fail("Internal error: at least one of bundle_id, infoplists, or version " +
             "should have been provided")

    merged_infoplist = intermediates.file(
        actions = actions,
        target_name = rule_label.name,
        output_discriminator = None,
        file_name = "Info.plist",
    )

    resource_actions.merge_root_infoplists(
        actions = actions,
        bundle_extension = bundle_extension,
        bundle_id = bundle_id,
        bundle_name = bundle_name,
        executable_name = executable_name,
        environment_plist = ctx.file._environment_plist,
        include_executable_name = False,
        input_plists = infoplists,
        launch_storyboard = None,
        output_discriminator = None,
        output_pkginfo = None,
        output_plist = merged_infoplist,
        platform_prerequisites = platform_prerequisites,
        resolved_plisttool = ctx.attr._mac_toolchain[AppleMacToolsToolchainInfo].resolved_plisttool,
        rule_descriptor = rule_descriptor,
        rule_label = rule_label,
        version = ctx.attr.version,
    )

    return [
        linking_support.sectcreate_objc_provider(
            "__TEXT",
            "__info_plist",
            merged_infoplist,
        ),
        AppleBinaryInfoplistInfo(infoplist = merged_infoplist),
    ]

macos_binary_infoplist = rule(
    implementation = _macos_binary_infoplist_impl,
    attrs = dicts.add(
        rule_factory.common_tool_attributes,
        {
            "bundle_id": attr.string(mandatory = False),
            "infoplists": attr.label_list(
                allow_files = [".plist"],
                mandatory = False,
                allow_empty = True,
            ),
            "minimum_deployment_os_version": attr.string(mandatory = False),
            "minimum_os_version": attr.string(mandatory = False),
            "platform_type": attr.string(
                default = str(apple_common.platform_type.macos),
            ),
            "_environment_plist": attr.label(
                allow_single_file = True,
                default = "@build_bazel_rules_apple//apple/internal:environment_plist_macos",
            ),
            "version": attr.label(providers = [[AppleBundleVersionInfo]]),
            "_product_type": attr.string(default = apple_product_type.tool),
        },
    ),
    fragments = ["apple", "cpp", "objc"],
)

def _macos_command_line_launchdplist_impl(ctx):
    actions = ctx.actions
    bundle_name, bundle_extension = bundling_support.bundle_full_name_from_rule_ctx(ctx)
    rule_label = ctx.label
    launchdplists = ctx.files.launchdplists
    platform_prerequisites = platform_support.platform_prerequisites_from_rule_ctx(ctx)

    if not launchdplists:
        fail("Internal error: launchdplists should have been provided")

    merged_launchdplist = intermediates.file(
        actions = actions,
        target_name = rule_label.name,
        output_discriminator = None,
        file_name = "Launchd.plist",
    )

    resource_actions.merge_resource_infoplists(
        actions = actions,
        bundle_id = None,
        bundle_name_with_extension = bundle_name + bundle_extension,
        input_files = launchdplists,
        output_discriminator = None,
        output_plist = merged_launchdplist,
        platform_prerequisites = platform_prerequisites,
        resolved_plisttool = ctx.attr._mac_toolchain[AppleMacToolsToolchainInfo].resolved_plisttool,
        rule_label = rule_label,
    )

    return [
        linking_support.sectcreate_objc_provider(
            "__TEXT",
            "__launchd_plist",
            merged_launchdplist,
        ),
    ]

macos_command_line_launchdplist = rule(
    implementation = _macos_command_line_launchdplist_impl,
    attrs = dicts.add(
        rule_factory.common_tool_attributes,
        {
            "launchdplists": attr.label_list(
                allow_files = [".plist"],
                mandatory = False,
            ),
            "minimum_deployment_os_version": attr.string(mandatory = False),
            "minimum_os_version": attr.string(mandatory = False),
            "platform_type": attr.string(
                default = str(apple_common.platform_type.macos),
            ),
            "_product_type": attr.string(default = apple_product_type.tool),
        },
    ),
    fragments = ["apple", "cpp", "objc"],
)
