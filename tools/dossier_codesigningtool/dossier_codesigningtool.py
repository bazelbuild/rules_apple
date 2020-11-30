# Lint as: python2, python3
# Copyright 2020 The Bazel Authors. All rights reserved.
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
"""A tool to manage code signing using dossiers.

Provides functionality to generate codesigning dossiers from bundles, and sign
bundles using codesigning dossiers.
"""

from __future__ import absolute_import
from __future__ import print_function

import argparse
import json
import os
import os.path
import plistlib
import re
import shutil
import subprocess
import sys
import uuid

from build_bazel_rules_apple.tools.wrapper_common import execute

# Regex with benign codesign messages that can be safely ignored.
# It matches the following benign outputs:
# * signed Mach-O thin
# * signed Mach-O universal
# * signed app bundle with Mach-O universal
# * signed bundle with Mach-O thin
# * replacing existing signature
_BENIGN_CODESIGN_OUTPUT_REGEX = re.compile(
    r'(signed.*Mach-O (universal|thin)|.*: replacing existing signature)')

# Keys used for manifest entries.
_CODESIGN_IDENTITY_KEY = 'codesign_identity'
_ENTITLEMENTS_KEY = 'entitlements'
_PROVISIONING_PROFILE_KEY = 'provisioning_profile'
_EMBEDDED_BUNDLE_MANIFESTS_KEY = 'embedded_bundle_manifests'
_EMBEDDED_RELATIVE_PATH_KEY = 'embedded_relative_path'

# The filename for a manifest within a manifest
_MANIFEST_FILENAME = 'manifest.json'

# Directories within a bundle that embedded bundles may be present in.
_EMBEDDED_BUNDLE_DIRECTORY_NAMES = ['AppClips', 'PlugIns', 'Frameworks']


def generate_arg_parser():
  """Generate argument parser for tool."""
  parser = argparse.ArgumentParser(
      description='Tool for signing iOS bundles using dossiers.')
  subparsers = parser.add_subparsers(help='Sub-commands')

  sign_parser = subparsers.add_parser(
      'sign', help='Sign an apple bundle using a dossier.')
  sign_parser.add_argument('--dossier', help='Path to input dossier directory')
  sign_parser.add_argument(
      '--codesign', required=True, type=str, help='Path to codesign binary')
  sign_parser.add_argument('bundle', help='Path to the bundle')
  sign_parser.set_defaults(func=_sign_bundle)

  generate_parser = subparsers.add_parser(
      'generate', help='Generate a dossier from a signed bundle.')
  generate_parser.add_argument(
      '--output', help='Path to output manifest dossier directory')
  generate_parser.add_argument(
      '--codesign', required=True, type=str, help='Path to codesign binary')
  generate_parser.add_argument('bundle', help='Path to the bundle')
  generate_parser.set_defaults(func=_generate_manifest_dossier)

  create_parser = subparsers.add_parser('create', help='Create a dossier.')
  create_parser.add_argument(
      '--output',
      required=True,
      help='Path to output manifest dossier directory')
  create_parser.add_argument(
      '--codesign_identity',
      required=True,
      type=str,
      help='Codesigning identity to be used.')
  create_parser.add_argument(
      '--provisioning_profile',
      type=str,
      help='Optional provisioning profile to be used.')
  create_parser.add_argument(
      '--entitlements_file',
      type=str,
      help='Optional path to optional entitlements')
  create_parser.add_argument(
      '--embedded_dossier',
      action='append',
      nargs=2,
      help='Specifies an embedded bundle dossier to be included in created dossier. Should be in form [relative path of artifact dossier signs] [path to dossier]'
  )
  create_parser.set_defaults(func=_create_dossier)

  return parser


