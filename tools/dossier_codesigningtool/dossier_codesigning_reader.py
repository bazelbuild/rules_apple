#!/usr/bin/env python3

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
r"""A tool to sign bundles with code signing dossiers.

Provides functionality to sign bundles using codesigning dossiers.

To use this script with a combined dossier and bundle zip:

% bazel build //path/to/ios_app \
    --output_groups=combined_dossier_zip \
    --features=disable_legacy_signing \
    --ios_multi_cpus=arm64

% ./dossier_codesigning_reader.py sign \
    --codesign /usr/bin/codesign \
    --output_artifact=~/Desktop/ios_app.ipa \
    bazel-bin/path/to/ios_app_dossier_with_bundle.zip

To use this script with a dossier and ipa:

% bazel build //path/to/ios_app \
    --output_groups=+dossier \
    --features=disable_legacy_signing \
    --ios_multi_cpus=arm64

% ./dossier_codesigning_reader.py sign \
    --codesign /usr/bin/codesign \
    --dossier=bazel-bin/path/to/ios_app_dossier.zip \
    --output_artifact=~/Desktop/ios_app.ipa \
    bazel-bin/path/to/ios_app_dossier_with_bundle.ipa

To use this script with a dossier directly within an extracted ipa's app bundle:

% bazel build //path/to/ios_app \
    --output_groups=+dossier \
    --features=disable_legacy_signing \
    --ios_multi_cpus=arm64

% ditto -x -k bazel-bin/path/to/ios_app_dossier_with_bundle.ipa ~/Desktop/

% ./dossier_codesigning_reader.py sign \
    --codesign /usr/bin/codesign \
    --dossier=bazel-bin/path/to/ios_app_dossier.zip \
    ~/Desktop/Payload/ios_app.app
"""

import argparse
import concurrent.futures
import glob
import io
import json
import os
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import traceback


# LINT.IfChange
_DEFAULT_TIMEOUT = 900


# Redefining execute_and_filter_output here to keep the tool standalone, without
# requiring any Python module support or deps for use in non-Bazel contexts.
def _execute_and_filter_output(cmd_args,
                               filtering=None,
                               custom_env=None,
                               inputstr=None,
                               print_output=False,
                               timeout=_DEFAULT_TIMEOUT):
  """Executes a command with arguments, and suppresses STDERR output.

  Args:
    cmd_args: A list of strings beginning with the command to execute followed
      by its arguments.
    filtering: Optionally specify a filter for stdout/stderr. It must be
      callable and have the following signature:  myFilter(tool_exit_status,
      stdout_string, stderr_string) -> (tool_exit_status, stdout_string,
      stderr_string) The filter can then use the tool's exit status to process
      the output as they wish, returning what ever should be used.
    custom_env: A dictionary of custom environment variables for this session.
    inputstr: Data to send directly to the child process as input.
    print_output: Wheither to always print the output of stdout and stderr for
      this subprocess.
    timeout: Timeout in seconds.

  Returns:
    A tuple consisting of the result of running the command, stdout output from
    the command as a string, and the stderr output from the command as a string.

  Raises:
    CalledProcessError: If the process did not indicate a successful result.
  """
  env = os.environ.copy()
  if custom_env:
    env.update(custom_env)
  proc = subprocess.Popen(
      cmd_args,
      stdin=subprocess.PIPE,
      stdout=subprocess.PIPE,
      stderr=subprocess.PIPE,
      env=env)
  try:
    stdout, stderr = proc.communicate(input=inputstr, timeout=timeout)
  except subprocess.TimeoutExpired:
    # Cleanup suggested by https://docs.python.org/3/library/subprocess.html
    proc.kill()
    stdout, stderr = proc.communicate()

  cmd_result = proc.returncode

  # The invoked tools don't specify what encoding they use, so for lack of a
  # better option, just use utf8 with error replacement. This will replace
  # incorrect utf8 byte sequences with '?', which avoids UnicodeDecodeError
  # from raising.
  #
  # NOTE: Not using `encoding` and `errors` on `subprocess.Popen` as that also
  # impacts stdin. This way the callers can control sending `bytes` or `str`
  # thru as input.
  stdout = stdout.decode('utf8', 'replace')
  stderr = stderr.decode('utf8', 'replace')

  if (stdout or stderr) and filtering:
    if not callable(filtering):
      raise TypeError('\'filtering\' must be callable.')
    cmd_result, stdout, stderr = filtering(cmd_result, stdout, stderr)

  if cmd_result != 0:
    # print the stdout and stderr, as the exception won't print it.
    print('ERROR:{stdout}\n\n{stderr}'.format(stdout=stdout, stderr=stderr))
    raise subprocess.CalledProcessError(proc.returncode, cmd_args)
  elif print_output:
    # The default encoding of stdout/stderr is 'ascii', so we need to reopen the
    # streams in utf8 mode since some messages from Apple's tools use characters
    # like curly quotes.
    def _ensure_utf8_encoding(s):
      # Tests might hook sys.stdout/sys.stderr, so be defensive.
      if (
          getattr(s, 'encoding', 'utf8') != 'utf8'
          and callable(getattr(s, 'reconfigure', None))
          and isinstance(s, io.TextIOWrapper)
      ):
        s.reconfigure(encoding='utf8')

    if stdout:
      _ensure_utf8_encoding(sys.stdout)
      sys.stdout.write(stdout)
    if stderr:
      _ensure_utf8_encoding(sys.stderr)
      sys.stderr.write(stderr)

  return stdout
