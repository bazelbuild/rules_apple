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

import argparse
import concurrent.futures
import json
import os
import os.path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import uuid

from build_bazel_rules_apple.tools.wrapper_common import execute


class DossierDirectory(object):
  """Class to manage dossier directories.

  Must used as a context manager.

  Attributes:
    path: The string path to the directory.
    unzipped: A boolean indicating if the dossier was unzipped or already was a
      directory.
  """

  def __init__(self, path, unzipped):
    self.path = path
    self.unzipped = unzipped

  def __enter__(self):
    return self

  def __exit__(self, exception_type, exception_value, traceback):
    if self.unzipped:
      shutil.rmtree(self.path)


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
_EMBEDDED_BUNDLE_DIRECTORY_NAMES = [
    'AppClips', 'PlugIns', 'Frameworks', 'Watch'
]


def generate_arg_parser():
  """Generate argument parser for tool."""
  parser = argparse.ArgumentParser(
      description='Tool for signing iOS bundles using dossiers.',
      fromfile_prefix_chars='@')
  subparsers = parser.add_subparsers(help='Sub-commands')

  sign_parser = subparsers.add_parser(
      'sign', help='Sign an apple bundle using a dossier.')
  sign_parser.add_argument(
      '--dossier',
      help='Path to input dossier location. Can be a directory or .zip file.')
  sign_parser.add_argument(
      '--codesign', required=True, type=str, help='Path to codesign binary')
  sign_parser.add_argument('bundle', help='Path to the bundle')
  sign_parser.set_defaults(func=_sign_bundle)

  generate_parser = subparsers.add_parser(
      'generate', help='Generate a dossier from a signed bundle.')
  generate_parser.add_argument(
      '--output',
      required=True,
      help='Path to output manifest dossier location.')
  generate_parser.add_argument(
      '--zip',
      action='store_true',
      help='Zip the final dossier into a file at specified location.')
  generate_parser.add_argument(
      '--codesign', required=True, type=str, help='Path to codesign binary')
  generate_parser.add_argument('bundle', help='Path to the bundle')
  generate_parser.set_defaults(func=_generate_manifest_dossier)

  create_parser = subparsers.add_parser('create', help='Create a dossier.')
  create_parser.add_argument(
      '--output',
      required=True,
      help='Path to output manifest dossier location.')
  create_parser.add_argument(
      '--zip',
      action='store_true',
      help='Zip the final dossier into a file at specified location.')
  identity_group = create_parser.add_mutually_exclusive_group(required=True)
  identity_group.add_argument(
      '--codesign_identity', type=str, help='Codesigning identity to be used.')
  identity_group.add_argument(
      '--infer_identity',
      action='store_true',
      help='Infer the codesigning identity based on provisioning profile at signing time. If this option is passed, the provisioning profile is mandatory.'
  )
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

  embed_parser = subparsers.add_parser(
      'embed',
      help='Embeds a dossier into an existing dossier. Only supports embedding at the top level of the existing dossier.'
  )
  embed_parser.add_argument(
      '--dossier', required=True, help='Path to dossier location to edit.')
  embed_parser.add_argument(
      '--embedded_relative_artifact_path',
      required=True,
      type=str,
      help='Relative path of artifact the dossier to be embedded signs')
  embed_parser.add_argument(
      '--embedded_dossier_path',
      required=True,
      type=str,
      help='Path to dossier to be embedded')
  embed_parser.set_defaults(func=_embed_dossier)

  return parser


def _parse_provisioning_profile(provisioning_profile_path):
  """Reads and parses a provisioning profile."""
  plist_xml = subprocess.check_output([
      'security',
      'cms',
      '-D',
      '-i',
      provisioning_profile_path,
  ])
  return plistlib.loads(plist_xml)


def _certificate_fingerprint(identity):
  """Extracts a fingerprint given identity in a provisioning profile."""
  openssl_command = [
      'openssl',
      'x509',
      '-inform',
      'DER',
      '-noout',
      '-fingerprint',
  ]
  _, fingerprint, _ = execute.execute_and_filter_output(
      openssl_command, inputstr=identity, raise_on_failure=True)
  fingerprint = fingerprint.strip()
  fingerprint = fingerprint.replace('SHA1 Fingerprint=', '')
  fingerprint = fingerprint.replace(':', '')
  return fingerprint


