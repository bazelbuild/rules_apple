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

"""Plist manipulation for Apple packaging rules.

The "defaults" tool provided with OS X is somewhat satisfactory for reading and
writing single values in a plist, but merging whole plists with conflict
detection is not as easy.

This script takes a single argument that points to a file containing the JSON
representation of a "control" structure (similar to the PlMerge tool, which
takes a binary protocol buffer). This control structure is a dictionary with
the following keys:

  plists: A list of plists that will be merged. The items in this list may be
      strings (which are interpreted as paths), readable file-like objects
      containing XML-formatted plist data (for testing), or dictionaries that
      are treated as inlined plists. Key-value pairs within the plists in this
      list must not conflict (i.e., the same key must not have different values
      in different plists) or the tool will raise an error.
  forced_plists: A list of plists that will be merged after those in "plists".
      Unlike those, collisions between key-value pairs in these plists do not
      raise an error; they replace any values from the originals instead. If
      multiple plists have the same key, the last one in this list is the one
      that will be kept.
  output: A string indicating the path to where the merged plist will be
      written, or a writable file-like object (for testing).
  binary: If true, the output plist file will be written in binary format;
      otherwise, it will be written in XML format. This property is ignored if
      |output| is not a path.
  info_plist_options: A dictionary containing options specific to Info.plist
      files. Omit this key if you are merging or converting general plists
      (such as entitlements or other files). See below for more details.
  target: The target name, used for warning/error messages.

The info_plist_options dictionary can contain the following keys:

  apply_default_version: If True, the tool will set CFBundleVersion and
      CFBundleShortVersionString to be "1.0" if values are not already present
      in the output plist.
  executable: The name of the executable that will be written into the
      CFBundleExecutable key of the final plist, and will also be used in
      ${EXECUTABLE_NAME} and ${PRODUCT_NAME} substitutions.
  bundle_name: The bundle name (that is, the executable name and extension)
      that is used in the ${BUNDLE_NAME} substitution.
  bundle_id: The bundle identifier that will be written into the
      CFBundleIdentifier key of the final plist and will be used in the
      ${PRODUCT_BUNDLE_IDENTIFIER} substitution.
  pkginfo: If present, a string that denotes the path to a PkgInfo file that
      should be created from the CFBundlePackageType and CFBundleSignature keys
      in the final merged plist. (For testing purposes, this may also be a
      writable file-like object.)
  version_file: If present, a string that denotes the path to the version file
      propagated by an `AppleBundleVersionInfo` provider, which contains values
      that will be used for the version keys in the Info.plist.
  child_plists: If present, a dictionary containing plists that will be
      compared against the final compiled plist for consistency. The keys of
      the dictionary are the labels of the targets to which the associated
      plists belong. See below for the details of how these are validated.

If info_plist_options is present, validation will be performed on the output
file after merging is complete. If any of the following conditions are not
satisfied, an error will be raised:

  * The CFBundleIdentifier must be present and be formatted as a valid bundle
    identifier.
  * The CFBundleIdentifier and CFBundleShortVersionString values of the
    output file will be compared to the child plists for consistency. Child
    plists are expected to have the same bundle version string as the parent
    and should have bundle IDs that are prefixed by the bundle ID of the
    parent.
"""

from collections import OrderedDict
import json
import plistlib
import re
import subprocess
import sys

MISMATCHED_BUNDLE_ID_MSG = ('The CFBundleIdentifier of the merged Info.plists '
                            '"%s" must be equal to the bundle_id argument '
                            '"%s".')

CHILD_BUNDLE_ID_MISMATCH_MSG = ('The CFBundleIdentifier of the child target '
                                '"%s" should have "%s" as its prefix, but '
                                'found "%s".')

CHILD_BUNDLE_VERSION_MISMATCH_MSG = ('The CFBundleShortVersionString of the '
                                     'child target "%s" should be the same as '
                                     'its parent\'s version string "%s", but '
                                     'found "%s".')