def _extract_codesign_data(bundle_path, output_directory, unique_id,
                           codesign_path):
  """Extracts the codesigning data for provided bundle to output directory.

   Given a bundle_path will extract the entitlements file to the provided
   output_directory as well as extract the codesigning identity.

  Args:
    bundle_path: The absolute path to the bundle to extract entitlements from.
    output_directory: The absolute path to the output directory the entitlements
      should be placed in, it must already exist.
    unique_id: Unique identifier to use for filename of extracted entitlements.
    codesign_path: Path to the codesign tool as a string.

  Returns:
    A tuple of the output file name for the entitlements in the output_directory
    and the codesigning identity. If either of these is not available, they will
    be set to None in the tuple.

  Raises:
    OSError: If unable to extract codesign identity.
  """
  command = (codesign_path, '-dvv', '--entitlements', ':-', bundle_path)
  process = subprocess.Popen(
      command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
  output, stderr = process.communicate()
  if process.poll() != 0:
    raise OSError('Fail to extract entitlements from bundle: %s' % stderr)
  if not output:
    return None, None
  signing_info = re.search(r'^Authority=(.*)$', str(stderr), re.MULTILINE)
  if signing_info:
    cert_authority = signing_info.group(1)
  else:
    cert_authority = None
  plist = plistlib.readPlistFromString(output)
  if not plist:
    return None, cert_authority
  output_file_name = unique_id + '.entitlements'
  output_file_path = os.path.join(output_directory, output_file_name)
  output_file = open(output_file_path, 'w')
  output_file.write(output)
  output_file.close()
  return output_file_name, cert_authority


def _copy_entitlements_file(original_entitlements_file_path, output_directory,
                            unique_id):
  """Copies an entitlements file from an original path to an output directory.

  Args:
    original_entitlements_file_path: The absolute path to the original
      entitlements file.
    output_directory: The absolute path to the output directory the entitlements
      should be placed in, it must already exist.
    unique_id: Unique identifier to use for filename of extracted entitlements.

  Returns:
    The filename relative to output_directory the entitlements were copied to,
    or if the original path does not exist it does nothing and will return
    `None`.
  """
  if os.path.exists(original_entitlements_file_path):
    dest_entitlements_filename = unique_id + '.entitlements'
    dest_entitlements_path = os.path.join(output_directory,
                                          dest_entitlements_filename)
    shutil.copy(original_entitlements_file_path, dest_entitlements_path)
    return dest_entitlements_filename
  else:
    return None


def _copy_provisioning_profile(original_provisiong_profile_path,
                               output_directory, unique_id):
  """Copies a provisioning profile file from an original path to an output directory.

  Args:
    original_provisiong_profile_path: The absolute path to the original
      provisioning profile file.
    output_directory: The absolute path to the output directory the profile
      should be placed in, it must already exist.
    unique_id: Unique identifier to use for filename of extracted entitlements.

  Returns:
    The filename relative to output_directory the profile was copied to, or if
    the original path does not exist it does nothing and will return `None`.
  """
  if os.path.exists(original_provisiong_profile_path):
    dest_provisiong_profile_filename = unique_id + '.mobileprovision'
    dest_provision_profile_path = os.path.join(
        output_directory, dest_provisiong_profile_filename)
    shutil.copy(original_provisiong_profile_path, dest_provision_profile_path)
    return dest_provisiong_profile_filename
  else:
    return None


def _extract_provisioning_profile(bundle_path, output_directory, unique_id):
  """Extracts the provisioning profile for provided bundle to destination file name.

  Given a bundle_path will extract the entitlements file to the provided
  output_directory, and return the filename relative to the output_directory
  that the entitlements have been placed in, or None if no entitlements exist.

  Args:
    bundle_path: The absolute path to the bundle to extract entitlements from.
    output_directory: The absolute path to the output directory the entitlements
      should be placed in, it must already exist.
    unique_id: Unique identifier to use for filename of extracted entitlements.

  Returns:
    The filename relative to output_directory the entitlements were placed in,
    or None if there were no entitlements found.

  Raises:
    Error if unable to extract entitlements.
  """
  original_provisiong_profile_path = os.path.join(bundle_path,
                                                  'embedded.mobileprovision')
  return _copy_provisioning_profile(original_provisiong_profile_path,
                                    output_directory, unique_id)


def _generate_manifest(codesign_identity,
                       entitlement_file=None,
                       provisioning_profile_file=None,
                       embedded_bundle_manifests=None):
  """Generates the manifest based on provided parameters.

  Given a set of code signing parameters, generates a manifest representation
  suitable for inclusion in a codesigning dossier.

  Args:
    codesign_identity: The string representing the codesigning identity to be
      used for signing this bundle.
    entitlement_file: The absolute path to the entitlements file to use for
      signing this bundle, or None if no entitlements need to be included.
    provisioning_profile_file: The absolute path to the provisioning profile to
      embed within the signed bundle, or None if none needs to be embedded.
    embedded_bundle_manifests: Manifests for embedded bundles that should be
      included in this manifest, or None if there are none.

  Returns:
    The manifest contents.
  """
  manifest = {_CODESIGN_IDENTITY_KEY: codesign_identity}
  if entitlement_file is not None:
    manifest[_ENTITLEMENTS_KEY] = entitlement_file
  if provisioning_profile_file is not None:
    manifest[_PROVISIONING_PROFILE_KEY] = provisioning_profile_file
  if embedded_bundle_manifests is not None:
    manifest[_EMBEDDED_BUNDLE_MANIFESTS_KEY] = embedded_bundle_manifests
  return manifest


def _embedded_manifests_for_path(bundle_path, dossier_directory,
                                 target_directory, codesign_path):
  """Generates embedded manifests for a bundle in a sub-directory.

  Provided a bundle, output directory, and a target directory, traverses the
  target directory to find any bundles that are signed, and generate manifests.
  Copies any referenced assets to the output directory.

  Args:
    bundle_path: The absolute path to the bundle that will be searched.
    dossier_directory: The absolute path to the output dossier directory that
      manifest referenced assets will be copied to.
    target_directory: The target directory name, relative to the bundle_path, to
      be traversed.
    codesign_path: Path to the codesign tool as a string.

  Returns:
    A list of manifest contents with the contents they reference copied into
    dossier_directory, or an empty list if no bundles are codesigned.
  """
  embedded_manifests = []
  target_directory_path = os.path.join(bundle_path, target_directory)
  if os.path.exists(target_directory_path):
    target_directory_contents = os.listdir(target_directory_path)
    target_directory_contents.sort()
    for filename in target_directory_contents:
      absolute_embedded_bundle_path = os.path.join(target_directory_path,
                                                   filename)
      embedded_manifest = _manifest_with_dossier_for_bundle(
          absolute_embedded_bundle_path, dossier_directory, codesign_path)
      if embedded_manifest is not None:
        embedded_manifest[_EMBEDDED_RELATIVE_PATH_KEY] = os.path.join(
            target_directory, filename)
        embedded_manifests.append(embedded_manifest)
  return embedded_manifests


def _manifest_with_dossier_for_bundle(bundle_path, dossier_directory,
                                      codesign_path):
  """Generates a manifest and assets for a provided bundle.

  Provided a bundle and output directory, prepares a code signing dossier by
  generating the manifest contents for the bundle referenced and copying any
  assets referenced by the manifest into the dossier folder.

  Args:
    bundle_path: The absolute path to the bundle that a manifest will be
      generated for.
    dossier_directory: The absolute path to the output dossier directory that
      manifest referenced assets will be copied to.
    codesign_path: Path to the codesign tool as a string.

  Returns:
    The manifest contents with files they reference copied into
    dossier_directory.
  """
  unique_id = str(uuid.uuid4())
  entitlements_file, codesign_identity = _extract_codesign_data(
      bundle_path, dossier_directory, unique_id, codesign_path)
  if not codesign_identity:
    return None
  provisioning_profile = _extract_provisioning_profile(bundle_path,
                                                       dossier_directory,
                                                       unique_id)
  embedded_manifests = []
  for embedded_bundle_directory in _EMBEDDED_BUNDLE_DIRECTORY_NAMES:
    embedded_manifests.extend(
        _embedded_manifests_for_path(bundle_path, dossier_directory,
                                     embedded_bundle_directory, codesign_path))
  if not embedded_manifests:
    embedded_manifests = None
  return _generate_manifest(codesign_identity, entitlements_file,
                            provisioning_profile, embedded_manifests)


def _generate_manifest_dossier(args):
  """Generate a manifest dossier for provided args."""
  bundle_path = args.bundle
  dossier_directory = args.output
  codesign_path = args.codesign
  if not os.path.exists(dossier_directory):
    os.makedirs(dossier_directory)
  manifest = _manifest_with_dossier_for_bundle(
      os.path.abspath(bundle_path), dossier_directory, codesign_path)
  manifest_file = open(os.path.join(dossier_directory, _MANIFEST_FILENAME), 'w')
  manifest_file.write(json.dumps(manifest, sort_keys=True))
  manifest_file.close()


def _find_codesign_allocate():
  cmd = ['xcrun', '--find', 'codesign_allocate']
  _, stdout, _ = execute.execute_and_filter_output(cmd, raise_on_failure=True)
  return stdout.strip()


def _filter_codesign_output(codesign_output):
  """Filters the codesign output which can be extra verbose."""
  filtered_lines = []
  for line in codesign_output.splitlines():
    if line and not _BENIGN_CODESIGN_OUTPUT_REGEX.search(line):
      filtered_lines.append(line)
  return '\n'.join(filtered_lines)


def _filter_codesign_tool_output(exit_status, codesign_stdout, codesign_stderr):
  """Filters the output from executing the codesign tool."""
  return _filter_codesign_output(codesign_stdout), _filter_codesign_output(
      codesign_stderr)


def _invoke_codesign(codesign_path, identity, entitlements, force_signing,
                     disable_timestamp, full_path_to_sign):
  """Invokes the codesign tool on the given path to sign.

  Args:
    codesign_path: Path to the codesign tool as a string.
    identity: The unique identifier string to identify code signatures.
    entitlements: Path to the file with entitlement data. Optional.
    force_signing: If true, replaces any existing signature on the path given.
    disable_timestamp: If true, disables the use of timestamp services.
    full_path_to_sign: Path to the bundle or binary to code sign as a string.
  """
  cmd = [codesign_path, '-v', '--sign', identity]
  if entitlements:
    cmd.extend([
        '--entitlements',
        entitlements,
    ])
  if force_signing:
    cmd.append('--force')
  if disable_timestamp:
    cmd.append('--timestamp=none')
  cmd.append(full_path_to_sign)

  # Just like Xcode, ensure CODESIGN_ALLOCATE is set to point to the correct
  # version.
  custom_env = {'CODESIGN_ALLOCATE': _find_codesign_allocate()}
  execute.execute_and_filter_output(
      cmd,
      filtering=_filter_codesign_tool_output,
      custom_env=custom_env,
      raise_on_failure=True,
      print_output=True)


def _sign_bundle_with_manifest(root_bundle_path, manifest, dossier_directory,
                               codesign_path):
  """Signing a bundle with a dossier.

  Provided a bundle, dossier path, and the path to the codesign tool, will sign
  a bundle using the dossier's information.

  Args:
    root_bundle_path: The absolute path to the bundle that will be signed.
    manifest: The contents of the manifest in this dossier.
    dossier_directory: Directory of dossier to be used for signing.
    codesign_path: Path to the codesign tool as a string.
  """
  codesign_identity = manifest[_CODESIGN_IDENTITY_KEY]
  entitlements_filename = manifest[_ENTITLEMENTS_KEY]
  provisioning_profile_filename = manifest[_PROVISIONING_PROFILE_KEY]
  entitlements_file_path = os.path.join(dossier_directory,
                                        entitlements_filename)
  provisioning_profile_file_path = os.path.join(dossier_directory,
                                                provisioning_profile_filename)
  for embedded_manifest in manifest.get(_EMBEDDED_BUNDLE_MANIFESTS_KEY, []):
    embedded_relative_path = embedded_manifest[_EMBEDDED_RELATIVE_PATH_KEY]
    embedded_bundle_path = os.path.join(root_bundle_path,
                                        embedded_relative_path)
    _sign_bundle_with_manifest(embedded_bundle_path, embedded_manifest,
                               dossier_directory, codesign_path)
  dest_provisioning_profile_path = os.path.join(root_bundle_path,
                                                'embedded.mobileprovision')
  shutil.copy(provisioning_profile_file_path, dest_provisioning_profile_path)
  _invoke_codesign(
      codesign_path=codesign_path,
      identity=codesign_identity,
      entitlements=entitlements_file_path,
      force_signing=True,
      disable_timestamp=False,
      full_path_to_sign=root_bundle_path)


def _sign_bundle(args):
  """Signing a bundle with a dossier.

  Provided a set of args from generate sub-command, signs a bundle.

  Args:
    bundle_path: The absolute path to the bundle that will be signed.
    dossier_directory: The absolute path to the output dossier directory that
      will be used to sign this bundle.
    codesign_path: Path to the codesign tool as a string.

  Raises:
    OSError: If bundle or manifest dossier can not be found.
  """
  bundle_path = args.bundle
  dossier_directory = args.dossier
  codesign_path = args.codesign
  if not os.path.exists(bundle_path):
    raise OSError('Bundle doest not exist at path %s' % bundle_path)
  manifest = _read_manifest_from_dossier(dossier_directory)
  _sign_bundle_with_manifest(bundle_path, manifest, dossier_directory,
                             codesign_path)


def _read_manifest_from_dossier(dossier_directory):
  """Reads the manifest from a dossier file.

  Args:
    dossier_directory: The path to the dossier.

  Raises:
    OSError: If bundle or manifest dossier can not be found.
  """
  manifest_file_path = os.path.join(dossier_directory, _MANIFEST_FILENAME)
  if not os.path.exists(manifest_file_path):
    raise OSError('Dossier doest not exist at path %s' % dossier_directory)
  with open(manifest_file_path, 'r') as fp:
    return json.load(fp)


def _merge_dossier_contents(source_dossier_path, destination_dossier_path):
  """Merges all of the files except the actual manifest from one dossier into another.

  Args:
    source_dossier_path: The path to the source dossier.
    destination_dossier_path: The path to the destination dossier.
  """
  dossier_files = os.listdir(source_dossier_path)
  for filename in dossier_files:
    if filename == _MANIFEST_FILENAME:
      continue
    shutil.copy(
        os.path.join(source_dossier_path, filename),
        os.path.join(destination_dossier_path, filename))


def _create_dossier(args):
  """Creates a signing dossier.

  Provided a set of args from generate sub-command, creates a new dossier.
  """
  dossier_directory = args.output
  if not os.path.exists(dossier_directory):
    os.makedirs(dossier_directory)
  unique_id = str(uuid.uuid4())
  entitlements_filename = None
  if hasattr(args, 'entitlements_file'):
    entitlements_filename = _copy_entitlements_file(args.entitlements_file,
                                                    dossier_directory,
                                                    unique_id)
  provisioning_profile_filename = None
  if hasattr(args, 'provisioning_profile'):
    provisioning_profile_filename = _copy_provisioning_profile(
        args.provisioning_profile, dossier_directory, unique_id)
  embedded_manifests = []
  if hasattr(args, 'embedded_dossier'):
    for embedded_dossier in args.embedded_dossier:
      embedded_dossier_bundle_relative_path = embedded_dossier[0]
      embedded_dossier_path = embedded_dossier[1]
      _merge_dossier_contents(embedded_dossier_path, dossier_directory)
      embedded_manifest = _read_manifest_from_dossier(embedded_dossier_path)
      embedded_manifest[
          _EMBEDDED_RELATIVE_PATH_KEY] = embedded_dossier_bundle_relative_path
      embedded_manifests.append(embedded_manifest)
  manifest = _generate_manifest(args.codesign_identity, entitlements_filename,
                                provisioning_profile_filename,
                                embedded_manifests)
  with open(os.path.join(dossier_directory, _MANIFEST_FILENAME), 'w') as fp:
    fp.write(json.dumps(manifest, sort_keys=True))


if __name__ == '__main__':
  args = generate_arg_parser().parse_args()
  sys.exit(args.func(args))
