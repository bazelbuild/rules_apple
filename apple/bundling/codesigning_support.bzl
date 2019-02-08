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
# limitations under the License.

"""Functions related to code signing of Apple bundles."""

load(
    "@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:defines.bzl",
    "defines",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_support.bzl",
    "rule_support",
)
load(
    "@bazel_skylib//lib:shell.bzl",
    "shell",
)

def _codesign_command(ctx, path_to_sign, provisioning_profile, entitlements_file):
    """Returns a single `codesign` command invocation.

    Args:
      ctx: The Skylark context.
      path_to_sign: A struct indicating the path that should be signed and its
          optionality (see `_path_to_sign`).
      entitlements_file: The entitlements file to pass to codesign. May be `None`
          for non-app binaries (e.g. test bundles).

    Returns:
      The codesign command invocation for the given directory.
    """

    # Because the path will include environment # variables which need to be
    # expanded, path has to be quoted using double quote, this means that path
    # can't be quoted using shell.quote.
    path = "\"" + path_to_sign.path.replace("\"", "\\\"") + "\""
    if path_to_sign.glob:
        # The glob must be appended outside of the quotes in order to be expanded.
        path += path_to_sign.glob
    cmd_prefix = ""

    if path_to_sign.optional:
        cmd_prefix += "ls %s >& /dev/null && " % path

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
            path,
        ])
    else:
        cmd_codesigning.extend([
            "--force",
            "--timestamp=none",
            path,
        ])

    # The command returned by this function is executed as part of the final
    # bundling shell script. Each directory to be signed must be prefixed by
    # $WORK_DIR, which is the variable in that script that contains the path
    # to the directory where the bundle is being built.
    return (cmd_prefix + " ".join(cmd_codesigning))

def _path_to_sign(path, optional = False, glob = None, use_entitlements = True):
    """Returns a "path to sign" value to be passed to `signing_command_lines`.

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

    Returns:
      A `struct` that can be passed to `signing_command_lines`.
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

    # First, try to use the identity passed on the command line, if any. If it's
    # a simulator build, use an ad hoc identity.
    identity = ctx.fragments.objc.signing_certificate_name if is_device else "-"

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
        commands.append(_codesign_command(
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

# Define the loadable module that lists the exported symbols in this file.
codesigning_support = struct(
    path_to_sign = _path_to_sign,
    should_sign_simulator_bundles = _should_sign_simulator_bundles,
    signing_command_lines = _signing_command_lines,
)
