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

def _double_quote(raw_string):
    """Add double quotes around the string and preserve existing quote characters.

    Args:
      raw_string: A string that might have shell-syntaxed environment variables.

    Returns:
      The string with double quotes.
    """
    return "\"" + raw_string.replace("\"", "\\\"") + "\""

def _no_op(x):
    """Helper that does not nothing be return the result."""
    return x

def _codesign_args_for_path(
        ctx,
        path_to_sign,
        provisioning_profile,
        entitlements_file,
        shell_quote = True):
    """Returns a command line for the codesigning tool wrapper script.

    Args:
      ctx: The Starlark context.
      path_to_sign: A struct indicating the path that should be signed and its
          optionality (see `_path_to_sign`).
      provisioning_profile: The provisioning profile file. May be `None`.
      entitlements_file: The entitlements file to pass to codesign. May be `None`
          for non-app binaries (e.g. test bundles).
      shell_quote: Sanitizes the arguments to be evaluated in a shell.

    Returns:
      The codesign command invocation for the given directory as a list.
    """
    if not path_to_sign.is_directory and path_to_sign.signed_frameworks:
        fail("Internal Error: Received a list of signed frameworks as exceptions " +
             "for code signing, but path to sign is not a directory.")

    for x in path_to_sign.signed_frameworks:
        if not x.startswith(path_to_sign.path):
            fail("Internal Error: Signed framework does not have the current path " +
                 "to sign (%s) as its prefix (%s)." % (path_to_sign.path, x))

    cmd_codesigning = [
        "--codesign",
        "/usr/bin/codesign",
    ]

    is_device = platform_support.is_device_build(ctx)

    # Add quotes for sanitizing inputs when they're invoked directly from a shell script, for
    # instance when using this string to assemble the output of codesigning_command.
    maybe_quote = shell.quote if shell_quote else _no_op
    maybe_double_quote = _double_quote if shell_quote else _no_op

    # First, try to use the identity passed on the command line, if any. If it's a simulator build,
    # use an ad hoc identity.
    identity = ctx.fragments.objc.signing_certificate_name if is_device else "-"
    if not identity:
        if provisioning_profile:
            cmd_codesigning.extend([
                "--mobileprovision",
                maybe_quote(provisioning_profile.path),
            ])

        else:
            identity = "-"

    if identity:
        cmd_codesigning.extend([
            "--identity",
            maybe_quote(identity),
        ])

    # The entitlements rule ensures that entitlements_file is None or a file
    # containing only "com.apple.security.get-task-allow" when building for the
    # simulator.
    if path_to_sign.use_entitlements and entitlements_file:
        cmd_codesigning.extend([
            "--entitlements",
            maybe_quote(entitlements_file.path),
        ])

    if is_device:
        cmd_codesigning.append("--force")
    else:
        cmd_codesigning.extend([
            "--force",
            "--disable_timestamp",
        ])

    if path_to_sign.is_directory:
        cmd_codesigning.append("--directory_to_sign")
    else:
        cmd_codesigning.append("--target_to_sign")

    # Because the path does include environment variables which need to be expanded, path has to be
    # quoted using double quotes, this means that path can't be quoted using shell.quote.
    cmd_codesigning.append(maybe_double_quote(path_to_sign.path))

    if path_to_sign.signed_frameworks:
        for signed_framework in path_to_sign.signed_frameworks:
            # Signed frameworks must also be double quoted, as they too have an environment
            # variable to be expanded.
            cmd_codesigning.extend([
                "--signed_path",
                maybe_double_quote(signed_framework),
            ])

    extra_opts_raw = getattr(ctx.attr, "codesignopts", [])
    extra_opts = [ctx.expand_make_variables("codesignopts", opt, {}) for opt in extra_opts_raw]
    cmd_codesigning.append("--")
    cmd_codesigning.extend(extra_opts)
    return cmd_codesigning

def _path_to_sign(path, is_directory = False, signed_frameworks = [], use_entitlements = True):
    """Returns a "path to sign" value to be passed to `_signing_command_lines`.

    Args:
      path: The path to sign, relative to wherever the code signing command lines
          are being executed.
      is_directory: If `True`, the path is a directory and not a bundle, indicating
          that the contents of each item in the directory should be code signed
          except for the invisible files prefixed with a period.
      signed_frameworks: If provided, a list of frameworks that have already been signed.
      use_entitlements: If provided, indicates if the entitlements on the bundling
          target should be used for signing this path (useful to disabled the use
          when signing frameworks within an iOS app).

    Returns:
      A `struct` that can be passed to `_signing_command_lines`.
    """
    return struct(
        path = path,
        is_directory = is_directory,
        signed_frameworks = signed_frameworks,
        use_entitlements = use_entitlements,
    )