def _find_codesign_identities(identity=None):
  """Finds code signing identities on the current system."""
  ids = []
  execute_command = [
      'security',
      'find-identity',
      '-v',
      '-p',
      'codesigning',
  ]
  _, output, _ = execute.execute_and_filter_output(execute_command,
                                                   raise_on_failure=True)
  output = output.strip()
  pattern = '(?P<hash>[A-F0-9]{40})'
  if identity:
    name_requirement = re.escape(identity)
    pattern += r'\s+".*?{}.*?"'.format(name_requirement)
  regex = re.compile(pattern)
  for line in output.splitlines():
    # CSSMERR_TP_CERT_REVOKED comes from Security.framework/cssmerr.h
    if 'CSSMERR_TP_CERT_REVOKED' in line:
      continue
    m = regex.search(line)
    if m:
      groups = m.groupdict()
      id = groups['hash']
      ids.append(id)
  return ids


def _find_codesign_identity(provisioning_profile_path):
  """Finds a valid identity on the system given a provisioning profile."""
  mpf = _parse_provisioning_profile(provisioning_profile_path)
  ids_codesign = set(_find_codesign_identities())
  for id_mpf in _get_identities_from_provisioning_profile(mpf):
    if id_mpf in ids_codesign:
      return id_mpf


def _get_identities_from_provisioning_profile(provisioning_profile):
  """Iterates through all the identities in a provisioning profile, lazily."""
  for identity in provisioning_profile['DeveloperCertificates']:
    if not isinstance(identity, bytes):
      # Old versions of plistlib return the deprecated plistlib.Data type
      # instead of bytes.
      identity = identity.data
    yield _certificate_fingerprint(identity)


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
      command,
      stdout=subprocess.PIPE,
      stderr=subprocess.PIPE,
      encoding='utf8',
      errors='replace')
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
  plist = plistlib.loads(output)
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


def _copy_provisioning_profile(original_provisioning_profile_path,
                               output_directory, unique_id):
  """Copies a provisioning profile file from an original path to an output directory.

  Args:
    original_provisioning_profile_path: The absolute path to the original
      provisioning profile file. File must exist.
    output_directory: The absolute path to the output directory the profile
      should be placed in, it must already exist.
    unique_id: Unique identifier to use for filename of extracted entitlements.

  Returns:
    The filename relative to output_directory the profile was copied to.
  """
  profile_extension = os.path.splitext(original_provisioning_profile_path)[1]
  dest_provisioning_profile_filename = unique_id + profile_extension
  dest_provision_profile_path = os.path.join(output_directory,
                                             dest_provisioning_profile_filename)
  shutil.copy(original_provisioning_profile_path, dest_provision_profile_path)
  return dest_provisioning_profile_filename


def _extract_provisioning_profile(bundle_path, output_directory, unique_id):
  """Extracts the profile for provided bundle to destination file name.

  Given a bundle_path will extract the profile file to the provided
  output_directory, and return the filename relative to the output_directory
  that the profile has been placed in, or None if no profile exists.

  Args:
    bundle_path: The absolute path to the bundle to extract profile from.
    output_directory: The absolute path to the output directory the profile
      should be placed in, it must already exist.
    unique_id: Unique identifier to use for filename of extracted profile.

  Returns:
    The filename relative to output_directory the profile was placed in,
    or None if there was no profile found.
  """
  embedded_mobileprovision_path = os.path.join(bundle_path,
                                               'embedded.mobileprovision')
  embedded_provisioning_profile_path = os.path.join(
      bundle_path, 'Contents', 'embedded.provisionprofile')
  if os.path.exists(embedded_mobileprovision_path):
    original_provisioning_profile_path = embedded_mobileprovision_path
  elif os.path.exists(embedded_provisioning_profile_path):
    original_provisioning_profile_path = embedded_provisioning_profile_path
  else:
    return None
  return _copy_provisioning_profile(original_provisioning_profile_path,
                                    output_directory, unique_id)