# LINT.ThenChange(../wrapper_common/execute.py)


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

  def __exit__(self, exception_type, exception_value, traceback_value):
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
CODESIGN_IDENTITY_KEY = 'codesign_identity'
ENTITLEMENTS_KEY = 'entitlements'
PROVISIONING_PROFILE_KEY = 'provisioning_profile'
EMBEDDED_BUNDLE_MANIFESTS_KEY = 'embedded_bundle_manifests'
EMBEDDED_RELATIVE_PATH_KEY = 'embedded_relative_path'


# Regex which matches the 40 char hash
_SECURITY_FIND_IDENTITY_OUTPUT_REGEX = re.compile(r'(?P<hash>[A-F0-9]{40})')

# The filename for a manifest within a manifest
MANIFEST_FILENAME = 'manifest.json'

# All optional ipa subdirectories by Apple; 'Payload' is required of all IPAs.
IPA_OPTIONAL_SUBDIRS = [
    'SwiftSupport',
    'WatchKitSupport2',
    'MessagesApplicationExtensionSupport',
    'BCSymbolMaps',
    'Symbols',
]

VALID_INPUT_EXTENSIONS = frozenset(['.zip', '.app', '.ipa'])


def generate_arg_parser():
  """Generates an argument parser for this tool."""

  parser = argparse.ArgumentParser(
      description='Tool for signing iOS bundles using dossiers.',
      fromfile_prefix_chars='@')
  subparsers = parser.add_subparsers(help='Sub-commands')

  sign_parser = subparsers.add_parser(
      'sign', help='Sign an Apple bundle using a dossier.')
  sign_parser.add_argument(
      '--dossier',
      help='Path to input dossier location. Can be a directory or .zip file.')
  sign_parser.add_argument(
      '--codesign', required=True, type=str, help='Path to codesign binary')
  sign_parser.add_argument(
      '--allow_entitlement',
      action='append',
      type=str,
      help='Entitlement to allow. If none are specified, the entitlements found'
      ' in the dossier will be used without additional processing')
  sign_parser.add_argument(
      'input_artifact',
      help='Path to the bundle, ipa or combined zip.')
  sign_parser.add_argument(
      '--output_artifact',
      help='''
If the input artifact is an ipa or combined zip, placed the signed result in the
given output artifact specified location. Required for ipa or combined zip
inputs.
''')
  sign_parser.add_argument(
      '--keychain',
      help='''
If specified, during signing, only search for the signing identity in the
keychain file specified. This is equivalent to the --keychain argument on
/usr/bin/codesign itself.
''')
  sign_parser.set_defaults(func=_sign_bundle)

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


def _generate_sha1(data):
  """Returns the SHA1 of the data as a string in uppercase."""
  openssl_command = ['openssl', 'sha1']
  cmd_output = _execute_and_filter_output(openssl_command, inputstr=data)
  return cmd_output.upper().strip()


