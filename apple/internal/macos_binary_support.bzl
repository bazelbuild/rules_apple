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
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/internal:linking_support.bzl",
    "linking_support",
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
    "@build_bazel_rules_apple//apple:providers.bzl",
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
    bundle_id = ctx.attr.bundle_id
    infoplists = ctx.files.infoplists
    if ctx.attr.version and AppleBundleVersionInfo in ctx.attr.version:
        version = ctx.attr.version[AppleBundleVersionInfo]
    else:
        version = None

    if not bundle_id and not infoplists and not version:
        fail("Internal error: at least one of bundle_id, infoplists, or version " +
             "should have been provided")

    merged_infoplist = intermediates.file(
        ctx.actions,
        ctx.label.name,
        "Info.plist",
    )

    resource_actions.merge_root_infoplists(
        ctx,
        input_plists = infoplists,
        output_plist = merged_infoplist,
        output_pkginfo = None,
        bundle_id = bundle_id,
        include_executable_name = False,
    )

    return [
        linking_support.sectcreate_objc_provider(
            "__TEXT",
            "__info_plist",
            merged_infoplist,
        ),
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
            "minimum_os_version": attr.string(mandatory = False),
            # TODO(kaipi): Make this private when it isn't also used by
            # apple_binary (when there is a linking api to use). It is public
            # for consistency and because this rule is an internal
            # implementation detail.
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
    fragments = ["apple", "objc"],
)

def _macos_command_line_launchdplist_impl(ctx):
    launchdplists = ctx.files.launchdplists

    if not launchdplists:
        fail("Internal error: launchdplists should have been provided")

    merged_launchdplist = intermediates.file(
        ctx.actions,
        ctx.label.name,
        "Launchd.plist",
    )

    resource_actions.merge_resource_infoplists(
        ctx,
        bundle_name = ctx.label.name,
        input_files = launchdplists,
        output_plist = merged_launchdplist,
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
        },
    ),
    fragments = ["apple", "objc"],
)
