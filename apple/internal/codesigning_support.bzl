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
    "@build_bazel_rules_apple//apple/internal/utils:defines.bzl",
    "defines",
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
    "@build_bazel_rules_apple//apple/internal:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_support.bzl",
    "rule_support",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@bazel_skylib//lib:shell.bzl",
    "shell",
)

def _codesign_command_for_path(ctx, path_to_sign, provisioning_profile, entitlements_file):
    """Returns a single `codesign` command invocation.

    Args:
      ctx: The Skylark context.
      path_to_sign: A struct indicating the path that should be signed and its
          optionality (see `_path_to_sign`).
      provisioning_profile: The provisioning profile file. May be `None`.
      entitlements_file: The entitlements file to pass to codesign. May be `None`
          for non-app binaries (e.g. test bundles).

    Returns:
      The codesign command invocation for the given directory.
    """

    # Because the path will include environment variables which need to be expanded, path has to be
    # quoted using double quote, this means that path can't be quoted using shell.quote.
    path = "\"" + path_to_sign.path.replace("\"", "\\\"") + "\""
    if path_to_sign.glob:
        # The glob must be appended outside of the quotes in order to be expanded.
        full_path_to_sign = path + path_to_sign.glob
    else:
        full_path_to_sign = path

    cmd_codesigning = [
        ctx.executable._codesigningtool.path,
        "--codesign",
        "/usr/bin/codesign",
    ]

    is_device = platform_support.is_device_build(ctx)

    # First, try to use the identity passed on the command line, if any. If it's
    # a simulator build, use an ad hoc identity.
    identity = ctx.fragments.objc.signing_certificate_name if is_device else "-"
    if not identity:
        if provisioning_profile:
            cmd_codesigning.extend([
                "--mobileprovision",
                shell.quote(provisioning_profile.path),
            ])
        else:
            identity = "-"

    if identity:
        cmd_codesigning.extend(["--identity", shell.quote(identity)])

    if is_device:
        if path_to_sign.use_entitlements and entitlements_file:
            cmd_codesigning.extend([
                "--entitlements",
                shell.quote(entitlements_file.path),
            ])
        cmd_codesigning.extend([
            "--force",
            full_path_to_sign,
        ])
    else:
        cmd_codesigning.extend([
            "--force",
            "--timestamp=none",
            full_path_to_sign,
        ])

    final_command = " ".join(cmd_codesigning)

    # If the path is optional, wrap it inside an `if` that checks whether that path exists. This way
    # the command will not return a non-zero exit code if the directory not exists.
    if path_to_sign.optional:
        final_command = "if [[ -e {path_to_sign} ]]; then\n  {codesign_command}\nfi".format(
            path_to_sign = path,
            codesign_command = final_command,
        )

    # The command returned by this function is executed as part of the final bundling shell script.
    # Each directory to be signed must be prefixed by $WORK_DIR, which is the variable in that
    # script that contains the path to the directory where the bundle is being built.
    return final_command

def _path_to_sign(path, optional = False, glob = None, use_entitlements = True):
    """Returns a "path to sign" value to be passed to `_signing_command_lines`.

    Args:
      path: The path to sign, relative to wherever the code signing command lines
          are being executed. For example, with bundle signing these paths are
          prefixed with a `$WORK_DIR` environment variable that points to the
          location where the bundle is being constructed, but for simple binary
          signing it is the path to the binary itself.
      optional: If `True`, the path is an optional path that is ignored if it does
          not exist. This is used to handle Frameworks directories cleanly since
          they may or may not be present in the bundle.
      glob: If provided, this is a glob string to append to the path when calling
          the signing tool.
      use_entitlements: If provided, indicates if the entitlements on the bundling
          target should be used for signing this path (useful to disabled the use
          when signing frameworks within an iOS app).

    Returns:
      A `struct` that can be passed to `_signing_command_lines`.
    """
    return struct(
        path = path,
        optional = optional,
        glob = glob,
        use_entitlements = use_entitlements,
    )

def _signing_command_lines(
        ctx,
        paths_to_sign,
        entitlements_file):
    """Returns a multi-line string with codesign invocations for the bundle.

    For any signing identity other than ad hoc, the identity is verified as being
    valid in the keychain and an error will be emitted if the identity cannot be
    used for signing for any reason.

    Args:
      ctx: The Skylark context.
      paths_to_sign: A list of values returned from `path_to_sign` that indicate
          paths that should be code-signed.
      entitlements_file: The entitlements file to pass to codesign.

    Returns:
      A multi-line string with codesign invocations for the bundle.
    """
    commands = []

    # Verify that a provisioning profile was provided for device builds on
    # platforms that require it.
    is_device = platform_support.is_device_build(ctx)
    provisioning_profile = getattr(ctx.file, "provisioning_profile", None)
    rule_descriptor = rule_support.rule_descriptor(ctx)
    if (is_device and
        rule_descriptor.requires_signing_for_device and
        not provisioning_profile):
        fail("The provisioning_profile attribute must be set for device " +
             "builds on this platform (%s)." %
             platform_support.platform_type(ctx))

    # Just like Xcode, ensure CODESIGN_ALLOCATE is set to point to the correct
    # version. DEVELOPER_DIR will already be set on the action that invokes
    # the script. Without this, codesign should already be using DEVELOPER_DIR
    # to find things, but this should get the rules slightly closer on behaviors.
    # apple_common.apple_toolchain().developer_dir() won't work here because
    # usage relies on the expansion done in the xcrunwrapper, and the individual
    # signing commands don't bounce through xcrun (and don't need to).
    commands.append(
        ("export CODESIGN_ALLOCATE=${DEVELOPER_DIR}/" +
         "Toolchains/XcodeDefault.xctoolchain/usr/bin/codesign_allocate"),
    )

    for path_to_sign in paths_to_sign:
        commands.append(_codesign_command_for_path(
            ctx,
            path_to_sign,
            provisioning_profile,
            entitlements_file,
        ))
    return "\n".join(commands)

def _should_sign_simulator_bundles(ctx):
    """Check if a main bundle should be codesigned.

    The Frameworks/* bundles should *always* be signed, this is just for
    the other bundles.

    Args:
      ctx: The Skylark context.

    Returns:
      True/False for if the bundle should be signed.

    """
    rule_descriptor = rule_support.rule_descriptor(ctx)
    if not rule_descriptor.skip_simulator_signing_allowed:
        return True

    # Default is to sign.
    return defines.bool_value(
        ctx,
        "apple.codesign_simulator_bundles",
        True,
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
            _path_to_sign(
                paths.join("$WORK_DIR", frameworks_path) + "/",
                optional = True,
                glob = "*",
                use_entitlements = False,
            ),
        ]
        is_device = platform_support.is_device_build(ctx)
        if is_device or _should_sign_simulator_bundles(ctx):
            paths_to_sign.append(
                _path_to_sign(paths.join("$WORK_DIR", bundle_path)),
            )
        signing_command_lines = _signing_command_lines(
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

    # Only compress the IPA for optimized (release) builds or when requested.
    # For debug builds, zip without compression, which will speed up the build.
    compression_requested = defines.bool_value(ctx, "apple.compress_ipa", False)
    should_compress = (ctx.var["COMPILATION_MODE"] == "opt") or compression_requested

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
    path_to_sign = _path_to_sign(output_binary.path)
    signing_commands = _signing_command_lines(
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

codesigning_support = struct(
    codesigning_command = _codesigning_command,
    post_process_and_sign_archive_action = _post_process_and_sign_archive_action,
    sign_binary_action = _sign_binary_action,
)