def _find_codesign_identities(signing_keychain=None):
  """Finds the code signing identities in a specified keychain."""
  ids = {}
  execute_command = [
      'security',
      'find-identity',
      '-v',
      '-p',
      'codesigning',
  ]
  if signing_keychain:
    execute_command.extend([signing_keychain])
  output = _execute_and_filter_output(execute_command)
  output = output.strip()
  for line in output.splitlines():
    m = _SECURITY_FIND_IDENTITY_OUTPUT_REGEX.search(line)
    if m:
      ids[m.groupdict()['hash']] = line
  return ids


def _resolve_codesign_identity(
    provisioning_profile_path, codesign_identity, signing_keychain
):
  """Finds the best identity on the system given a profile and identity."""
  mpf = _parse_provisioning_profile(provisioning_profile_path)
  ids_codesign = _find_codesign_identities(signing_keychain)
  best_codesign_identity = codesign_identity
  for id_mpf in _get_identities_from_provisioning_profile(mpf):
    if id_mpf in ids_codesign.keys():
      best_codesign_identity = id_mpf
      # Return early if the specified codesign_identity matches a valid entity.
      if codesign_identity in ids_codesign[id_mpf]:
        break
  return best_codesign_identity


def _get_identities_from_provisioning_profile(provisioning_profile):
  """Iterates through all the identities in a provisioning profile, lazily."""
  for identity in provisioning_profile['DeveloperCertificates']:
    if not isinstance(identity, bytes):
      # Old versions of plistlib return the deprecated plistlib.Data type
      # instead of bytes.
      identity = identity.data
    yield _generate_sha1(identity)


def _find_codesign_allocate():
  cmd = ['xcrun', '--find', 'codesign_allocate']
  stdout = _execute_and_filter_output(cmd)
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
  return (exit_status, _filter_codesign_output(codesign_stdout),
          _filter_codesign_output(codesign_stderr))


def _invoke_codesign(codesign_path, identity, entitlements_path, force_signing,
                     disable_timestamp, full_path_to_sign, signing_keychain):
  """Invokes the codesign tool on the given path to sign.

  Args:
    codesign_path: Path to the codesign tool as a string.
    identity: The unique identifier string to identify code signatures.
    entitlements_path: Path to the file with entitlement data. Optional.
    force_signing: If true, replaces any existing signature on the path given.
    disable_timestamp: If true, disables the use of timestamp services.
    full_path_to_sign: Path to the bundle or binary to code sign as a string.
    signing_keychain: If not None, this will only search for the signing
      identity in the keychain file specified, forwarding the path directly to
      the /usr/bin/codesign invocation via its --keychain argument.
  """
  cmd = [codesign_path, '-v', '--sign', identity]
  if entitlements_path:
    cmd.extend([
        '--entitlements',
        entitlements_path,
        '--generate-entitlement-der',
    ])
  if force_signing:
    cmd.append('--force')
  if disable_timestamp:
    cmd.append('--timestamp=none')
  if signing_keychain:
    cmd.extend([
        '--keychain',
        signing_keychain,
    ])
  cmd.append(full_path_to_sign)

  # Just like Xcode, ensure CODESIGN_ALLOCATE is set to point to the correct
  # version.
  custom_env = {'CODESIGN_ALLOCATE': _find_codesign_allocate()}
  _execute_and_filter_output(
      cmd,
      filtering=_filter_codesign_tool_output,
      custom_env=custom_env,
      print_output=True)


def _fetch_preferred_signing_identity(
    manifest, provisioning_profile_file_path, signing_keychain
):
  """Returns the preferred signing identity.

  Args:
    manifest: The contents of the manifest in this dossier.
    provisioning_profile_file_path: Directory of the provisioning profile to be
      used for signing.
    signing_keychain: If not None, this will only search for the signing
      identity in the keychain file specified, forwarding the path directly to
      the /usr/bin/codesign invocation via its --keychain argument.

  Returns:
    A string representing the code signing identity or None if one could not be
    found.

  Provided a manifest and a path to a provisioning profile attempts to resolve
  what codesigning identity should be used. Will return the resolved codesigning
  identity or None if no identity could be resolved.
  """
  codesign_identity = manifest.get(CODESIGN_IDENTITY_KEY)

  # An identity of '-' is used for simulator signing which can't be validated.
  if codesign_identity != '-':
    codesign_identity = _resolve_codesign_identity(
        provisioning_profile_file_path, codesign_identity, signing_keychain
    )
  return codesign_identity


