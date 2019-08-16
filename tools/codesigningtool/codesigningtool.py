# Lint as: python2, python3
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

from __future__ import absolute_import
from __future__ import print_function
import argparse
import os
import plistlib
import re
import subprocess
import sys

_PY3 = sys.version_info[0] == 3


# Regex with benign codesign messages that can be safely ignored.
# It matches the following bening outputs:
# * signed Mach-O thin
# * signed Mach-O universal
# * signed app bundle with Mach-O universal
# * signed bundle with Mach-O thin
# * replacing existing signature
_BENIGN_CODESIGN_OUTPUT_REGEX = re.compile(
    r'(signed.*Mach-O (universal|thin)|libswift.*\.dylib: replacing existing signature)'
)


def _check_output(args, inputstr=None):
  proc = subprocess.Popen(
      args,
      stdin=subprocess.PIPE,
      stdout=subprocess.PIPE,
      stderr=subprocess.PIPE)
  stdout, stderr = proc.communicate(input=inputstr)

  # Only decode the output for Py3 so that the output type matches
  # the native string-literal type. This prevents Unicode{Encode,Decode}Errors
  # in Py2.
  if _PY3:
    # The invoked tools don't specify what encoding they use, so for lack of a
    # better option, just use utf8 with error replacement. This will replace
    # incorrect utf8 byte sequences with '?', which avoids UnicodeDecodeError
    # from raising.
    stdout = stdout.decode('utf8', 'replace')
    stderr = stderr.decode('utf8', 'replace')

  if proc.returncode != 0:
    # print the stdout and stderr, as the exception won't print it.
    print("ERROR:{stdout}\n\n{stderr}".format(stdout=stdout, stderr=stderr))
    raise subprocess.CalledProcessError(proc.returncode, args)
  return stdout, stderr


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
  fingerprint, stderr = _check_output([
      "openssl",
      "x509",
      "-inform",
      "DER",
      "-noout",
      "-fingerprint",
  ],
                                      inputstr=identity)
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
  output, stderr = _check_output([
      "security",
      "find-identity",
      "-v",
      "-p",
      "codesigning",
  ])
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

def main(argv):
  parser = argparse.ArgumentParser(description="codesign wrapper")
  parser.add_argument(
      "--mobileprovision", type=str, help="mobileprovision file")
  parser.add_argument(
      "--codesign", required=True, type=str, help="path to codesign binary")
  parser.add_argument(
      "--identity", type=str, help="specific identity to sign with")
  args, codesign_args = parser.parse_known_args()
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
    print("ERROR: Unable to find an identity on the system matching the "\
        "ones in %s" % args.mobileprovision, file=sys.stderr)
    return 1
  stdout, stderr = _check_output([args.codesign, "-v", "--sign", identity] +
                                 codesign_args,)
  if stdout:
    filtered_stdout = _filter_codesign_output(stdout)
    if filtered_stdout:
      print(filtered_stdout)
  if stderr:
    filtered_stderr = _filter_codesign_output(stderr)
    if filtered_stderr:
      print(filtered_stderr)


if __name__ == '__main__':
  sys.exit(main(sys.argv))
