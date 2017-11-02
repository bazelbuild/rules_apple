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
  substitutions: A dictionary of string pairs to use for ${VAR}/$(VAR)
      substitutions when processing the plists. All keys/values will get
      support for the rfc1034identifier qualifier.
  target: The target name, used for warning/error messages.
  warn_unknown_substitutions: If True, unknown substitutions will just be
      a warning instead of an error.

The info_plist_options dictionary can contain the following keys:

  apply_default_version: If True, the tool will set CFBundleVersion and
      CFBundleShortVersionString to be "1.0" if values are not already present
      in the output plist.
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

# Format strings for errors that are raised, exposed here to the tests
# can validate against them.

CHILD_BUNDLE_ID_MISMATCH_MSG = (
    'While processing target "%s"; the CFBundleIdentifier of the child target '
    '"%s" should have "%s" as its prefix, but found "%s".'
)

CHILD_BUNDLE_VERSION_MISMATCH_MSG = (
    'While processing target "%s"; the CFBundleShortVersionString of the '
    'child target "%s" should be the same as its parent\'s version string '
    '"%s", but found "%s".'
)

INFO_PLIST_OPTION_VALUE_HAS_VARIABLE_MSG = (
    'Target "%s" has an info_plist_options entry "%s" that appears to contain '
    'an unsupported variable reference: "%s".'
)

PLUTIL_CONVERSION_TO_XML_FAILED_MSG = (
    'While processing target "%s", plutil failed (%d) to convert "%s" to xml.'
)

CONFLICTING_KEYS_MSG = (
    'While processing target "%s"; found key "%s" in two plists with different '
    'values: "%s" != "%s"'
)

UNKNOWN_CONTROL_KEYS_MSG = (
    'Target "%s" used a control structure has unknown key(s): %s'
)

UNKNOWN_INFO_PLIST_OPTIONS_MSG = (
    'Target "%s" used info_plist_options that included unknown key(s): %s'
)

INVALID_SUBSTITUTATION_REFERENCE_MSG = (
    'In target "%s"; invalid variable reference "%s" while merging '
    'Info.plists (key: "%s", value: "%s").'
)

UNKNOWN_SUBSTITUTATION_REFERENCE_MSG = (
    'In target "%s"; unknown variable reference "%s" while merging '
    'Info.plists (key: "%s", value: "%s").'
)

INVALID_SUBSTITUTION_VARIABLE_NAME = (
    'On target "%s"; invalid variable name for substitutions: "%s".'
)

SUBSTITUTION_VARIABLE_CANT_HAVE_QUALIFIER = (
    'On target "%s"; variable name for substitutions can not have a '
    'qualifier: "%s".'
)

# All valid keys in the a control structure.
_CONTROL_KEYS = frozenset([
    'binary', 'forced_plists', 'info_plist_options', 'output', 'plists',
    'substitutions', 'target', 'warn_unknown_substitutions',
])

# All valid keys in the info_plist_options control structure.
_INFO_PLIST_OPTIONS_KEYS = frozenset([
    'apply_default_version', 'child_plists', 'pkginfo', 'version_file',
])

# Two regexes for variable matching/validation.
# VARIABLE_REFERENCE_RE: Matches things that look mostly a
#   variable reference.
# VARIABLE_NAME_RE: Is used to match the name from the first regex to
#     confirm it is a valid name.
VARIABLE_REFERENCE_RE = re.compile(r'\$(\(|\{)([^\)\}]*)((\)|\})?|$)')
VARIABLE_NAME_RE = re.compile('^([a-zA-Z0-9_]+)(:rfc1034identifier)?$')

# Regex for RFC1034 normalization, see _ConvertToRFC1034()
_RFC1034_RE = re.compile(r'[^0-9A-Za-z.]')


def ExtractVariableFromMatch(re_match_obj):
  """Takes a match from VARIABLE_REFERENCE_RE and extracts the variable.

  This funciton is exposed to testing.

  Args:
    re_match_obj: a re.MatchObject
  Returns:
    The variable name (with qualifier attached) or None if the match wasn't
    completely valid.
  """
  expected_close = '}' if re_match_obj.group(1) == '{' else ')'
  if re_match_obj.group(3) == expected_close:
    m = VARIABLE_NAME_RE.match(re_match_obj.group(2))
    if m:
      return m.group(0)
  return None


def _ConvertToRFC1034(string):
  """Forces the given value into RFC 1034 compliance.

  This function replaces any bad characters with '-' as Xcode would in its
  plist substitution.

  Args:
    string: The string to convert.
  Returns:
    The converted string.
  """
  return _RFC1034_RE.sub('-', string)


class PlistToolError(ValueError):
  """Raised for all errors errors.

  Custom ValueError used to allow catching (and logging) just the plisttool
  errors.
  """

  def __init__(self, msg):
    """Initializes an error with the given message.

    Args:
      msg: The message for the error.
    """
    ValueError.__init__(self, msg)


