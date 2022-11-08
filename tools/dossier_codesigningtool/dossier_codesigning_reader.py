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
"""A tool to sign bundles with code signing dossiers.

Provides functionality to sign bundles using codesigning dossiers.
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
      if (getattr(s, 'encoding', 'utf8') != 'utf8' and
          callable(getattr(s, 'reconfigure', None))):
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
CODESIGN_IDENTITY_KEY = 'codesign_identity'
ENTITLEMENTS_KEY = 'entitlements'
PROVISIONING_PROFILE_KEY = 'provisioning_profile'
EMBEDDED_BUNDLE_MANIFESTS_KEY = 'embedded_bundle_manifests'
EMBEDDED_RELATIVE_PATH_KEY = 'embedded_relative_path'

# The filename for a manifest within a manifest
MANIFEST_FILENAME = 'manifest.json'


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
  sign_parser.add_argument('bundle', help='Path to the bundle')
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
  fingerprint = _execute_and_filter_output(openssl_command, inputstr=identity)
  fingerprint = fingerprint.strip()
  fingerprint = fingerprint.replace('SHA1 Fingerprint=', '')
  fingerprint = fingerprint.replace(':', '')
  return fingerprint


def _find_codesign_identities(identity=None):
  """Finds the code signing identities on the current system."""
  ids = []
  execute_command = [
      'security',
      'find-identity',
      '-v',
      '-p',
      'codesigning',
  ]
  output = _execute_and_filter_output(execute_command)
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
      identifier = groups['hash']
      ids.append(identifier)
  return ids


def _find_codesign_identity(provisioning_profile_path):
  """Finds a valid identity on the system given a provisioning profile."""
  mpf = _parse_provisioning_profile(provisioning_profile_path)
  ids_codesign = set(_find_codesign_identities())
  for id_mpf in _get_identities_from_provisioning_profile(mpf):
    if id_mpf in ids_codesign:
      return id_mpf
  return None


def _get_identities_from_provisioning_profile(provisioning_profile):
  """Iterates through all the identities in a provisioning profile, lazily."""
  for identity in provisioning_profile['DeveloperCertificates']:
    if not isinstance(identity, bytes):
      # Old versions of plistlib return the deprecated plistlib.Data type
      # instead of bytes.
      identity = identity.data
    yield _certificate_fingerprint(identity)


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
  _execute_and_filter_output(
      cmd,
      filtering=_filter_codesign_tool_output,
      custom_env=custom_env,
      print_output=True)


def _fetch_preferred_signing_identity(manifest,
                                      provisioning_profile_file_path=None):
  """Returns the preferred signing identity.

  Args:
    manifest: The contents of the manifest in this dossier.
    provisioning_profile_file_path: Directory of the provisioning profile to be
      used for signing.

  Returns:
    A string representing the code signing identity or None if one could not be
    found.

  Provided a manifest and an optional path to a provisioning profile will
  attempt to resolve what codesigning identity should be used. Will return
  the resolved codesigning identity or None if no identity could be resolved.
  """
  codesign_identity = manifest.get(CODESIGN_IDENTITY_KEY)
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
  """Signs a bundle with a dossier.

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
  provisioning_profile_filename = manifest.get(PROVISIONING_PROFILE_KEY)
  provisioning_profile_file_path = os.path.join(dossier_directory,
                                                provisioning_profile_filename)
  if not codesign_identity:
    codesign_identity = _fetch_preferred_signing_identity(
        manifest, provisioning_profile_file_path)
  if not codesign_identity:
    raise SystemExit(
        'Signing failed - codesigning identity not specified in manifest '
        'and unable to infer identity.')

  entitlements_filename = manifest.get(ENTITLEMENTS_KEY)
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
  for embedded_manifest in manifest.get(EMBEDDED_BUNDLE_MANIFESTS_KEY, []):
    embedded_relative_path = embedded_manifest[EMBEDDED_RELATIVE_PATH_KEY]
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
  """
  # Assume if the path is a file instead of a directory we should unzip
  if os.path.isfile(dossier_path):
    return DossierDirectory(_extract_zipped_dossier(dossier_path), True)
  return DossierDirectory(dossier_path, False)


def _sign_bundle(args):
  """Signs a bundle with a dossier.

  Provided a set of args from sign sub-command, signs a bundle.

  Args:
    args: A struct of arguments required for signing that were generated from
      an instance of argparse.ArgumentParser(...).

  Raises:
    OSError: If bundle or manifest dossier can not be found.
  """
  bundle_path = args.bundle
  codesign_path = args.codesign
  with extract_zipped_dossier_if_required(args.dossier) as dossier_directory:
    if not os.path.exists(bundle_path):
      raise OSError('Bundle doest not exist at path %s' % bundle_path)
    manifest = read_manifest_from_dossier(dossier_directory.path)
    _sign_bundle_with_manifest(bundle_path, manifest, dossier_directory.path,
                               codesign_path)


def read_manifest_from_dossier(dossier_directory):
  """Reads the manifest from a dossier file.

  Args:
    dossier_directory: The path to the dossier.

  Raises:
    OSError: If bundle or manifest dossier can not be found.

  Returns:
    The contents of the manifest file as a dictionary.
  """
  manifest_file_path = os.path.join(dossier_directory, MANIFEST_FILENAME)
  if not os.path.exists(manifest_file_path):
    raise OSError('Dossier doest not exist at path %s' % dossier_directory)
  with open(manifest_file_path, 'r') as fp:
    return json.load(fp)


if __name__ == '__main__':
  args = generate_arg_parser().parse_args()
  sys.exit(args.func(args))