def _generate_entitlements_for_signing(*, src, allowed_entitlements, dest):
  """Generate entitlements based on the filtered set of allowed entitlements.

  Args:
    src: A path to the entitlements to source for dossier signing.
    allowed_entitlements: A list of strings indicating keys that are valid for
      entitlements. Only the strings listed here will be transferred to the
      generated entitlements.
    dest: A path to indicate where the generated entitlements should be placed.
  """

  try:
    with open(src, 'rb') as f:
      original_entitlements = plistlib.load(f)
  except plistlib.InvalidFileException as exc:
    orig_traceback = traceback.format_exc()
    raise OSError('Unable to read override entitlements: %s\n'
                  'Original Exception:\n%s' % (src, orig_traceback)) from exc

  new_entitlements = {}
  for key in original_entitlements:
    if key in allowed_entitlements:
      new_entitlements[key] = original_entitlements[key]
    else:
      print('WARNING: Invalid entitlement key found: %s' % key)

  # log the entitlements for debug purpose
  print('Dumping entitlements to %s: %s' % (dest, new_entitlements))
  with open(dest, 'wb') as f:
    plistlib.dump(new_entitlements, f)


def _extract_archive(*, app_bundle_subdir, working_dir, unsigned_archive_path):
  """Create a temp directory and extract unsigned IPA archive there.

  Args:
    app_bundle_subdir: String, the path relative to the working directory to the
      directory with the .app within the archive which will be returned.
    working_dir: String, the path to unzip the archive file into.
    unsigned_archive_path: String, the full path to a unsigned archive.

  Returns:
    extracted_bundle: String, the path to extracted bundle, which is
      {working_dir}/{app_bundle_subdir}/*.app

  Raises:
    OSError: when app bundle is not found in extracted archive.
  """
  subprocess.check_call(
      ['ditto', '-x', '-k', unsigned_archive_path, working_dir])

  extracted_bundles = glob.glob(
      os.path.join(working_dir, app_bundle_subdir, '*.app'))
  if len(extracted_bundles) != 1:
    raise OSError(
        f'Input with IPA contents broken, {len(extracted_bundles)} apps were'
        ' found in the bundle; there must only be one.'
    )

  return extracted_bundles[0]


def _package_ipa(*, app_bundle_subdir, working_dir, output_ipa):
  """Package signed bundle into the target location.

  Args:
    app_bundle_subdir: String, the path relative to the working
      directory to the directory with the .app within the archive which will be
      returned.
    working_dir: String, the path to the folder which contains contents suitable
      for an unzipped IPA archive.
    output_ipa: String, a path to where the zipped IPA file should be placed.

  Raises:
    OSError: If a recognized 'Payload' sub directory could not be found.
  """
  # Expand a user path if specified, resolve symlinks if necessary.
  output_ipa_fullpath = os.path.realpath(os.path.expanduser(output_ipa))
  print('Archiving IPA package %s.' % output_ipa_fullpath)
  # Check that Payload exists; if not, then it can be assumed that we do not
  # have the means to form a valid IPA.
  ipa_payload_path = os.path.join(working_dir, app_bundle_subdir)
  if not os.path.exists(ipa_payload_path):
    raise OSError(
        f'Could not find a Payload to build a valid IPA in: {ipa_payload_path}'
    )
  ipa_source_dirs = [ipa_payload_path]
  for ipa_optional_subdir in IPA_OPTIONAL_SUBDIRS:
    # Check that the optional sub directory exists within the working directory
    # before adding it to the ditto cmd, to avoid noisy diagnostic messaging
    # from ditto's stderr output.
    ipa_subdir_path = os.path.join(working_dir, ipa_optional_subdir)
    if os.path.exists(ipa_subdir_path):
      ipa_source_dirs.append(ipa_subdir_path)
  subprocess.check_call(
      ['ditto', '-c', '-k', '--norsrc', '--noextattr', '--keepParent'] +
      ipa_source_dirs + [output_ipa_fullpath])


