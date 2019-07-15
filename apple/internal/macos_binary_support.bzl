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

def _macos_binary_infoplist_link_flag(ctx, bundle_id, infoplists):
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

    return linking_support.sectcreate_link_flag("__TEXT", "__info_plist", merged_infoplist)

def _macos_binary_launchdplist_link_flag(ctx, launchdplists):
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

    return linking_support.sectcreate_link_flag("__TEXT", "__launchd_plist", merged_launchdplist)

macos_binary_support = struct(
    macos_binary_infoplist_link_flag = _macos_binary_infoplist_link_flag,
    macos_binary_launchdplist_link_flag = _macos_binary_launchdplist_link_flag,
)