def _provisioning_profile(ctx):
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
    return provisioning_profile

def _signing_command_lines(
        ctx,
        paths_to_sign,
        entitlements_file):
    """Returns a multi-line string with codesign invocations for the bundle.

    For any signing identity other than ad hoc, the identity is verified as being
    valid in the keychain and an error will be emitted if the identity cannot be
    used for signing for any reason.

    Args:
      ctx: The Starlark context.
      paths_to_sign: A list of values returned from `path_to_sign` that indicate
          paths that should be code-signed.
      entitlements_file: The entitlements file to pass to codesign.

    Returns:
      A multi-line string with codesign invocations for the bundle.
    """
    provisioning_profile = _provisioning_profile(ctx)

    commands = []

    # Use of the entitlements file is not recommended for the signing of frameworks. As long as
    # this remains the case, we do have to split the "paths to sign" between multiple invocations
    # of codesign.
    for path_to_sign in paths_to_sign:
        codesign_command = [ctx.executable._codesigningtool.path]
        codesign_command.extend(_codesign_args_for_path(
            ctx,
            path_to_sign,
            provisioning_profile,
            entitlements_file,
        ))
        commands.append(" ".join(codesign_command))
    return "\n".join(commands)

def _should_sign_simulator_bundles(ctx):
    """Check if a main bundle should be codesigned.

    The Frameworks/* bundles should *always* be signed, this is just for
    the other bundles.

    Args:
      ctx: The Starlark context.

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

def _should_sign_bundles(ctx):
    should_sign_bundles = True

    rule_descriptor = rule_support.rule_descriptor(ctx)
    codesigning_exceptions = rule_descriptor.codesigning_exceptions
    if (codesigning_exceptions ==
        rule_support.codesigning_exceptions.sign_with_provisioning_profile):
        # If the rule doesn't have a provisioning profile, do not sign the binary or its
        # frameworks.
        provisioning_profile = getattr(ctx.file, "provisioning_profile", None)
        if not provisioning_profile:
            should_sign_bundles = False
    elif codesigning_exceptions == rule_support.codesigning_exceptions.skip_signing:
        should_sign_bundles = False
    elif codesigning_exceptions != rule_support.codesigning_exceptions.none:
        fail("Internal Error: Encountered unsupported state for codesigning_exceptions.")

    return should_sign_bundles

def _codesigning_args(
        ctx,
        entitlements,
        full_archive_path,
        is_framework = False):
    """Returns a set of codesigning arguments to be passed to the codesigning tool.

    Args:
        ctx: The rule context.
        entitlements: The entitlements file to sign with. Can be None.
        full_archive_path: The full path to the codesigning target.
        is_framework: If the target is a framework. False by default.

    Returns:
        A list containing the arguments to pass to the codesigning tool.
    """
    if not _should_sign_bundles(ctx):
        return []

    is_device = platform_support.is_device_build(ctx)
    if not is_framework and not is_device and not _should_sign_simulator_bundles(ctx):
        return []

    return _codesign_args_for_path(
        ctx,
        _path_to_sign(full_archive_path),
        provisioning_profile = _provisioning_profile(ctx),
        entitlements_file = entitlements,
        shell_quote = False,
    )

def _codesigning_command(
        ctx,
        entitlements,
        frameworks_path,
        signed_frameworks,
        bundle_path = ""):
    """Returns a codesigning command that includes framework embedded bundles.

    Args:
        ctx: The rule context.
        entitlements: The entitlements file to sign with. Can be None.
        frameworks_path: The location of the Frameworks directory, relative to the archive.
        signed_frameworks: A depset containing each framework that has already been signed.
        bundle_path: The location of the bundle, relative to the archive.

    Returns:
        A string containing the codesigning commands.
    """
    if not _should_sign_bundles(ctx):
        return ""

    paths_to_sign = []

    # The command returned by this function is executed as part of a bundling shell script.
    # Each directory to be signed must be prefixed by $WORK_DIR, which is the variable in that
    # script that contains the path to the directory where the bundle is being built.
    if frameworks_path:
        framework_root = paths.join("$WORK_DIR", frameworks_path) + "/"
        full_signed_frameworks = []

        for signed_framework in signed_frameworks.to_list():
            full_signed_frameworks.append(paths.join(framework_root, signed_framework))

        paths_to_sign.append(
            _path_to_sign(
                framework_root,
                is_directory = True,
                signed_frameworks = full_signed_frameworks,
                use_entitlements = False,
            ),
        )

    is_device = platform_support.is_device_build(ctx)
    if is_device or _should_sign_simulator_bundles(ctx):
        path_to_sign = paths.join("$WORK_DIR", bundle_path)
        paths_to_sign.append(
            _path_to_sign(path_to_sign),
        )
    return _signing_command_lines(
        ctx,
        paths_to_sign = paths_to_sign,
        entitlements_file = entitlements,
    )

def _post_process_and_sign_archive_action(
        ctx,
        archive_codesigning_path,
        frameworks_path,
        input_archive,
        output_archive,
        output_archive_root_path,
        signed_frameworks,
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
      signed_frameworks: Depset containing each framework that has already been signed.
      entitlements: Optional file representing the entitlements to sign with.
    """
    input_files = [input_archive]
    processing_tools = []

    signing_command_lines = _codesigning_command(
        ctx,
        entitlements,
        frameworks_path,
        signed_frameworks,
        bundle_path = archive_codesigning_path,
    )
    if signing_command_lines:
        processing_tools.append(ctx.executable._codesigningtool)
        if entitlements:
            input_files.append(entitlements)
        provisioning_profile = getattr(ctx.file, "provisioning_profile", None)
        if provisioning_profile:
            input_files.append(provisioning_profile)

    ipa_post_processor = ctx.executable.ipa_post_processor
    ipa_post_processor_path = ""
    if ipa_post_processor:
        processing_tools.append(ipa_post_processor)
        ipa_post_processor_path = ipa_post_processor.path

    # Only compress the IPA for optimized (release) builds or when requested.
    # For debug builds, zip without compression, which will speed up the build.
    compression_requested = defines.bool_value(ctx, "apple.compress_ipa", False)
    should_compress = (ctx.var["COMPILATION_MODE"] == "opt") or compression_requested

    # TODO(b/163217926): These are kept the same for the three different actions
    # that could be run to ensure anything keying off these values continues to
    # work. After some data is collected, the values likely can be revisited and
    # changed.
    mnemonic = "ProcessAndSign"
    progress_message = "Processing and signing %s" % ctx.label.name

    # If there is no work to be done, skip the processing/signing action, just
    # copy the file over.
    has_work = any([signing_command_lines, ipa_post_processor_path, should_compress])
    if not has_work:
        ctx.actions.run_shell(
            inputs = [input_archive],
            outputs = [output_archive],
            mnemonic = mnemonic,
            progress_message = progress_message,
            command = "cp -p '%s' '%s'" % (input_archive.path, output_archive.path),
        )
        return

    process_and_sign_template = intermediates.file(
        ctx.actions,
        ctx.label.name,
        "process-and-sign-%s.sh" % hash(output_archive.path),
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

    # Build up some arguments for the script to allow logging to tell what work
    # is being done within the action's script.
    arguments = []
    if signing_command_lines:
        arguments.append("should_sign")
    if ipa_post_processor_path:
        arguments.append("should_process")
    if should_compress:
        arguments.append("should_compress")

    run_on_darwin = any([signing_command_lines, ipa_post_processor_path])
    if run_on_darwin:
        legacy_actions.run(
            ctx,
            inputs = input_files,
            outputs = [output_archive],
            executable = process_and_sign_template,
            arguments = arguments,
            mnemonic = mnemonic,
            progress_message = progress_message,
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
    else:
        ctx.actions.run(
            inputs = input_files,
            outputs = [output_archive],
            executable = process_and_sign_template,
            arguments = arguments,
            mnemonic = mnemonic,
            progress_message = progress_message,
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
        command = "cp {input_binary} {output_binary}".format(
            input_binary = input_binary.path,
            output_binary = output_binary.path,
        ) + "\n" + signing_commands,
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
    codesigning_args = _codesigning_args,
    codesigning_command = _codesigning_command,
    post_process_and_sign_archive_action = _post_process_and_sign_archive_action,
    provisioning_profile = _provisioning_profile,
    sign_binary_action = _sign_binary_action,
)