class PlistConflictError(ValueError):
  """Raised when conflicting values are found for a key.

  This error is raised when two plists being merged have different values for
  the same key. The "key" attribute has the name of the key; the "value1" and
  "value2" attributes have the values that were encountered.
  """

  def __init__(self, key, value1, value2):
    """Initializes an error with the given key and values.

    Args:
      key: The key that had conflicting values.
      value1: One of the conflicting values.
      value2: One of the conflicting values.
    """
    self.key = key
    self.value1 = value1
    self.value2 = value2
    ValueError.__init__(self, (
        'Found key %r in two plists with different values: %r != %r') % (
            key, value1, value2))


class PlistTool(object):
  """Implements the core functionality of the plist tool."""

  def __init__(self, control):
    """Initializes PlistTool with the given control options.

    Args:
      control: The dictionary of options used to control the tool. Please see
          the moduledoc for a description of the format of this dictionary.
    Raises:
      ValueError: If the bundle_id parameter is missing.
    """
    self._control = control

    # The dictionary of substitutions to apply, where the key is the name to be
    # replaced when enclosed by ${...} or $(...) in a plist value, and the
    # value is the string to substitute.
    self._substitutions = {}

    info_plist_options = self._control.get('info_plist_options')
    if info_plist_options:
      executable = info_plist_options.get('executable')
      if executable:
        self._substitutions['EXECUTABLE_NAME'] = executable
        self._substitutions['PRODUCT_NAME'] = executable

      bundle_name = info_plist_options.get('bundle_name')
      if bundle_name:
        self._substitutions['BUNDLE_NAME'] = bundle_name

      bundle_id = info_plist_options.get('bundle_id')
      if bundle_id:
        self._substitutions['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id

  def run(self):
    """Performs the operations requested by the control struct."""
    if not self._control.get('plists'):
      raise ValueError('No input plists specified.')

    if not self._control.get('output'):
      raise ValueError('No output file specified.')

    out_plist = {}

    for p in self._control['plists']:
      plist = self._get_plist_dict(p)
      self.merge_dictionaries(plist, out_plist)

    forced_plists = self._control.get('forced_plists', [])
    for p in forced_plists:
      plist = self._get_plist_dict(p)
      self.merge_dictionaries(plist, out_plist, override_collisions=True)

    info_plist_options = self._control.get('info_plist_options')
    if info_plist_options:
      self._perform_info_plist_operations(out_plist, info_plist_options,
                                          self._control.get('target'))

    self._write_plist(out_plist)

  def merge_dictionaries(self, src, dest, override_collisions=False):
    """Merge the top-level keys from src into dest.

    This method is publicly visible for testing.

    Args:
      src: The dictionary whose values will be merged into dest.
      dest: The dictionary into which the values will be merged.
      override_collisions: If True, collisions will be resolved by replacing
          the previous value with the new value. If False, an error will be
          raised if old and new values do not match.
    Raises:
      PlistConflictError: If the two dictionaries had different values for the
          same key.
    """
    for key in src:
      src_value = self._apply_substitutions(src[key])

      if key in dest:
        dest_value = dest[key]

        if not override_collisions and src_value != dest_value:
          raise PlistConflictError(key, src_value, dest_value)

      dest[key] = src_value

  def _get_plist_dict(self, p):
    """Returns a plist dictionary based on the given object.

    This function handles the various input formats for plists in the control
    struct that are supported by this tool. Dictionary objects are returned
    verbatim; strings are treated as paths to plist files, and anything else
    is assumed to be a readable file-like object whose contents are plist data.

    Args:
      p: The object to interpret as a plist.
    Returns:
      A dictionary containing the values from the plist.
    """
    if isinstance(p, dict):
      return p

    if isinstance(p, basestring):
      with open(p) as plist_file:
        return OrderedDict(self._read_plist(plist_file))

    return OrderedDict(self._read_plist(p))

  def _read_plist(self, plist_file):
    """Reads a plist file and returns its contents as a dictionary.

    This method wraps the readPlist method in plistlib by checking the format
    of the plist before reading and using plutil to convert it into XML format
    first, to support plain text and binary formats as well.

    Args:
      plist_file: The file-like object containing the plist data.
    Returns:
      The contents of the plist file as a dictionary.
    """
    plist_contents = plist_file.read()

    # Binary plists are easy to identify because they start with 'bplist'. For
    # plain text plists, it may be possible to have leading whitespace, but
    # well-formed XML should *not* have any whitespace before the XML
    # declaration, so we can check that the plist is not XML and let plutil
    # handle them the same way.
    if not plist_contents.startswith('<?xml'):
      plutil_process = subprocess.Popen(
          ['plutil', '-convert', 'xml1', '-o', '-', '--', '-'],
          stdout=subprocess.PIPE,
          stdin=subprocess.PIPE
      )
      plist_contents, _ = plutil_process.communicate(plist_contents)

    return plistlib.readPlistFromString(plist_contents)

  def _perform_info_plist_operations(self, out_plist, options, target):
    """Performs operations specific to Info.plist files.

    Args:
      out_plist: The dictionary representing the merged plist so far. This
          dictionary will be modified according to the options provided.
      options: A dictionary containing options that describe how the plist
          will be modified. The keys and values are described in the module
          doc.
      target: The name of the target for which the plist is being built.
    Raises:
      ValueError: If the bundle identifier is missing.
    """
    executable = options.get('executable')
    if executable:
      out_plist['CFBundleExecutable'] = executable

    bundle_id = options.get('bundle_id')
    if bundle_id:
      bundle_id = self._apply_substitutions(bundle_id)
      old_bundle_id = out_plist.get('CFBundleIdentifier')
      if old_bundle_id and old_bundle_id != bundle_id:
        raise ValueError(MISMATCHED_BUNDLE_ID_MSG %
                         (old_bundle_id, bundle_id))
      out_plist['CFBundleIdentifier'] = bundle_id

    # Pull in the version info propagated by AppleBundleVersionInfo, using "1.0"
    # as a default if there's no version info whatsoever (either there, or
    # already in the plist).
    version_file = options.get('version_file')
    if version_file:
      if isinstance(version_file, basestring):
        with open(version_file) as f:
          version_info = json.load(f)
      else:
        version_info = json.load(version_file)

      bundle_version = version_info.get('build_version')
      short_version_string = version_info.get('short_version_string')

      if bundle_version:
        out_plist['CFBundleVersion'] = bundle_version
      if short_version_string:
        out_plist['CFBundleShortVersionString'] = short_version_string

    if (options.get('apply_default_version') and
        'CFBundleVersion' not in out_plist):
      print('WARN: The Info.plist for target "%s" did not have a '
            'CFBundleVersion key, so "1.0" will be used as a default. Please '
            'set up proper versioning using the "version" attribute on the '
            'target before releasing it.' % target)
      out_plist['CFBundleVersion'] = '1.0'
      out_plist['CFBundleShortVersionString'] = '1.0'

    # TODO(b/29216266): Check for required keys, such as versions.

    child_plists = options.get('child_plists')
    if child_plists:
      self._validate_against_children(out_plist, child_plists)

    pkginfo_file = options.get('pkginfo')
    if pkginfo_file:
      if isinstance(pkginfo_file, basestring):
        with open(pkginfo_file, 'w') as p:
          self._write_pkginfo(p, out_plist)
      else:
        self._write_pkginfo(pkginfo_file, out_plist)

  def _apply_substitutions(self, value):
    """Applies variable substitutions to the given plist value.

    If the plist value is a string, the text will have the substitutions
    applied. If it is an array or dictionary, then the substitutions will
    be recursively applied to its members. Otherwise (for booleans or
    numbers), the value will remain untouched.

    Variable names can also be suffixed with ":rfc1034identifier", which
    replaces any non-identifier characters with hyphens.

    Args:
      value: The value with possible variable references to substitute.
    Returns:
      The value with any variable references substituted with their new
      values.
    """
    if isinstance(value, str):
      for key, substitute in self._substitutions.iteritems():
        value = value.replace('${' + key + '}', substitute)
        value = value.replace('$(' + key + ')', substitute)

        key += ':rfc1034identifier'
        substitute = self._convert_to_rfc1034(substitute)
        value = value.replace('${' + key + '}', substitute)
        value = value.replace('$(' + key + ')', substitute)
      return value

    if isinstance(value, dict):
      return {k: self._apply_substitutions(v) for k, v in value.iteritems()}

    if isinstance(value, list):
      return [self._apply_substitutions(v) for v in value]

    return value

  def _convert_to_rfc1034(self, string):
    """Forces the given value into RFC 1034 compliance.

    This function replaces any bad characters with '-' as Xcode would in its
    plist substitution.

    Args:
      string: The string to convert.
    Returns:
      The converted string.
    """
    return re.sub(r'[^0-9A-Za-z.]', '-', string)

  def _write_plist(self, plist):
    """Writes the given plist to the output file.

    This method also converts it to binary format if "binary" is True in the
    control struct.

    Args:
      plist: The plist to write to the output path in the control struct.
    """
    path_or_file = self._control['output']
    plistlib.writePlist(plist, path_or_file)

    if self._control.get('binary') and isinstance(path_or_file, basestring):
      subprocess.call(['plutil', '-convert', 'binary1', path_or_file])

  def _write_pkginfo(self, pkginfo, plist):
    """Writes a PkgInfo file with contents from the given plist.

    Args:
      pkginfo: A writable file-like object into which the PkgInfo data will be
          written.
      plist: The plist containing the bundle package type and signature that
          will be written into the PkgInfo.
    """
    package_type = self._four_byte_pkginfo_string(
        plist.get('CFBundlePackageType'))
    signature = self._four_byte_pkginfo_string(
        plist.get('CFBundleSignature'))

    pkginfo.write(package_type)
    pkginfo.write(signature)

  @staticmethod
  def _four_byte_pkginfo_string(value):
    """Encodes a plist value into four bytes suitable for a PkgInfo file.

    Args:
      value: The value that is a candidate for the PkgInfo file.
    Returns:
      If the value is a string that is exactly four bytes long, it is returned;
      otherwise, '????' is returned instead.
    """
    try:
      if not isinstance(value, basestring):
        return '????'

      if isinstance(value, str):
        value = value.decode('utf-8')

      # Based on some experimentation, Xcode appears to use MacRoman encoding
      # for the contents of PkgInfo files, so we do the same.
      value = value.encode('mac-roman')

      return value if len(value) == 4 else '????'
    except (UnicodeDecodeError, UnicodeEncodeError):
      # Return the default string if any character set encoding/decoding errors
      # occurred.
      return '????'

  def _validate_against_children(self, out_plist, child_plists):
    """Validates that a target's plist is consistent with its children.

    This function checks each of the given child plists (which are typically
    extensions or sub-apps embedded in another application) and fails the build
    if their bundle IDs or bundle version strings are inconsistent.

    Args:
      out_plist: The final plist of the target being built.
      child_plists: The plists of child targets that the target being built
          depends on.
    Raises:
      ValueError: if there was an inconsistency between a child target's plist
      and the current target's plist, with a message describing what was
      incorrect.
    """
    for label, p in child_plists.iteritems():
      child_plist = self._get_plist_dict(p)

      prefix = out_plist['CFBundleIdentifier'] + '.'
      child_id = child_plist['CFBundleIdentifier']
      if not child_id.startswith(prefix):
        raise ValueError(CHILD_BUNDLE_ID_MISMATCH_MSG % (
            label, prefix, child_id))

      version = out_plist['CFBundleShortVersionString']
      child_version = child_plist['CFBundleShortVersionString']
      if version != child_version:
        raise ValueError(CHILD_BUNDLE_VERSION_MISMATCH_MSG % (
            label, version, child_version))


def _main(control_path):
  with open(control_path) as control_file:
    control = json.load(control_file)

  tool = PlistTool(control)
  tool.run()


if __name__ == '__main__':
  if len(sys.argv) < 2:
    sys.stderr.write('ERROR: Path to control file not specified.\n')
    exit(1)

  _main(sys.argv[1])
