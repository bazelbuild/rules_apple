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

"""Toolchains for the Linux-first execution platform regression test.

The Mac CI worker can run portable Python tools using a macOS interpreter even
when their actions select Linux. Simulator and environment plist tools retain
their normal toolchain configuration so an incorrect Linux selection fails.
"""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@rules_cc//cc:cc_toolchain_config_lib.bzl", "tool_path")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/toolchains:cc_toolchain_config_info.bzl", "CcToolchainConfigInfo")
load("//apple/build_settings:build_settings.bzl", "build_settings_labels")
load("//apple/internal:apple_toolchains.bzl", "AppleXPlatToolsToolchainInfo")

def _local_xplat_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        xplat_tools_info = AppleXPlatToolsToolchainInfo(
            build_settings = struct(**{
                setting.label.name: setting[BuildSettingInfo].value
                for setting in ctx.attr._build_settings
            }),
            bundletool = ctx.attr._bundletool,
            versiontool = ctx.attr._versiontool,
        ),
    )]

local_xplat_toolchain = rule(
    attrs = {
        "_build_settings": attr.label_list(
            default = build_settings_labels.all_labels,
            providers = [BuildSettingInfo],
        ),
        "_bundletool": attr.label(
            cfg = config.exec(exec_group = "macos"),
            default = "//tools/bundletool",
            executable = True,
        ),
        "_versiontool": attr.label(
            cfg = config.exec(exec_group = "macos"),
            default = "//tools/versiontool",
            executable = True,
        ),
    },
    exec_groups = {
        "macos": exec_group(exec_compatible_with = ["@platforms//os:macos"]),
    },
    implementation = _local_xplat_toolchain_impl,
)

def _unused_linux_cc_config_impl(ctx):
    return [cc_common.create_cc_toolchain_config_info(
        abi_libc_version = "unused",
        abi_version = "unused",
        compiler = "unavailable",
        ctx = ctx,
        host_system_name = "unused",
        target_cpu = "k8",
        target_libc = "unused",
        target_system_name = "unused",
        tool_paths = [
            tool_path(name = name, path = "/usr/bin/false")
            for name in ["ar", "cpp", "gcc", "gcov", "ld", "nm", "objcopy", "objdump", "strip"]
        ],
        toolchain_identifier = "unused_linux",
    )]

unused_linux_cc_config = rule(
    fragments = ["cpp"],
    implementation = _unused_linux_cc_config_impl,
    provides = [CcToolchainConfigInfo],
)
