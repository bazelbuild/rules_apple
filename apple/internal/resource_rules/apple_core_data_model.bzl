# Copyright 2021 The Bazel Authors. All rights reserved.
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

"""Implementation of Apple Core Data Model resource rule."""

load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "group_files_by_directory",
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
    "@build_bazel_rules_apple//apple/internal:rule_attrs.bzl",
    "rule_attrs",
)
load(
    "@build_bazel_rules_apple//apple/internal/toolchains:apple_toolchains.bzl",
    "apple_toolchain_utils",
)

visibility("@build_bazel_rules_apple//apple/...")

def _apple_core_data_model_impl(ctx):
    """Implementation of the apple_core_data_model."""
    actions = ctx.actions
    swift_version = getattr(ctx.attr, "swift_version")
    apple_mac_toolchain_info = apple_toolchain_utils.get_mac_toolchain(ctx)
    apple_xplat_toolchain_info = apple_toolchain_utils.get_xplat_toolchain(ctx)
    mac_exec_group = apple_toolchain_utils.get_mac_exec_group(ctx)

    platform_prerequisites = platform_support.platform_prerequisites(
        apple_fragment = ctx.fragments.apple,
        apple_platform_info = platform_support.apple_platform_info_from_rule_ctx(ctx),
        build_settings = apple_xplat_toolchain_info.build_settings,
        config_vars = ctx.var,
        device_families = None,
        explicit_minimum_os = ctx.fragments.cpp.minimum_os_version(),
        objc_fragment = None,
        uses_swift = True,
        xcode_version_config =
            ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
    )

    datamodel_groups = group_files_by_directory(
        ctx.files.srcs,
        ["xcdatamodeld"],
        attr = "datamodels",
    )

    output_files = []
    for datamodel_path, files in datamodel_groups.items():
        datamodel_name = paths.replace_extension(
            paths.basename(datamodel_path),
            "",
        )

        dir_name = "{}.{}.coredata.sources".format(
            datamodel_name.lower(),
            ctx.label.name,
        )
        output_dir = actions.declare_directory(dir_name)

        resource_actions.generate_datamodels(
            actions = actions,
            datamodel_path = datamodel_path,
            input_files = files.to_list(),
            mac_exec_group = mac_exec_group,
            output_dir = output_dir,
            platform_prerequisites = platform_prerequisites,
            xctoolrunner = apple_mac_toolchain_info.xctoolrunner,
            swift_version = swift_version,
        )

        output_files.append(output_dir)

    return [DefaultInfo(files = depset(output_files))]

apple_core_data_model = rule(
    implementation = _apple_core_data_model_impl,
    exec_groups = apple_toolchain_utils.use_apple_exec_group_toolchain(),
    attrs = dicts.add(
        rule_attrs.common_tool_attrs(),
        apple_support.action_required_attrs(),
        apple_support.platform_constraint_attrs(),
        {
            "srcs": attr.label_list(
                allow_empty = False,
                allow_files = ["contents"],
                mandatory = True,
            ),
            "swift_version": attr.string(
                doc = "Target Swift version for generated classes.",
            ),
        },
    ),
    fragments = ["apple", "cpp"],
    doc = """
This rule takes a Core Data model definition from a .xcdatamodeld bundle
and generates Swift or Objective-C source files that can be added as a
dependency to a swift_library target.
""",
)