def _sign_bundle_with_manifest(
    root_bundle_path,
    manifest,
    dossier_directory_path,
    codesign_path,
    allowed_entitlements,
    signing_keychain,
    override_codesign_identity=None,
    executor=concurrent.futures.ThreadPoolExecutor()):
  """Signs a bundle with a dossier.

  Provided a bundle, dossier path, and the path to the codesign tool, will sign
  a bundle using the dossier's information.

  Args:
    root_bundle_path: The absolute path to the bundle that will be signed.
    manifest: The contents of the manifest in this dossier.
    dossier_directory_path: Directory of dossier to be used for signing.
    codesign_path: Path to the codesign tool as a string.
    allowed_entitlements: A list of strings indicating keys that are valid for
      entitlements. If not None, only the strings listed here will be
      transferred to the generated entitlements. If None, the entitlements found
      with the dossier will be used directly for code signing.
    signing_keychain: If not None, this will first search for the signing
      identity in the keychain file specified, forwarding the path directly to
      the /usr/bin/codesign invocation via its --keychain argument.
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
  provisioning_profile_filename = manifest.get(PROVISIONING_PROFILE_KEY)
  provisioning_profile_file_path = os.path.join(dossier_directory_path,
                                                provisioning_profile_filename)
  if not codesign_identity:
    codesign_identity = _fetch_preferred_signing_identity(
        manifest, provisioning_profile_file_path, signing_keychain
    )
  if not codesign_identity:
    raise SystemExit(
        'Signing failed - codesigning identity not specified in manifest '
        'and unable to infer identity.')

  entitlements_filename = manifest.get(ENTITLEMENTS_KEY)
  entitlements_source_path = os.path.join(dossier_directory_path,
                                          entitlements_filename)

  with tempfile.TemporaryDirectory() as working_dir:
    print('Working dir for temp signing artifacts created: %s' % working_dir)
    if allowed_entitlements:
      _, entitlements_for_signing_path = tempfile.mkstemp(
          dir=working_dir, suffix='.plist')

      _generate_entitlements_for_signing(
          src=entitlements_source_path,
          allowed_entitlements=allowed_entitlements,
          dest=entitlements_for_signing_path)
    else:
      entitlements_for_signing_path = entitlements_source_path

    # submit each embedded manifest to sign concurrently
    codesign_futures = _sign_embedded_bundles_with_manifest(
        manifest, root_bundle_path, dossier_directory_path, codesign_path,
        allowed_entitlements, signing_keychain, codesign_identity, executor)
    _wait_embedded_manifest_futures(codesign_futures)

    if provisioning_profile_file_path:
      _copy_embedded_provisioning_profile(
          provisioning_profile_file_path, root_bundle_path)

    print('Signing bundle at: %s' % root_bundle_path)
    _invoke_codesign(
        codesign_path=codesign_path,
        identity=codesign_identity,
        entitlements_path=entitlements_for_signing_path,
        force_signing=True,
        disable_timestamp=False,
        full_path_to_sign=root_bundle_path,
        signing_keychain=signing_keychain)


def _sign_embedded_bundles_with_manifest(
    manifest,
    root_bundle_path,
    dossier_directory_path,
    codesign_path,
    allowed_entitlements,
    signing_keychain,
    codesign_identity,
    executor):
  """Signs embedded bundles concurrently and returns futures list.

  Args:
    manifest: The contents of the manifest in this dossier.
    root_bundle_path: The absolute path to the bundle that will be signed.
    dossier_directory_path: Directory of dossier to be used for signing.
    codesign_path: Path to the codesign tool as a string.
    allowed_entitlements: A list of strings indicating keys that are valid for
      entitlements. If not None, only the strings listed here will be
      transferred to the generated entitlements. If None, the entitlements found
      with the dossier will be used directly for code signing.
    signing_keychain: If not None, this will only search for the signing
      identity in the keychain file specified, forwarding the path directly to
      the /usr/bin/codesign invocation via its --keychain argument.
    codesign_identity: The codesign identity to use for codesigning.
    executor: Asynchronous jobs Executor from concurrent.futures.

  Returns:
    List of asynchronous Future tasks submited to executor.
  """
  codesign_futures = []
  for embedded_manifest in manifest.get(EMBEDDED_BUNDLE_MANIFESTS_KEY, []):
    embedded_relative_path = embedded_manifest[EMBEDDED_RELATIVE_PATH_KEY]
    embedded_bundle_path = os.path.join(root_bundle_path,
                                        embedded_relative_path)
    codesign_future = executor.submit(_sign_bundle_with_manifest,
                                      embedded_bundle_path, embedded_manifest,
                                      dossier_directory_path, codesign_path,
                                      allowed_entitlements, signing_keychain,
                                      codesign_identity, executor)
    codesign_futures.append(codesign_future)

  return codesign_futures


def _copy_embedded_provisioning_profile(
    provisioning_profile_file_path, root_bundle_path):
  """Copies the top-level provisioning profile for an embedded bundle.

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


