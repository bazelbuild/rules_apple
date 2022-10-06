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

"""Implementation for apple universal binary rules."""

load(
    "@build_bazel_rules_apple//apple/internal:rule_attrs.bzl",
    "rule_attrs",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBinaryInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:linking_support.bzl",
    "linking_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:transition_support.bzl",
    "transition_support",
)
load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "use_cpp_toolchain")

def _apple_universal_binary_impl(ctx):
    inputs = [
        binary.files.to_list()[0]
        for binary in ctx.split_attr.binary.values()
    ]

    if not inputs:
        fail("Target (%s) `binary` label ('%s') does not provide any " +
             "file for universal binary" % (ctx.attr.name, ctx.attr.binary))

    fat_binary = ctx.actions.declare_file(ctx.label.name)

    linking_support.lipo_or_symlink_inputs(
        actions = ctx.actions,
        inputs = inputs,
        output = fat_binary,
        apple_fragment = ctx.fragments.apple,
        xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
    )

    return [
        AppleBinaryInfo(
            binary = fat_binary,
        ),
        DefaultInfo(
            executable = fat_binary,
            files = depset([fat_binary]),
        ),
    ]

apple_universal_binary = rule(
    implementation = _apple_universal_binary_impl,
    attrs = dicts.add(
        rule_attrs.common_attrs,
        rule_attrs.platform_attrs(),
        {
            # Required to use the Apple Starlark rule and split transitions.
            "_allowlist_function_transition": attr.label(
                default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
            ),
            "binary": attr.label(
                mandatory = True,
                cfg = apple_common.multi_arch_split,
                doc = "Target to generate a 'fat' binary from.",
            ),
            "forced_cpus": attr.string_list(
                mandatory = False,
                allow_empty = True,
                doc = """
An optional list of target CPUs for which the universal binary should be built.

If this attribute is present, the value of the platform-specific CPU flag
(`--ios_multi_cpus`, `--macos_cpus`, `--tvos_cpus`, or `--watchos_cpus`) will be
ignored and the binary will be built for all of the specified architectures
instead.

This is primarily useful to force macOS tools to be built as universal binaries
using `forced_cpus = ["x86_64", "arm64"]`, without requiring the user to pass
additional flags when invoking Bazel.
""",
            ),
        },
    ),
    cfg = transition_support.apple_universal_binary_rule_transition,
    doc = """
This rule produces a multi-architecture ("fat") binary targeting Apple platforms.
The `lipo` tool is used to combine built binaries of multiple architectures.
""",
    fragments = ["apple", "cpp", "objc"],
    toolchains = use_cpp_toolchain(),
)
