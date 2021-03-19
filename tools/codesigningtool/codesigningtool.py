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

import argparse
import os
import plistlib
import re
import subprocess
import sys

from build_bazel_rules_apple.tools.wrapper_common import execute


# Regex with benign codesign messages that can be safely ignored.
# It matches the following bening outputs:
# * signed Mach-O thin
# * signed Mach-O universal
# * signed app bundle with Mach-O universal
# * signed bundle with Mach-O thin
# * replacing existing signature
# * using the deprecated --resource-rules flag
_BENIGN_CODESIGN_OUTPUT_REGEX = re.compile(
    r'('
    r'signed.*Mach-O (universal|thin)|'
    r'replacing existing signature|'
    r'Warning: --resource-rules has been deprecated'
    r')'
)


def _find_codesign_allocate():
  cmd = ["xcrun", "--find", "codesign_allocate"]
  _, stdout, _ = execute.execute_and_filter_output(cmd, raise_on_failure=True)
  return stdout.strip()


def _invoke_codesign(codesign_path, identity, entitlements, force_signing,
                     disable_timestamp, full_path_to_sign, extra):
  """Invokes the codesign tool on the given path to sign.

  Args:
    codesign_path: Path to the codesign tool as a string.
    identity: The unique identifier string to identify code signatures.
    entitlements: Path to the file with entitlement data. Optional.
    force_signing: If true, replaces any existing signature on the path given.
    disable_timestamp: If true, disables the use of timestamp services.
    full_path_to_sign: Path to the bundle or binary to code sign as a string.
  """
  cmd = [codesign_path, "-v", "--sign", identity]
  if entitlements:
    cmd.extend([
        "--entitlements",
        entitlements,
    ])
  if force_signing:
    cmd.append("--force")
  if disable_timestamp:
    cmd.append("--timestamp=none")
  cmd.append(full_path_to_sign)
  cmd.extend(extra)

  # Just like Xcode, ensure CODESIGN_ALLOCATE is set to point to the correct
  # version.
  custom_env = {"CODESIGN_ALLOCATE": _find_codesign_allocate()}
  _, stdout, stderr = execute.execute_and_filter_output(cmd,
                                                        custom_env=custom_env,
                                                        raise_on_failure=True)
  if stdout:
    filtered_stdout = _filter_codesign_output(stdout)
    if filtered_stdout:
      print(filtered_stdout)
  if stderr:
    filtered_stderr = _filter_codesign_output(stderr)
    if filtered_stderr:
      print(filtered_stderr)


def plist_from_bytes(byte_content):
  try:
    return plistlib.loads(byte_content)
  except AttributeError:
    return plistlib.readPlistFromString(byte_content)


def _parse_mobileprovision_file(mobileprovision_file):
  """Reads and parses a mobileprovision file."""
  plist_xml = subprocess.check_output([
      "security",
      "cms",
      "-D",
      "-i",
      mobileprovision_file,
  ])
  return plist_from_bytes(plist_xml)


def _certificate_fingerprint(identity):
  """Extracts a fingerprint given identity in a mobileprovision file."""
  _, fingerprint, _ = execute.execute_and_filter_output([
      "openssl",
      "x509",
      "-inform",
      "DER",
      "-noout",
      "-fingerprint",
  ], inputstr=identity, raise_on_failure=True)
  fingerprint = fingerprint.strip()
  fingerprint = fingerprint.replace("SHA1 Fingerprint=", "")
  fingerprint = fingerprint.replace(":", "")
  return fingerprint


def _get_identities_from_provisioning_profile(mpf):
  """Iterates through all the identities in a provisioning profile, lazily."""
  for identity in mpf["DeveloperCertificates"]:
    if not isinstance(identity, bytes):
      # Old versions of plistlib return the deprecated plistlib.Data type
      # instead of bytes.
      identity = identity.data
    yield _certificate_fingerprint(identity)


def _find_codesign_identities(identity=None):
  """Finds code signing identities on the current system."""
  ids = []
  _, output, _ = execute.execute_and_filter_output([
      "security",
      "find-identity",
      "-v",
      "-p",
      "codesigning",
  ], raise_on_failure=True)
  output = output.strip()
  pattern = "(?P<hash>[A-F0-9]{40})"
  if identity:
    name_requirement = re.escape(identity)
    pattern += r'\s+".*?{}.*?"'.format(name_requirement)
  regex = re.compile(pattern)
  for line in output.splitlines():
    # CSSMERR_TP_CERT_REVOKED comes from Security.framework/cssmerr.h
    if "CSSMERR_TP_CERT_REVOKED" in line:
      continue
    m = regex.search(line)
    if m:
      groups = m.groupdict()
      id = groups["hash"]
      ids.append(id)
  return ids


def _find_codesign_identity(mobileprovision):
  """Finds a valid identity on the system given a mobileprovision file."""
  mpf = _parse_mobileprovision_file(mobileprovision)
  ids_codesign = set(_find_codesign_identities())
  for id_mpf in _get_identities_from_provisioning_profile(mpf):
    if id_mpf in ids_codesign:
      return id_mpf


