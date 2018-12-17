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
    "@build_bazel_rules_apple//apple/bundling:mock_support.bzl",
    "mock_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//common:define_utils.bzl",
    "define_utils",
)
load(
    "@bazel_skylib//lib:shell.bzl",
    "shell",
)

def _extract_provisioning_plist_command(ctx, provisioning_profile):
    """Returns the shell command to extract a plist from a provisioning profile.

    Args:
      ctx: The Skylark context.
      provisioning_profile: The `File` representing the provisioning profile.

    Returns:
      The shell command used to extract the plist.
    """
    if mock_support.is_provisioning_mocked(ctx):
        # If provisioning is mocked, treat the provisioning profile as a plain XML
        # plist without a signature.
        return "cat " + shell.quote(provisioning_profile.path)
    else:
        # NOTE: Until the bundling rules are updated to merge entitlements support
        # and signing, this extraction command should be kept in sync with what
        # exists in provisioning_profile_tool.
        #
        # Use a fallback mechanism to call first the security command and if that
        # fails (e.g. when running in El Capitan) call the openssl command.
        # The whole output for that fallback command group is then rerouted to
        # STDERR which is only printed if the command actually failed (security and
        # openssl print information into stderr even if the command succeeded).
        profile_path = shell.quote(provisioning_profile.path)
        extract_plist_cmd = (
            "(security cms -D -i %s || " % profile_path +
            "openssl smime -inform der -verify -noverify -in %s)" % profile_path
        )
        return ("( " +
                "STDERR=$(mktemp -t openssl.stderr) && " +
                "trap \"rm -f ${STDERR}\" EXIT && " +
                extract_plist_cmd + " 2> ${STDERR} || " +
                "( >&2 echo 'Could not extract plist from provisioning profile' " +
                " && >&2 cat ${STDERR} && exit 1 ) " +
                ")")

def _extracted_provisioning_profile_identity(ctx, provisioning_profile):
    """Extracts the first signing certificate hex ID from a provisioning profile.

    Args:
      ctx: The Skylark context.
      provisioning_profile: The provisioning profile from which to extract the
          signing identity.

    Returns:
      A Bash output-capturing subshell expression (`$( ... )`) that executes
      commands needed to extract the hex ID of a signing certificate from a
      provisioning profile. This expression can then be used in later commands
      to include the ID in code-signing commands.
    """
    extract_plist_cmd = _extract_provisioning_plist_command(
        ctx,
        provisioning_profile,
    )
    return ("$( " +
            "PLIST=$(mktemp -t cert.plist) && trap \"rm ${PLIST}\" EXIT && " +
            extract_plist_cmd + " > ${PLIST} && " +
            "/usr/libexec/PlistBuddy -c " +
            "'Print DeveloperCertificates:0' " +
            "${PLIST} | openssl x509 -inform DER -noout -fingerprint | " +
            "cut -d= -f2 | sed -e s#:##g " +
            ")")

def _verify_signing_id_commands(identity, provisioning_profile):
    """Returns commands that verify that the given identity is valid.

    Args:
      identity: The signing identity to verify.
      provisioning_profile: The provisioning profile, if the signing identity was
          extracted from it. If provided, this is included in the error message
          that is printed if the identity is not valid.

    Returns:
      A string containing Bash commands that verify the signing identity and
      assign it to the environment variable `VERIFIED_ID` if it is valid.
    """
    verified_id = ("VERIFIED_ID=" +
                   "$( " +
                   "security find-identity -v -p codesigning | " +
                   "grep -F \"" + identity + "\" | " +
                   "xargs | " +
                   "cut -d' ' -f2 " +
                   ")\n")

    # If the identity was extracted from the provisioning profile (as opposed to
    # being passed on the command line), include that as part of the error message
    # to point the user at the source of the identity being used.
    if provisioning_profile:
        found_in_prov_profile_msg = (" found in provisioning profile " +
                                     provisioning_profile.path)
    else:
        found_in_prov_profile_msg = ""

    # Exit and report an Xcode-visible error if no matched identifiers were found.
    error_handling = ("if [[ -z \"$VERIFIED_ID\" ]]; then\n" +
                      "  " +
                      "echo " +
                      "error: Could not find a valid identity in the " +
                      "keychain matching \"" + identity + "\"" +
                      found_in_prov_profile_msg + "." +
                      "\n" +
                      "  " +
                      "exit 1\n" +
                      "fi\n")
    return verified_id + error_handling

