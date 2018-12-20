# Copyright 2017 The Bazel Authors. All rights reserved.
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

"""Rule implementations for creating macOS applications and bundles.

DO NOT load this file directly; use the macro in
@build_bazel_rules_apple//apple:macos.bzl instead. Bazel rules receive their name at
*definition* time based on the name of the global to which they are assigned.
We want the user to call macros that have the same name, to get automatic
binary creation, entitlements support, and other features--which requires a
wrapping macro because rules cannot invoke other rules.
"""

load(
    "@build_bazel_rules_apple//apple/bundling:codesigning_support.bzl",
    "codesigning_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:debug_symbol_actions.bzl",
    "debug_symbol_actions",
)
load(
    "@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:rule_factory.bzl",
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

def _macos_command_line_application_impl(ctx):
    """Implementation of the macos_command_line_application rule."""
    output_file = ctx.actions.declare_file(ctx.label.name)

    outputs = []

    debug_outputs = ctx.attr.binary[apple_common.AppleDebugOutputs]
    if debug_outputs:
        # Create a .dSYM bundle with the expected name next to the binary in the
        # output directory.
        if ctx.fragments.objc.generate_dsym:
            symbol_bundle = debug_symbol_actions.create_symbol_bundle(
                ctx,
                debug_outputs,
                ctx.label.name,
            )
            outputs.extend(symbol_bundle)

        if ctx.fragments.objc.generate_linkmap:
            linkmaps = debug_symbol_actions.collect_linkmaps(
                ctx,
                debug_outputs,
                ctx.label.name,
            )
            outputs.extend(linkmaps)

    # It's not hermetic to sign the binary that was built by the apple_binary
    # target that this rule takes as an input, so we copy it and then execute the
    # code signing commands on that copy in the same action.
    path_to_sign = codesigning_support.path_to_sign(output_file.path)
    signing_commands = codesigning_support.signing_command_lines(
        ctx,
        [path_to_sign],
        None,
    )

    inputs = [ctx.file.binary]

    platform_support.xcode_env_action(
        ctx,
        inputs = inputs,
        outputs = [output_file],
        command = [
            "/bin/bash",
            "-c",
            "cp {input_binary} {output_binary}".format(
                input_binary = ctx.file.binary.path,
                output_binary = output_file.path,
            ) + "\n" + signing_commands,
        ],
        mnemonic = "SignBinary",
    )

    outputs.append(output_file)
    return [
        DefaultInfo(
            executable = output_file,
            files = depset(direct = outputs),
        ),
    ]

macos_command_line_application = rule(
    _macos_command_line_application_impl,
    attrs = dicts.add(
        rule_factory.common_tool_attributes,
        rule_factory.code_signing_attributes(
            rule_factory.code_signing(
                ".provisionprofile",
                requires_signing_for_device = False,
            ),
        ),
        {
            # TODO(b/73292865): Replace "binary" with "deps" when Tulsi
            # migrates off of "binary".
            "binary": attr.label(
                mandatory = True,
                providers = [apple_common.AppleExecutableBinary],
                allow_single_file = True,
            ),
            "bundle_id": attr.string(mandatory = False),
            "infoplists": attr.label_list(
                allow_files = [".plist"],
                mandatory = False,
            ),
            "launchdplists": attr.label_list(
                allow_files = [".plist"],
                mandatory = False,
            ),
            "minimum_os_version": attr.string(mandatory = False),
            "version": attr.label(providers = [[AppleBundleVersionInfo]]),
            "_platform_type": attr.string(
                default = str(apple_common.platform_type.macos),
            ),
        },
    ),
    executable = True,
    fragments = ["apple", "objc"],
)

def _macos_dylib_impl(ctx):
    """Implementation of the macos_dylib rule."""
    output_file = ctx.actions.declare_file(ctx.label.name + ".dylib")

    outputs = []

    debug_outputs = ctx.attr.binary[apple_common.AppleDebugOutputs]
    if debug_outputs:
        # Create a .dSYM bundle with the expected name next to the binary in the
        # output directory.
        if ctx.fragments.objc.generate_dsym:
            symbol_bundle = debug_symbol_actions.create_symbol_bundle(
                ctx,
                debug_outputs,
                ctx.label.name,
            )
            outputs.extend(symbol_bundle)

        if ctx.fragments.objc.generate_linkmap:
            linkmaps = debug_symbol_actions.collect_linkmaps(
                ctx,
                debug_outputs,
                ctx.label.name,
            )
            outputs.extend(linkmaps)

    # It's not hermetic to sign the binary that was built by the apple_binary
    # target that this rule takes as an input, so we copy it and then execute the
    # code signing commands on that copy in the same action.
    path_to_sign = codesigning_support.path_to_sign(output_file.path)
    signing_commands = codesigning_support.signing_command_lines(
        ctx,
        [path_to_sign],
        None,
    )

    inputs = [ctx.file.binary]

    platform_support.xcode_env_action(
        ctx,
        inputs = inputs,
        outputs = [output_file],
        command = [
            "/bin/bash",
            "-c",
            "cp {input_binary} {output_binary}".format(
                input_binary = ctx.file.binary.path,
                output_binary = output_file.path,
            ) + "\n" + signing_commands,
        ],
        mnemonic = "SignBinary",
    )

    outputs.append(output_file)
    return [
        DefaultInfo(
            executable = output_file,
            files = depset(direct = outputs),
        ),
    ]

macos_dylib = rule(
    _macos_dylib_impl,
    attrs = dicts.add(
        rule_factory.common_tool_attributes,
        rule_factory.code_signing_attributes(
            rule_factory.code_signing(
                ".provisionprofile",
                requires_signing_for_device = False,
            ),
        ),
        {
            # TODO(b/73292865): Replace "binary" with "deps" when Tulsi
            # migrates off of "binary".
            "binary": attr.label(
                mandatory = True,
                providers = [apple_common.AppleDylibBinary],
                allow_single_file = True,
            ),
            "bundle_id": attr.string(mandatory = False),
            "infoplists": attr.label_list(
                allow_files = [".plist"],
                mandatory = False,
                allow_empty = True,
            ),
            "minimum_os_version": attr.string(mandatory = False),
            "version": attr.label(providers = [[AppleBundleVersionInfo]]),
            "_platform_type": attr.string(
                default = str(apple_common.platform_type.macos),
            ),
        },
    ),
    executable = False,
    fragments = ["apple", "objc"],
)
