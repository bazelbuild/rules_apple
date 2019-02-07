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
# limitations under the License.

"""Actions related to codesigning."""

load(
    "@build_bazel_rules_apple//apple/bundling:codesigning_support.bzl",
    "codesigning_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:legacy_actions.bzl",
    "legacy_actions",
)
load(
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_support.bzl",
    "rule_support",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

def _codesigning_command(ctx, entitlements, frameworks_path, bundle_path = ""):
    """Returns a codesigning command that includes framework embedded bundles.

    Args:
        ctx: The rule context.
        entitlements: The entitlements file to sign with. Can be None.
        frameworks_path: The location of the Frameworks directory, relative to the archive.
        bundle_path: The location of the bundle, relative to the archive.

    Returns:
        A string containing the codesigning commands.
    """
    rule_descriptor = rule_support.rule_descriptor(ctx)
    signing_command_lines = ""
    if not rule_descriptor.skip_signing:
        paths_to_sign = [
            codesigning_support.path_to_sign(
                paths.join("$WORK_DIR", frameworks_path) + "/",
                optional = True,
                glob = "*",
                use_entitlements = False,
            ),
        ]
        is_device = platform_support.is_device_build(ctx)
        if is_device or codesigning_support.should_sign_simulator_bundles(ctx):
            paths_to_sign.append(
                codesigning_support.path_to_sign(paths.join("$WORK_DIR", bundle_path)),
            )
        signing_command_lines = codesigning_support.signing_command_lines(
            ctx,
            paths_to_sign,
            entitlements,
        )

    return signing_command_lines

def _post_process_and_sign_archive_action(
        ctx,
        archive_codesigning_path,
        frameworks_path,
        input_archive,
        output_archive,
        output_archive_root_path,
        entitlements = None):
    """Post-processes and signs an archived bundle.

    Args:
      ctx: The target's rule context.
      archive_codesigning_path: The codesigning path relative to the archive.
      frameworks_path: The Frameworks path relative to the archive.
      input_archive: The `File` representing the archive containing the bundle
          that has not yet been processed or signed.
      output_archive: The `File` representing the processed and signed archive.
      output_archive_root_path: The `string` path to where the processed, uncompressed archive
          should be located.
      entitlements: Optional file representing the entitlements to sign with.
    """
    input_files = [input_archive]

    if entitlements:
        input_files.append(entitlements)

    provisioning_profile = getattr(ctx.file, "provisioning_profile", None)
    if provisioning_profile:
        input_files.append(provisioning_profile)

    signing_command_lines = _codesigning_command(
        ctx,
        entitlements,
        frameworks_path,
        bundle_path = archive_codesigning_path,
    )

    processing_tools = [ctx.executable._codesigningtool]

    ipa_post_processor = ctx.executable.ipa_post_processor
    ipa_post_processor_path = ""
    if ipa_post_processor:
        processing_tools.append(ipa_post_processor)
        ipa_post_processor_path = ipa_post_processor.path

    # Only compress the IPA for optimized (release) builds. For debug builds,
    # zip without compression, which will speed up the build.
    should_compress = (ctx.var["COMPILATION_MODE"] == "opt")

    process_and_sign_template = intermediates.file(
        ctx.actions,
        ctx.label.name,
        "process-and-sign.sh",
    )
    ctx.actions.expand_template(
        template = ctx.file._process_and_sign_template,
        output = process_and_sign_template,
        is_executable = True,
        substitutions = {
            "%ipa_post_processor%": ipa_post_processor_path or "",
            "%output_path%": output_archive.path,
            "%should_compress%": "1" if should_compress else "",
            "%signing_command_lines%": signing_command_lines,
            "%unprocessed_archive_path%": input_archive.path,
            "%work_dir%": output_archive_root_path,
        },
    )

    legacy_actions.run(
        ctx,
        inputs = input_files,
        outputs = [output_archive],
        executable = process_and_sign_template,
        mnemonic = "ProcessAndSign",
        progress_message = "Processing and signing %s" % ctx.label.name,
        execution_requirements = {
            # Added so that the output of this action is not cached remotely, in case multiple
            # developers sign the same artifact with different identities.
            "no-cache": "1",
            # Unsure, but may be needed for keychain access, especially for files that live in
            # $HOME.
            "no-sandbox": "1",
        },
        tools = processing_tools,
    )

def _sign_binary_action(ctx, input_binary, output_binary):
    """Signs the input binary file, copying it into the given output binary file.

    Args:
      ctx: The target's rule context.
      input_binary: The `File` representing the binary to be signed.
      output_binary: The `File` representing signed binary.
    """

    # It's not hermetic to sign the binary that was built by the apple_binary
    # target that this rule takes as an input, so we copy it and then execute the
    # code signing commands on that copy in the same action.
    path_to_sign = codesigning_support.path_to_sign(output_binary.path)
    signing_commands = codesigning_support.signing_command_lines(
        ctx,
        [path_to_sign],
        None,
    )

    legacy_actions.run_shell(
        ctx,
        inputs = [input_binary],
        outputs = [output_binary],
        command = [
            "/bin/bash",
            "-c",
            "cp {input_binary} {output_binary}".format(
                input_binary = input_binary.path,
                output_binary = output_binary.path,
            ) + "\n" + signing_commands,
        ],
        mnemonic = "SignBinary",
        execution_requirements = {
            # Added so that the output of this action is not cached remotely, in case multiple
            # developers sign the same artifact with different identities.
            "no-cache": "1",
            # Unsure, but may be needed for keychain access, especially for files that live in
            # $HOME.
            "no-sandbox": "1",
        },
        tools = [
            ctx.executable._codesigningtool,
        ],
    )

codesigning_actions = struct(
    codesigning_command = _codesigning_command,
    post_process_and_sign_archive_action = _post_process_and_sign_archive_action,
    sign_binary_action = _sign_binary_action,
)