def extract_zipped_dossier_if_required(dossier_path):
  """Unpacks a dossier if the provided path is a zipped dossier.

  Args:
    dossier_path: The path to the potentially zipped dossier.

  Returns:
    A DossierDirectory object that has the path to this dossier's directory.

  Raises:
    OSError: if specified dossier_path does not exists.
  """
  # Assume if the path is a file instead of a directory we should unzip
  if os.path.isfile(dossier_path):
    return DossierDirectory(_extract_zipped_dossier(dossier_path), True)
  elif os.path.isdir(dossier_path):
    return DossierDirectory(dossier_path, False)
  else:
    raise OSError('Dossier does not exist at path %s' % dossier_path)


def _check_common_archived_bundle_args(*, output_artifact):
  """Raises an error if the argument usage does not match the archived bundle.

  Args:
    output_artifact: String, a path to where the signed artifact should be
      placed.

  Raises:
    OSError: If the archived bundle-relevant arguments are invalid.
  """
  if not output_artifact:
    raise OSError(
        'Missing output_artifact, a requirement for signing archives.'
    )
  if os.path.splitext(output_artifact)[1] != '.ipa':
    raise OSError(
        '--output_artifact must have an .ipa extension if the input is an '
        'archive. Received: {}.'.format(output_artifact)
    )


def _sign_archived_bundle(
    *,
    allowed_entitlements,
    app_bundle_subdir,
    codesign_path,
    dossier_directory_path,
    output_ipa,
    signing_keychain,
    working_dir,
    unsigned_archive_path):
  """Signs the bundle and packages it as an IPA to output_artifact.

  Args:
    allowed_entitlements: A list of strings indicating keys that are valid for
      entitlements. Only the strings listed here will be transferred to the
      generated entitlements.
    app_bundle_subdir: String, the path relative to the working
    codesign_path: Path to the codesign tool as a string.
    dossier_directory_path: Directory of dossier to be used for signing.
    output_ipa: String, a path to where the zipped IPA file should be placed.
    signing_keychain: If not None, this will only search for the signing
      identity in the keychain file specified, forwarding the path directly to
      the /usr/bin/codesign invocation via its --keychain argument.
    working_dir: String, the path to unzip the archive file into.
    unsigned_archive_path: String, the full path to a unsigned archive.
  """
  extracted_bundle = _extract_archive(
      app_bundle_subdir=app_bundle_subdir,
      working_dir=working_dir,
      unsigned_archive_path=unsigned_archive_path,
  )
  manifest = read_manifest_from_dossier(dossier_directory_path)
  _sign_bundle_with_manifest(extracted_bundle, manifest,
                             dossier_directory_path, codesign_path,
                             allowed_entitlements, signing_keychain)
  _package_ipa(
      app_bundle_subdir=app_bundle_subdir,
      working_dir=working_dir,
      output_ipa=output_ipa,
  )
  print('Output artifact is: %s' % output_ipa)