def _generate_manifest(codesign_identity=None,
                       entitlement_file=None,
                       provisioning_profile_file=None,
                       embedded_bundle_manifests=None):
  """Generates the manifest based on provided parameters.

  Given a set of code signing parameters, generates a manifest representation
  suitable for inclusion in a codesigning dossier.

  Args:
    codesign_identity: The string representing the codesigning identity to be
      used for signing this bundle. If None is specified, the identity will be
      inferred from the provisioning profile based on the available identities
      when the `sign` command is given. If None is passed, the provisioning
      profile becomes mandatory.
    entitlement_file: The absolute path to the entitlements file to use for
      signing this bundle, or None if no entitlements need to be included.
    provisioning_profile_file: The absolute path to the provisioning profile to
      embed within the signed bundle, or None if none needs to be embedded.
    embedded_bundle_manifests: Manifests for embedded bundles that should be
      included in this manifest, or None if there are none.

  Returns:
    The manifest contents.
  """
  manifest = {}
  if codesign_identity:
    manifest[_CODESIGN_IDENTITY_KEY] = codesign_identity
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
  packaging_required = False
  if args.zip:
    dossier_directory = tempfile.mkdtemp()
    packaging_required = True
  codesign_path = args.codesign
  if not os.path.exists(dossier_directory):
    os.makedirs(dossier_directory)
  manifest = _manifest_with_dossier_for_bundle(
      os.path.abspath(bundle_path), dossier_directory, codesign_path)
  manifest_file = open(os.path.join(dossier_directory, _MANIFEST_FILENAME), 'w')
  manifest_file.write(json.dumps(manifest, sort_keys=True))
  manifest_file.close()
  if packaging_required:
    _zip_dossier(dossier_directory, args.output)
    shutil.rmtree(dossier_directory)


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
        '--generate-entitlement-der',
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


def _fetch_preferred_signing_identity(manifest,
                                      provisioning_profile_file_path=None):
  """Returns the preferred signing identity.

  Provided a manifest and an optional path to a provisioning profile will
  attempt to resolve what codesigning identity should be used. Will return
  the resolved codesigning identity or None if no identity could be resolved.
  """
  codesign_identity = manifest.get(_CODESIGN_IDENTITY_KEY)
  if not codesign_identity and provisioning_profile_file_path:
    codesign_identity = _find_codesign_identity(provisioning_profile_file_path)
  return codesign_identity


def _sign_bundle_with_manifest(
    root_bundle_path,
    manifest,
    dossier_directory,
    codesign_path,
    override_codesign_identity=None,
    executor=concurrent.futures.ThreadPoolExecutor()):
  """Signing a bundle with a dossier.

  Provided a bundle, dossier path, and the path to the codesign tool, will sign
  a bundle using the dossier's information.

  Args:
    root_bundle_path: The absolute path to the bundle that will be signed.
    manifest: The contents of the manifest in this dossier.
    dossier_directory: Directory of dossier to be used for signing.
    codesign_path: Path to the codesign tool as a string.
    override_codesign_identity: If set, this will override the identity
      specified in the manifest. This is primarily useful when signing an
      embedded bundle, as all bundles must use the same codesigning identity,
      and so lookup logic can be short circuited.
    executor: concurrent.futures.Executor instance to use for concurrent
      codesign invocations.

  Raises:
    SystemExit: if unable to infer codesign identity when not provided.
  """
  codesign_identity = override_codesign_identity
  provisioning_profile_filename = manifest.get(_PROVISIONING_PROFILE_KEY)
  provisioning_profile_file_path = os.path.join(dossier_directory,
                                                provisioning_profile_filename)
  if not codesign_identity:
    codesign_identity = _fetch_preferred_signing_identity(
        manifest, provisioning_profile_file_path)
  if not codesign_identity:
    raise SystemExit(
        'Signing failed - codesigning identity not specified in manifest '
        'and unable to infer identity.')

  entitlements_filename = manifest.get(_ENTITLEMENTS_KEY)
  entitlements_file_path = os.path.join(dossier_directory,
                                        entitlements_filename)

  # submit each embedded manifest to sign concurrently
  codesign_futures = _sign_embedded_bundles_with_manifest(
      manifest, root_bundle_path, dossier_directory, codesign_path,
      codesign_identity, executor)
  _wait_embedded_manifest_futures(codesign_futures)

  if provisioning_profile_file_path:
    _copy_embedded_provisioning_profile(
        provisioning_profile_file_path, root_bundle_path)

  _invoke_codesign(
      codesign_path=codesign_path,
      identity=codesign_identity,
      entitlements=entitlements_file_path,
      force_signing=True,
      disable_timestamp=False,
      full_path_to_sign=root_bundle_path)