def _filter_codesign_output(codesign_output):
  """Filters the codesign output which can be extra verbose."""
  filtered_lines = []
  for line in codesign_output.splitlines():
    if line and not _BENIGN_CODESIGN_OUTPUT_REGEX.search(line):
      filtered_lines.append(line)
  return "\n".join(filtered_lines)


def _all_paths_to_sign(targets_to_sign, directories_to_sign):
  """Returns a list of paths to sign from paths to targets and directories"""
  all_paths_to_sign = []

  if targets_to_sign:
    for target_to_sign in targets_to_sign:
      all_paths_to_sign.append(target_to_sign)

  if directories_to_sign:
    for directory_to_sign in directories_to_sign:
      if not os.path.exists(directory_to_sign):
        # TODO(b/149874635): Cleanly error here rather than no-op when the
        # failure to find a directory is a valid error condition.
        continue
      files_found = [
          x for x in os.listdir(directory_to_sign) if not x.startswith(".")
      ]
      # Prefix each path found through os.listdir before passing to codesign.
      all_paths_to_sign = [
          os.path.join(directory_to_sign, f) for f in files_found
      ]

  return all_paths_to_sign


def _filter_paths_already_signed(all_paths_to_sign, signed_paths):
  if set(signed_paths) - set(all_paths_to_sign):
    # TODO(b/151635856): Turn this condition into an error when clang_rt libs
    # for the sanitizers are properly scoped to only the *_application
    # Frameworks and not the *_extension Frameworks.
    print("WARNING: From the set of all paths to sign, signed frameworks were "
          "not found: %s" % (set(signed_paths) - set(all_paths_to_sign)))
    print("Set of all paths to sign contains: %s" % all_paths_to_sign)
  return [p for p in all_paths_to_sign if p not in signed_paths]


def generate_arg_parser():
  """Returns the arugment parser for the code signing tool."""
  parser = argparse.ArgumentParser(description="codesign wrapper")
  parser.add_argument(
      "--target_to_sign", type=str, action="append", help="full file system "
      "paths to a target to code sign"
  )
  parser.add_argument(
      "--directory_to_sign", type=str, action="append", help="full file system "
      "paths to a directory to code sign, if the directory doesn't exist this "
      "script will do nothing"
  )
  parser.add_argument(
      "--mobileprovision", type=str, help="mobileprovision file")
  parser.add_argument(
      "--codesign", required=True, type=str, help="path to codesign binary")
  parser.add_argument(
      "--identity", type=str, help="specific identity to sign with")
  parser.add_argument(
      "--signed_path", type=str, action="append", help="a path that has "
      "already been signed"
  )
  parser.add_argument(
      "--entitlements", type=str, help="file with entitlement data to forward "
      "to the code signing tool"
  )
  parser.add_argument(
      "--force", action="store_true", help="replace any existing signature on "
      "the path(s) given"
  )
  parser.add_argument(
      "--disable_timestamp", action="store_true", help="disables the use of "
      "timestamp services"
  )
  parser.add_argument("extra", nargs = argparse.REMAINDER, help="additional "
      "arguments that go directly to codesign, starting with a '--' argument")
  return parser


def main(args):
  extra = []
  if args.extra:
    if args.extra[0] != "--":
      print(
          "ERROR: unknown argument given: %s (the only unknown arguments "
          "allowed are those following '--' and which go directly to "
          "codesign)" % args.extra[0], file=sys.stderr)
  extra = args.extra[1:]
  identity = args.identity
  if identity is None:
    identity = _find_codesign_identity(args.mobileprovision)
  elif identity != "-":
    matching_identities = _find_codesign_identities(identity)
    if matching_identities:
      identity = matching_identities[0]
    else:
      print(
          "ERROR: No signing identity found for '{}'".format(identity),
          file=sys.stderr)
      return -1
  # No identity was found, fail
  if identity is None:
    print("ERROR: Unable to find an identity on the system matching the "
          "ones in %s" % args.mobileprovision, file=sys.stderr)
    return 1
  # No targets to sign were provided, fail
  if not args.target_to_sign and not args.directory_to_sign:
    print("INTERNAL ERROR: No paths to sign were given to codesign. Should "
          "have one of --target_to_sign or --directory_to_sign")
    return 1
  all_paths_to_sign = _all_paths_to_sign(args.target_to_sign,
                                         args.directory_to_sign)
  if not all_paths_to_sign:
    # TODO(b/149874635): Cleanly error here rather than no-op when the failure
    # to find paths to sign is a valid error condition.
    return 0
  signed_path = args.signed_path
  if signed_path:
    all_paths_to_sign = _filter_paths_already_signed(all_paths_to_sign,
                                                     signed_path)

  for path_to_sign in all_paths_to_sign:
    _invoke_codesign(args.codesign, identity, args.entitlements, args.force,
                     args.disable_timestamp, path_to_sign, extra)


if __name__ == "__main__":
  sys.exit(main(generate_arg_parser().parse_args()))