def _sign_bundle(parsed_args):
  """Signs a bundle with a dossier.

  Provided a set of args from sign sub-command, signs a bundle.

  Args:
    parsed_args: A struct of arguments required for signing that were generated
      from an instance of argparse.ArgumentParser(...).

  Raises:
    OSError: If the arguments do not fulfill the necessary requirements for the
      tasks at hand, or requested functionality has not yet been implemented.
  """
  # Resolve the full input path, expanding user paths and resolving symlinks.
  input_fullpath = os.path.realpath(os.path.expanduser(
      parsed_args.input_artifact))
  codesign_path = parsed_args.codesign
  allowed_entitlements = parsed_args.allow_entitlement
  signing_keychain = parsed_args.keychain
  output_artifact = parsed_args.output_artifact

  if not os.path.exists(input_fullpath):
    raise OSError('Specified input does not exist at path %s' % input_fullpath)

  # Normalize the path (turning a potential .app/ into .app) then splitext to
  # get a proper suffix for comparison.
  input_path_suffix = os.path.splitext(os.path.normpath(input_fullpath))[1]
  if input_path_suffix not in VALID_INPUT_EXTENSIONS:
    raise OSError(
        'Specified input path does not have a recognized extension.'
        ' Expected one of: {}.'.format(', '.join(VALID_INPUT_EXTENSIONS))
    )
  if input_path_suffix == '.zip':
    if parsed_args.dossier:
      raise OSError(
          'The --dossier arg is unused for combined zip signing. Please remove'
          ' it from your invocation.'
      )
    _check_common_archived_bundle_args(
        output_artifact=output_artifact,
    )
    with tempfile.TemporaryDirectory() as working_dir:
      print(
          'Working directory for combined zip extraction created: %s'
          % working_dir
      )
      dossier_directory_path = os.path.join(working_dir, 'dossier')
      _sign_archived_bundle(
          allowed_entitlements=allowed_entitlements,
          app_bundle_subdir='bundle/Payload',
          codesign_path=codesign_path,
          dossier_directory_path=dossier_directory_path,
          output_ipa=output_artifact,
          signing_keychain=signing_keychain,
          working_dir=working_dir,
          unsigned_archive_path=input_fullpath,
      )
  else:
    with extract_zipped_dossier_if_required(
        parsed_args.dossier
    ) as dossier_directory, \
        tempfile.TemporaryDirectory() as working_dir:
      if input_path_suffix == '.app':
        if output_artifact:
          raise OSError(
              '--output_artifact support for app bundles has not yet been'
              ' implemented!'
          )
        manifest = read_manifest_from_dossier(dossier_directory.path)
        _sign_bundle_with_manifest(input_fullpath, manifest,
                                   dossier_directory.path, codesign_path,
                                   allowed_entitlements, signing_keychain)
      elif input_path_suffix == '.ipa':
        _check_common_archived_bundle_args(
            output_artifact=output_artifact,
        )
        print(
            'Working directory for ipa extraction is: %s' % working_dir
        )
        _sign_archived_bundle(
            allowed_entitlements=allowed_entitlements,
            app_bundle_subdir='Payload',
            codesign_path=codesign_path,
            dossier_directory_path=dossier_directory.path,
            output_ipa=output_artifact,
            signing_keychain=signing_keychain,
            working_dir=working_dir,
            unsigned_archive_path=input_fullpath,
        )


def read_manifest_from_dossier(dossier_directory_path):
  """Reads the manifest from a dossier file.

  Args:
    dossier_directory_path: Directory of dossier to be used for signing.

  Raises:
    OSError: If bundle or manifest dossier can not be found.

  Returns:
    The contents of the manifest file as a dictionary.
  """
  manifest_file_path = os.path.join(dossier_directory_path, MANIFEST_FILENAME)
  if not os.path.exists(manifest_file_path):
    raise OSError('Dossier doest not exist at path %s' % dossier_directory_path)
  with open(manifest_file_path, 'r') as fp:
    return json.load(fp)


def _main():
  """Main method intended to route top level command line arguments."""
  parser = generate_arg_parser()
  args = parser.parse_args()
  if not vars(args):
    print('No additional args for dossier signing were found.')
    parser.print_help()
    sys.exit(1)
  sys.exit(args.func(args))


if __name__ == '__main__':
  _main()