def _embedded_provisioning_profile_name(ctx):
    """Returns the name of the embedded provisioning profile for the target.

    On macOS, the name of the provisioning profile that is placed in the bundle is
    named `embedded.provisionprofile`. On all other Apple platforms, it is named
    `embedded.mobileprovision`.

    Args:
      ctx: The Skylark context.

    Returns:
      The name of the embedded provisioning profile in the bundle.
    """
    if platform_support.platform_type(ctx) == apple_common.platform_type.macos:
        return "embedded.provisionprofile"
    return "embedded.mobileprovision"

def _codesign_command(ctx, path_to_sign, entitlements_file):
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

    # The command returned by this function is executed as part of the final
    # bundling shell script. Each directory to be signed must be prefixed by
    # $WORK_DIR, which is the variable in that script that contains the path
    # to the directory where the bundle is being built.
    if platform_support.is_device_build(ctx):
        entitlements_flag = ""
        if path_to_sign.use_entitlements and entitlements_file:
            entitlements_flag = (
                "--entitlements %s" % shell.quote(entitlements_file.path)
            )

        return ((cmd_prefix + "/usr/bin/codesign --force " +
                 "--sign $VERIFIED_ID %s %s") % (entitlements_flag, path))
    else:
        # Use ad hoc signing for simulator builds.
        return ((cmd_prefix + "/usr/bin/codesign --force " +
                 "--timestamp=none --sign \"-\" %s") % path)

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
    return struct(path = path, optional = optional, glob = glob, use_entitlements = use_entitlements)

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
    if (is_device and
        ctx.attr._requires_signing_for_device and
        not provisioning_profile):
        fail("The provisioning_profile attribute must be set for device " +
             "builds on this platform (%s)." %
             platform_support.platform_type(ctx))

    # First, try to use the identity passed on the command line, if any. If it's
    # a simulator build, use an ad hoc identity.
    identity = ctx.fragments.objc.signing_certificate_name if is_device else "-"

    # If no identity was passed on the command line, then for device builds that
    # require signing (i.e., not macOS), try to extract one from the provisioning
    # profile. Fail if one was not provided.
    if not identity and is_device and provisioning_profile:
        identity = _extracted_provisioning_profile_identity(
            ctx,
            provisioning_profile,
        )

    # If we still don't have an identity, fall back to ad hoc signing.
    if not identity:
        identity = "-"

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

    # If we're ad hoc signing or signing is mocked for tests, don't bother
    # verifying the identity in the keychain. Otherwise, verify that the identity
    # matches valid, unexpired entitlements in the keychain and return the first
    # unique hexadecimal identifier.
    if identity == "-" or mock_support.is_provisioning_mocked(ctx):
        commands.append("VERIFIED_ID=" + shell.quote(identity) + "\n")
    else:
        commands.append(
            _verify_signing_id_commands(identity, provisioning_profile),
        )

    for path_to_sign in paths_to_sign:
        commands.append(_codesign_command(ctx, path_to_sign, entitlements_file))

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
    if not ctx.attr._skip_simulator_signing_allowed:
        return True

    # Default is to sign.
    return define_utils.bool_value(
        ctx,
        "apple.codesign_simulator_bundles",
        True,
    )

# Define the loadable module that lists the exported symbols in this file.
codesigning_support = struct(
    embedded_provisioning_profile_name = _embedded_provisioning_profile_name,
    path_to_sign = _path_to_sign,
    should_sign_simulator_bundles = _should_sign_simulator_bundles,
    signing_command_lines = _signing_command_lines,
)