def _sign_embedded_bundles_with_manifest(
    manifest,
    root_bundle_path,
    dossier_directory,
    codesign_path,
    codesign_identity,
    executor):
  """Signs embedded bundles concurrently and returns futures list.

  Args:
    manifest: The contents of the manifest in this dossier.
    root_bundle_path: The absolute path to the bundle that will be signed.
    dossier_directory: Directory of dossier to be used for signing.
    codesign_path: Path to the codesign tool as a string.
    codesign_identity: The codesign identity to use for codesigning.
    executor: Asynchronous jobs Executor from concurrent.futures.

  Returns:
    List of asynchronous Future tasks submited to executor.
  """
  codesign_futures = []
  for embedded_manifest in manifest.get(_EMBEDDED_BUNDLE_MANIFESTS_KEY, []):
    embedded_relative_path = embedded_manifest[_EMBEDDED_RELATIVE_PATH_KEY]
    embedded_bundle_path = os.path.join(root_bundle_path,
                                        embedded_relative_path)
    codesign_future = executor.submit(_sign_bundle_with_manifest,
                                      embedded_bundle_path, embedded_manifest,
                                      dossier_directory, codesign_path,
                                      codesign_identity, executor)
    codesign_futures.append(codesign_future)

  return codesign_futures


def _copy_embedded_provisioning_profile(
    provisioning_profile_file_path, root_bundle_path):
  """Copy top-level provisioning profile for an embedded bundle.

  Args:
    provisioning_profile_file_path: The absolute path to the provisioning
                                    profile file.
    root_bundle_path: The absolute path to the bundle that will be signed.
  """
  profile_extension = os.path.splitext(provisioning_profile_file_path)[1]
  profile_filename = 'embedded' + profile_extension
  if profile_extension == '.mobileprovision':
    dest_provisioning_profile_path = os.path.join(root_bundle_path,
                                                  profile_filename)
  else:
    dest_provisioning_profile_path = os.path.join(root_bundle_path,
                                                  'Contents',
                                                  profile_filename)
  if not os.path.exists(dest_provisioning_profile_path):
    shutil.copy(provisioning_profile_file_path, dest_provisioning_profile_path)


def _wait_embedded_manifest_futures(
    future_list):
  """Waits for embedded manifets futures to complete or any to fail.

  Args:
    future_list: List of Future instances to watch for completition or failure.

  Raises:
    SystemExit: if any of the Futures raised an exception.
  """
  done_futures, not_done_futures = concurrent.futures.wait(
      future_list, return_when=concurrent.futures.FIRST_EXCEPTION)
  exceptions = [f.exception() for f in done_futures]

  for not_done_future in not_done_futures:
    not_done_future.cancel()

  if any(exceptions):
    errors = '\n\n'.join(
        f'\t{i}) {repr(e)}' for i, e in enumerate(exceptions, start=1))
    raise SystemExit(
        f'Signing failed - one or more codesign tasks failed:\n{errors}')


