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
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load("@build_bazel_apple_support//lib:lipo.bzl", "lipo")
load("@build_bazel_apple_support//xcode:providers.bzl", "XcodeVersionInfo")
load(
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "new_applebinaryinfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:transition_support.bzl",
    "transition_support",
)

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

def _lipo_or_symlink_inputs(*, actions, inputs, output, apple_platform_info, xcode_config):
    """Creates a universal binary with `lipo` if inputs > 1, symlinks otherwise."""
    if len(inputs) > 1:
        lipo.create(
            actions = actions,
            inputs = inputs,
            output = output,
            apple_platform_info = apple_platform_info,
            xcode_config = xcode_config,
        )
    else:
        # Symlink if there was only a single architecture created; it's faster.
        actions.symlink(target_file = inputs[0], output = output)

def _apple_universal_binary_impl(ctx):
    inputs = [
        binary.files.to_list()[0]
        for binary in ctx.split_attr.binary.values()
    ]

    if not inputs:
        fail("Target (%s) `binary` label ('%s') does not provide any " +
             "file for universal binary" % (ctx.attr.name, ctx.attr.binary))

    universal_binary = ctx.actions.declare_file(ctx.label.name)

    apple_platform_info = apple_support.platform_info_from_rule_ctx(ctx)

    _lipo_or_symlink_inputs(
        actions = ctx.actions,
        inputs = inputs,
        output = universal_binary,
        apple_platform_info = apple_platform_info,
        xcode_config = ctx.attr._xcode_config[XcodeVersionInfo],
    )

    # The apple_universal_binary doesn't have its own `data` attribute, so there's no runfiles to
    # collect from itself.
    runfiles = ctx.runfiles()
    transitive_runfiles = [
        target[DefaultInfo].default_runfiles
        for target in ctx.split_attr.binary.values()
    ]
    runfiles = runfiles.merge_all(transitive_runfiles)

    return [
        new_applebinaryinfo(
            archs = sorted(ctx.attr.forced_cpus),
            binary = universal_binary,
            platform_type = apple_support.target_os_from_rule_ctx(ctx),
            target_environment = apple_support.target_environment_from_rule_ctx(ctx),
        ),
        DefaultInfo(
            executable = universal_binary,
            files = depset([universal_binary]),
            runfiles = runfiles,
        ),
    ]

_common_attrs = apple_support.action_required_attrs() | {
}

_platform_attrs = {
    "minimum_os_version": attr.string(
        doc = """
A required string indicating the minimum OS version supported by the target, represented as a
dotted version number (for example, "9.0").
""",
        mandatory = True,
    ),
    "platform_type": attr.string(
        doc = """
The target Apple platform for which to create a binary. This dictates which SDK
is used for compilation/linking and which flag is used to determine the
architectures to target. For example, if `ios` is specified, then the output
binaries/libraries will be created combining all architectures specified by
`--ios_multi_cpus`. Options are:

*   `ios`: architectures gathered from `--ios_multi_cpus`.
*   `macos`: architectures gathered from `--macos_cpus`.
*   `tvos`: architectures gathered from `--tvos_cpus`.
*   `watchos`: architectures gathered from `--watchos_cpus`.
""",
        mandatory = True,
    ),
}

apple_universal_binary = rule(
    implementation = _apple_universal_binary_impl,
    attrs = _common_attrs | _platform_attrs | apple_support.platform_constraint_attrs() | {
        "binary": attr.label(
            mandatory = True,
            cfg = transition_support.apple_platform_split_transition,
            doc = "Target to generate a universal binary from.",
        ),
        "forced_cpus": attr.string_list(
            mandatory = False,
            allow_empty = True,
            doc = """
An optional list of target CPUs for which the universal binary should be built.

If this attribute is present, the value of the platform-specific CPU flag (`--ios_multi_cpus`,
`--macos_cpus`, `--tvos_cpus`, `--visionos_cpus`, or `--watchos_cpus`) will be ignored and the
binary will be built for all of the specified architectures instead.

This is primarily useful to force macOS tools to be built as universal binaries using
`forced_cpus = ["x86_64", "arm64"]`, without requiring the user to pass additional flags when
invoking Bazel.
""",
        ),
        "_building_apple_bundle": attr.bool(
            default = False,
            doc = """
Internal attribute read by Apple rule transitions to set the
`building_apple_bundle` build setting.
""",
        ),
    },
    cfg = transition_support.apple_universal_binary_rule_transition,
    doc = """
This rule produces a multi-architecture (universal) binary targeting Apple
platforms. The `lipo` tool is used to combine built binaries of multiple
architectures.
""",
    executable = True,
)
