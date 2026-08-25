# Copyright 2026 The Bazel Authors. All rights reserved.
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

"""Bundling task for extracting App Extension Points."""

load(
    "@build_bazel_rules_apple//apple/internal:location_enum.bzl",
    "location_enum",
)
load(
    "@build_bazel_rules_apple//apple/internal/providers:app_extension_point_info.bzl",
    "AppExtensionPointInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/resource_actions:exutil.bzl",
    "extract_extension_points",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:targets.bzl",
    "targets",
)

visibility(["@build_bazel_rules_apple//apple/internal/..."])

def _app_extension_point_bundling_task_impl(
        *,
        actions,
        apple_mac_toolchain_info,
        apple_xplat_toolchain_info,
        bundle_id,
        deps,
        label,
        mac_exec_group,
        platform_prerequisites,
        xplat_exec_group):
    """Bundling task for extracting .appexpt files for apps."""
    deps_list = list(targets.target_set(deps))

    # Use a transitive depset to remove incoming duplicates.
    extension_point_inputs = depset(
        transitive = [
            dep[AppExtensionPointInfo].extension_points
            for dep in deps_list  # Only consider app module deps for extension points to promote.
            if AppExtensionPointInfo in dep
        ],
        order = "postorder",
    )

    if not extension_point_inputs:
        return struct()

    app_extension_point_files = extract_extension_points(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_id = bundle_id,
        extension_point_inputs = extension_point_inputs.to_list(),
        label = label,
        mac_exec_group = mac_exec_group,
        platform_prerequisites = platform_prerequisites,
        xplat_exec_group = xplat_exec_group,
    )

    if not app_extension_point_files:
        return struct()

    return struct(
        bundle_files = [(
            location_enum.extension,
            "",  # Deliberately needs to be placed in the root of the Extensions folder.
            depset(direct = app_extension_point_files),
        )],
    )

def app_extension_point_bundling_task(
        *,
        actions,
        apple_mac_toolchain_info,
        apple_xplat_toolchain_info,
        bundle_id,
        deps = [],
        label,
        mac_exec_group,
        platform_prerequisites,
        xplat_exec_group):
    return lambda *args, **kwargs: _app_extension_point_bundling_task_impl(
        actions = actions,
        apple_mac_toolchain_info = apple_mac_toolchain_info,
        apple_xplat_toolchain_info = apple_xplat_toolchain_info,
        bundle_id = bundle_id,
        deps = deps,
        label = label,
        mac_exec_group = mac_exec_group,
        platform_prerequisites = platform_prerequisites,
        xplat_exec_group = xplat_exec_group,
        *args,
        **kwargs
    )
