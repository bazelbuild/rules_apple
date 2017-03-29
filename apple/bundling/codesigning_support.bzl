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

load("//apple/bundling:mock_support.bzl", "mock_support")
load("//apple/bundling:platform_support.bzl",
     "platform_support")
load("//apple/bundling:plist_support.bzl", "plist_support")
load("//apple/bundling:swift_support.bzl", "swift_support")
load("//apple:utils.bzl", "bash_quote")


def _provisioning_cert_hex_id_command(ctx):
  """Find a verified, unique hex identifer for a cert to codesign with.

  Args:
    ctx: The Skylark context.
  Returns:
    The command invocations to find a verified hex identifer for a cert to
    codesign with.
  """
  if (hasattr(ctx.file, "provisioning_profile") and
      not ctx.file.provisioning_profile):
    fail("The provisioning_profile attribute must be set for device builds.")

  cert_name = ctx.fragments.objc.signing_certificate_name
  if cert_name:
    identity = cert_name
  else:
    # Extract the signing certificate from the provisioning profile if one was
    # not explicitly provided.
    extract_plist_cmd = plist_support.extract_provisioning_plist_command(
        ctx, ctx.file.provisioning_profile)
    identity = ("$(" +
                "PLIST=$(mktemp -t cert.plist) && trap \"rm ${PLIST}\" EXIT " +
                " && " +
                extract_plist_cmd + " > ${PLIST} && " +
                "/usr/libexec/PlistBuddy -c " +
                "'Print DeveloperCertificates:0' " +
                "${PLIST} | openssl x509 -inform DER -noout -fingerprint | " +
                "cut -d= -f2 | sed -e s#:##g" +
                ")")

  # If we're ad hoc signing or signing is mocked for tests, don't bother
  # verifying the identity in the keychain. Otherwise, verify that the identity
  # matches valid, unexpired entitlements in the keychain and return the first
  # unique hexadecimal identifier.
  if cert_name == "-" or mock_support.is_provisioning_mocked(ctx):
    return "VERIFIED_ID=" + bash_quote(identity) + "\n"

  verified_id = ("VERIFIED_ID=" +
                 "$(" +
                 "security find-identity -v -p codesigning | " +
                 "grep -F " + bash_quote(identity) + " | " +
                 "xargs | " +
                 "cut -d' ' -f2 " +
                 ")\n")
  # Exit and report an Xcode-visible error if no matched identifiers were found.
  error_handling = ("if [ -z \"$VERIFIED_ID\" ]; then\n" +
                    "  " +
                    "echo " +
                    bash_quote("error: Could not find a valid identity in " +
                               "the keychain matching " +
                               '"' + identity + '"' + " " +
                               "found in provisioning profile " +
                               ctx.file.provisioning_profile.path + ".") +
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


def _codesign_command(ctx,
                      dir_to_sign,
                      entitlements_file,
                      optional=False):
  """Returns a single `codesign` command invocation.

  Args:
    ctx: The Skylark context.
    dir_to_sign: The path inside the archive to the directory to sign.
    entitlements_file: The entitlements file to pass to codesign. May be `None`
        for simulator builds or non-app binaries (e.g. test bundles).
    optional: If true, silently do nothing if the target directory does
        not exist. This is off by default to catch errors for "mandatory"
        sign paths.
  Returns:
    The codesign command invocation for the given directory.
  """
  full_dir = "$WORK_DIR/" + dir_to_sign
  cmd_prefix = ""
  if optional:
    cmd_prefix += "ls %s >& /dev/null && " % full_dir

  # The command returned by this function is executed as part of the final
  # bundling shell script. Each directory to be signed must be prefixed by
  # $WORK_DIR, which is the variable in that script that contains the path
  # to the directory where the bundle is being built.
  if platform_support.is_device_build(ctx):
    entitlements_flag = ""
    if entitlements_file:
      entitlements_flag = (
          "--entitlements %s" % bash_quote(entitlements_file.path))

    return (cmd_prefix + "/usr/bin/codesign --force " +
            "--sign $VERIFIED_ID %s %s" % (entitlements_flag, full_dir))
  else:
    # Use ad hoc signing for simulator builds.
    full_dir = "$WORK_DIR/" + dir_to_sign
    return cmd_prefix + '/usr/bin/codesign --force --sign "-" %s' % full_dir


def _signing_command_lines(ctx,
                           bundle_path_in_archive,
                           entitlements_file):
  """Returns a multi-line string with codesign invocations for the bundle.

  Args:
    ctx: The Skylark context.
    bundle_path_in_archive: The path to the bundle inside the archive.
    entitlements_file: The entitlements file to pass to codesign.)
  Returns:
    A multi-line string with codesign invocations for the bundle.
  """

  commands = []
  if platform_support.is_device_build(ctx):
    commands.append(_provisioning_cert_hex_id_command(ctx))
  commands.append(_codesign_command(ctx,
                                    bundle_path_in_archive + "/Frameworks/*",
                                    entitlements_file,
                                    optional=True))
  commands.append(_codesign_command(ctx,
                                    bundle_path_in_archive,
                                    entitlements_file))
  return "\n".join(commands)


# Define the loadable module that lists the exported symbols in this file.
codesigning_support = struct(
    embedded_provisioning_profile_name=_embedded_provisioning_profile_name,
    signing_command_lines=_signing_command_lines,
)