def _extract_zipped_dossier(zipped_dossier_path):
  """Unpacks a zipped dossier.

  Args:
    zipped_dossier_path: The path to the zipped dossier.

  Returns:
    The temporary directory storing the unzipped dossier. Caller is
    responsible for deleting this directory when finished using it.

  Raises:
    OSError: If unable to execute the unpacking command.
  """
  dossier_path = tempfile.mkdtemp()
  command = ('/usr/bin/unzip', '-q', zipped_dossier_path, '-d', dossier_path)
  process = subprocess.Popen(
      command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
  _, stderr = process.communicate()
  if process.poll() != 0:
    raise OSError('Fail to unzip dossier at path: %s' % stderr)
  return dossier_path


def _extract_zipped_dossier_if_required(dossier_path):
  """Unpacks a dossier if the provided path is a zipped dossier.

  Args:
    dossier_path: The path to the potentially zipped dossier.

  Returns:
    A DossierDirectory object that has the path to this dossier's directory.
  """
  # Assume if the path is a file instead of a directory we should unzip
  if os.path.isfile(dossier_path):
    return DossierDirectory(_extract_zipped_dossier(dossier_path), True)
  return DossierDirectory(dossier_path, False)


def _zip_dossier(dossier_path, destination_path):
  """Zips a dossier into a file.

  Args:
    dossier_path: The path to the unzipped dossier.
    destination_path: The file path to place the zipped dossier.

  Raises:
    OSError: If unable to execute packaging command
  """
  command = ('/usr/bin/zip', '-r', '-j', '-qX', '-0', destination_path,
             dossier_path)
  process = subprocess.Popen(
      command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
  _, stderr = process.communicate()
  if process.poll() != 0:
    raise OSError('Fail to zip dossier: %s' % stderr)


def _sign_bundle(args):
  """Signing a bundle with a dossier.

  Provided a set of args from sign sub-command, signs a bundle.

  Raises:
    OSError: If bundle or manifest dossier can not be found.
  """
  bundle_path = args.bundle
  codesign_path = args.codesign
  with _extract_zipped_dossier_if_required(args.dossier) as dossier_directory:
    if not os.path.exists(bundle_path):
      raise OSError('Bundle doest not exist at path %s' % bundle_path)
    manifest = _read_manifest_from_dossier(dossier_directory.path)
    _sign_bundle_with_manifest(bundle_path, manifest, dossier_directory.path,
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
  packaging_required = False
  if args.zip:
    dossier_directory = tempfile.mkdtemp()
    packaging_required = True
  if not os.path.exists(dossier_directory):
    os.makedirs(dossier_directory)
  unique_id = str(uuid.uuid4())
  entitlements_filename = None
  if hasattr(args, 'entitlements_file') and args.entitlements_file:
    entitlements_filename = _copy_entitlements_file(args.entitlements_file,
                                                    dossier_directory,
                                                    unique_id)
  provisioning_profile_filename = None
  if hasattr(args, 'provisioning_profile') and args.provisioning_profile:
    provisioning_profile_filename = _copy_provisioning_profile(
        args.provisioning_profile, dossier_directory, unique_id)
  if args.infer_identity and provisioning_profile_filename is None:
    raise SystemExit(
        'A provisioning profile must be provided to infer the signing identity')
  embedded_manifests = []
  if hasattr(args, 'embedded_dossier') and args.embedded_dossier:
    for embedded_dossier in args.embedded_dossier:
      embedded_dossier_bundle_relative_path = embedded_dossier[0]
      with _extract_zipped_dossier_if_required(
          embedded_dossier[1]) as embedded_dossier_directory:
        embedded_dossier_path = embedded_dossier_directory.path
        _merge_dossier_contents(embedded_dossier_path, dossier_directory)
        embedded_manifest = _read_manifest_from_dossier(embedded_dossier_path)
        embedded_manifest[
            _EMBEDDED_RELATIVE_PATH_KEY] = embedded_dossier_bundle_relative_path
        embedded_manifests.append(embedded_manifest)
  codesign_identity = None
  if hasattr(args, 'codesign_identity') and args.codesign_identity:
    codesign_identity = args.codesign_identity
  manifest = _generate_manifest(codesign_identity, entitlements_filename,
                                provisioning_profile_filename,
                                embedded_manifests)
  with open(os.path.join(dossier_directory, _MANIFEST_FILENAME), 'w') as fp:
    fp.write(json.dumps(manifest, sort_keys=True))
  if packaging_required:
    _zip_dossier(dossier_directory, args.output)
    shutil.rmtree(dossier_directory)


def _embed_dossier(args):
  """Embeds an existing dossier into the specified dossier.

  Provided a set of args from generate sub-command, embeds a dossier in a
  dossier.

  Raises:
    OSError: If any of specified dossiers are not found.
  """
  embedded_dossier_bundle_relative_path = args.embedded_relative_artifact_path
  with _extract_zipped_dossier_if_required(
      args.dossier) as dossier_directory, _extract_zipped_dossier_if_required(
          args.embedded_dossier_path) as embedded_dossier_directory:
    embedded_dossier_path = embedded_dossier_directory.path
    dossier_directory_path = dossier_directory.path

    if not os.path.isdir(dossier_directory_path):
      raise OSError('Dossier does not exist at path %s' %
                    dossier_directory_path)
    if not os.path.isdir(embedded_dossier_path):
      raise OSError('Embedded dossier does not exist at path %s' %
                    embedded_dossier_path)
    manifest = _read_manifest_from_dossier(dossier_directory_path)
    embedded_manifest = _read_manifest_from_dossier(embedded_dossier_path)
    _merge_dossier_contents(embedded_dossier_path, dossier_directory_path)
    embedded_manifest[
        _EMBEDDED_RELATIVE_PATH_KEY] = embedded_dossier_bundle_relative_path
    manifest[_EMBEDDED_BUNDLE_MANIFESTS_KEY].append(embedded_manifest)
    with open(os.path.join(dossier_directory_path, _MANIFEST_FILENAME),
              'w') as fp:
      fp.write(json.dumps(manifest, sort_keys=True))
    if dossier_directory.unzipped:
      _zip_dossier(dossier_directory_path, args.dossier)


if __name__ == '__main__':
  args = generate_arg_parser().parse_args()
  sys.exit(args.func(args))
