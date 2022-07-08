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
    "@build_bazel_rules_apple//apple/internal:rule_factory.bzl",
    "rule_factory",
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

apple_universal_binary = rule_factory.create_apple_binary_rule(
    doc = """
This rule produces a multi-architecture ("fat") binary targeting Apple platforms.
The `lipo` tool is used to combine built binaries of multiple architectures.
""",
    implementation = _apple_universal_binary_impl,
    require_linking_attrs = False,
    additional_attrs = {
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
    cfg = transition_support.apple_universal_binary_rule_transition,
)