class PlistTool(object):
  """Implements the core functionality of the plist tool."""

  def __init__(self, control):
    """Initializes PlistTool with the given control options.

    Args:
      control: The dictionary of options used to control the tool. Please see
          the moduledoc for a description of the format of this dictionary.
    """
    self._control = control

    # The dictionary of substitutions to apply, where the key is the name to be
    # replaced when enclosed by ${...} or $(...) in a plist value, and the
    # value is the string to substitute.
    self._substitutions = {}

  def run(self):
    """Performs the operations requested by the control struct.

    Raises:
      PlistToolError: If the control the control structure or
          info_plist_options contains unknown keys, or if the control
          structure is missing an 'output' entry.
    """
    target = self._control.get('target')
    if not target:
      raise PlistToolError('No target name in control.')

    unknown_keys = set(self._control.keys()) - _CONTROL_KEYS
    if unknown_keys:
      raise PlistToolError(UNKNOWN_CONTROL_KEYS_MSG % (
          target, ', '.join(sorted(unknown_keys))))
    i_p_o_keys = self._control.get('info_plist_options', dict()).keys()
    unknown_keys = set(i_p_o_keys) - _INFO_PLIST_OPTIONS_KEYS
    if unknown_keys:
      raise PlistToolError(UNKNOWN_INFO_PLIST_OPTIONS_MSG % (
          target, ', '.join(sorted(unknown_keys))))

    if not self._control.get('output'):
      raise PlistToolError('No output file specified.')

    subs = self._control.get('substitutions')
    if subs:
      for key, value in subs.iteritems():
        m = VARIABLE_NAME_RE.match(key)
        if not m:
          raise PlistToolError(INVALID_SUBSTITUTION_VARIABLE_NAME % (
              target, key))
        if m.group(2):
          raise PlistToolError(SUBSTITUTION_VARIABLE_CANT_HAVE_QUALIFIER % (
               target, key))
        if '$' in value:
          raise PlistToolError(
              INFO_PLIST_OPTION_VALUE_HAS_VARIABLE_MSG % (target, key, value))
        value_rfc = _ConvertToRFC1034(value)
        self._substitutions[key] = value
        self._substitutions[key + ':rfc1034identifier'] = value_rfc

    out_plist = {}

    for p in self._control.get('plists', []):
      plist = self._get_plist_dict(p, target)
      self.merge_dictionaries(plist, out_plist, target)

    forced_plists = self._control.get('forced_plists', [])
    for p in forced_plists:
      plist = self._get_plist_dict(p, target)
      self.merge_dictionaries(plist, out_plist, target,
                              override_collisions=True)

    info_plist_options = self._control.get('info_plist_options')
    if info_plist_options:
      self._perform_info_plist_operations(out_plist, info_plist_options,
                                          target)

    warn_only = self._control.get('warn_unknown_substitutions')
    self._validate_no_substitutions(target, '', out_plist, warn_only)

    self._write_plist(out_plist)

  def merge_dictionaries(self, src, dest, target, override_collisions=False):
    """Merge the top-level keys from src into dest.

    This method is publicly visible for testing.

    Args:
      src: The dictionary whose values will be merged into dest.
      dest: The dictionary into which the values will be merged.
      target: The name of the target for which the plist is being built.
      override_collisions: If True, collisions will be resolved by replacing
          the previous value with the new value. If False, an error will be
          raised if old and new values do not match.
    Raises:
      PlistToolError: If the two dictionaries had different values for the
          same key.
    """
    for key in src:
      src_value = self._apply_substitutions(src[key])

      if key in dest:
        dest_value = dest[key]

        if not override_collisions and src_value != dest_value:
          raise PlistToolError(CONFLICTING_KEYS_MSG % (
              target, key, src_value, dest_value))

      dest[key] = src_value

  def _get_plist_dict(self, p, target):
    """Returns a plist dictionary based on the given object.

    This function handles the various input formats for plists in the control
    struct that are supported by this tool. Dictionary objects are returned
    verbatim; strings are treated as paths to plist files, and anything else
    is assumed to be a readable file-like object whose contents are plist data.

    Args:
      p: The object to interpret as a plist.
      target: The name of the target for which the plist is being built.
    Returns:
      A dictionary containing the values from the plist.
    """
    if isinstance(p, dict):
      return p

    if isinstance(p, basestring):
      with open(p) as plist_file:
        return OrderedDict(self._read_plist(plist_file, p, target))

    return OrderedDict(self._read_plist(p, '<input>', target))

  def _read_plist(self, plist_file, name, target):
    """Reads a plist file and returns its contents as a dictionary.

    This method wraps the readPlist method in plistlib by checking the format
    of the plist before reading and using plutil to convert it into XML format
    first, to support plain text and binary formats as well.

    Args:
      plist_file: The file-like object containing the plist data.
      name: Name to report the file-like object as if it fails xml conversion.
      target: The name of the target for which the plist is being built.
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
      if plutil_process.returncode:
        raise PlistToolError(PLUTIL_CONVERSION_TO_XML_FAILED_MSG % (
            target, plutil_process.returncode, name))

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
      PlistToolError: If the bundle identifier was provided and the existing
          plist also had it, but they are different values.
    """
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
      self._validate_against_children(out_plist, child_plists, target)

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

    Args:
      value: The value with possible variable references to substitute.
    Returns:
      The value with any variable references substituted with their new
      values.
    """
    if isinstance(value, basestring):
      def _helper(match_obj):
        # Extract the parts.
        key = ExtractVariableFromMatch(match_obj)
        substitute = self._substitutions.get(key) if key else None
        if substitute:
          return substitute
        # Unknown, leave it as is for now, a forced_plists entry could
        # replace it, so it isn't an error...yet.
        return match_obj.group(0)

      return VARIABLE_REFERENCE_RE.sub(_helper, value)

    if isinstance(value, dict):
      return {k: self._apply_substitutions(v) for k, v in value.iteritems()}

    if isinstance(value, list):
      return [self._apply_substitutions(v) for v in value]

    return value

  def _validate_no_substitutions(self, target, key_name, value, warn_only):
    """Ensures there are no substitutions left in value (recursively).

    Args:
      target: The name of the target for which the plist is being built.
      key_name: The name of the key this value is part of.
      value: The value to check
      warn_only: If True, print a warning instead of raising an error.
    Raises:
      PlistToolError: If there is a variable substitution that wasn't resolved.
    """
    if isinstance(value, basestring):
      for m in VARIABLE_REFERENCE_RE.finditer(value):
        variable_name = ExtractVariableFromMatch(m)
        if not variable_name:
          # Reference wasn't property formed, raise that issue.
          raise PlistToolError(INVALID_SUBSTITUTATION_REFERENCE_MSG % (
              target, m.group(0), key_name, value))
        # Any subs should have already happened; but assert it just to make
        # sure nothing went wrong.
        assert(variable_name not in self._substitutions)
        if warn_only:
          print('WARNING: ' + UNKNOWN_SUBSTITUTATION_REFERENCE_MSG % (
              target, m.group(0), key_name, value))
        else:
          raise PlistToolError(UNKNOWN_SUBSTITUTATION_REFERENCE_MSG % (
              target, m.group(0), key_name, value))
      return

    if isinstance(value, dict):
      key_prefix = key_name + ':' if key_name else ''
      for k, v in value.iteritems():
        self._validate_no_substitutions(target, key_prefix + k, v, warn_only)
      return

    if isinstance(value, list):
      for i, v in enumerate(value):
        reporting_key = '%s[%d]' % (key_name, i)
        self._validate_no_substitutions(target, reporting_key, v, warn_only)
      return

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
      subprocess.check_call(['plutil', '-convert', 'binary1', path_or_file])

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

  def _validate_against_children(self, out_plist, child_plists, target):
    """Validates that a target's plist is consistent with its children.

    This function checks each of the given child plists (which are typically
    extensions or sub-apps embedded in another application) and fails the build
    if their bundle IDs or bundle version strings are inconsistent.

    Args:
      out_plist: The final plist of the target being built.
      child_plists: The plists of child targets that the target being built
          depends on.
      target: The name of the target being processed.
    Raises:
      PlistToolError: if there was an inconsistency between a child target's
          plist and the current target's plist, with a message describing what
          was incorrect.
    """
    for label, p in child_plists.iteritems():
      child_plist = self._get_plist_dict(p, target)

      prefix = out_plist['CFBundleIdentifier'] + '.'
      child_id = child_plist['CFBundleIdentifier']
      if not child_id.startswith(prefix):
        raise PlistToolError(CHILD_BUNDLE_ID_MISMATCH_MSG % (
            target, label, prefix, child_id))

      # CFBundleVersion isn't checked because Apple seems to treat this as
      # a build number developers can pick based on their sources, so they
      # don't require it to match between apps and extensions, but they do
      # require it for the CFBundleShortVersionString.

      version = out_plist['CFBundleShortVersionString']
      child_version = child_plist['CFBundleShortVersionString']
      if version != child_version:
        raise PlistToolError(CHILD_BUNDLE_VERSION_MISMATCH_MSG % (
            target, label, version, child_version))


def _main(control_path):
  with open(control_path) as control_file:
    control = json.load(control_file)

  tool = PlistTool(control)
  try:
    tool.run()
  except PlistToolError as e:
    # Log tools errors cleanly for build output.
    print 'ERROR: %s' % e
    sys.exit(1)


if __name__ == '__main__':
  if len(sys.argv) < 2:
    sys.stderr.write('ERROR: Path to control file not specified.\n')
    exit(1)

  _main(sys.argv[1])
