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

"""Version number extraction from Bazel build labels.

Arbitrary labels can be associated with a build by passing the `--embed_label`
flag. Release management systems can use this to tag the build with information
that can be used to decide the build number/version number of a bundle without
requiring that that transient information be checked into source control.

This script takes two arguments. The first points to a file containing the JSON
representation of a "control" structure. This control structure is a dictionary
with the following keys:

  build_info_path: The path to the build info file (`ctx.info_file.path` from
      Skylark) that contains the embedded label information.
  build_label_pattern: The regular expression that should be matched against the
      build label, with possible placeholders corresponding to `capture_groups`.
  build_version_pattern: The string (possibly containing placeholders) that
      should be used as the value of `CFBundleVersion`.
  capture_groups: A dictionary whose keys correspond to placeholders found in
      `build_label_pattern` and whose values are regular expressions that should
      be used to match and capture those segments.
  short_version_string_pattern: The string (possibly containing placeholders)
      that should be used as the value of `CFBundleShortVersionString`. If
      omitted, `build_version_pattern` will be used.

The second argument is the path to the output file. The output is written as a
JSON dictionary containing at most two values:

  build_version: The string to use for `CFBundleVersion`.
  short_version_string: The string to use for `CFBundleShortVersionString`.

This dictionary may be empty if there was no build label found in the build info
file. (This allows the script to complete gracefully in local development when
the --embed_label flag is often not being passed.)
"""

import contextlib
import json
import re
import sys


@contextlib.contextmanager
def _testable_open(fp, mode='r'):
  """Opens a file or uses an existing file-like object.

  This allows the logic to be written in such a way that it does not care
  whether the "paths" its given in the control structure are paths to files or
  file-like objects (such as StringIO) that support testing.

  Args:
    fp: Either a string representing the path to a file that should be opened,
        or an existing file-like object that should be used directly.
    mode: The mode with which to open the file, if `fp` is a string.
  Yields:
    The file-like object to be used in the body of the nested statements.
  """
  if hasattr(fp, 'read') and hasattr(fp, 'write'):
    yield fp
  else:
    yield open(fp, mode)


class VersionTool(object):
  """Implements the core functionality of the versioning tool."""

  def __init__(self, control):
    """Initializes VersionTool with the given control options.

    Args:
      control: The dictionary of options used to control the tool. Please see
          the moduledoc for a description of the format of this dictionary.
    """
    self._build_info_path = control.get('build_info_path')
    self._build_label_pattern = control.get('build_label_pattern')
    self._build_version_pattern = control.get('build_version_pattern')
    self._capture_groups = control.get('capture_groups')

    # Use the build_version pattern if short_version_string is not specified so
    # that they both end up the same.
    self._short_version_string_pattern = control.get(
        'short_version_string_pattern') or self._build_version_pattern

  def run(self):
    """Performs the operations requested by the control struct."""
    substitutions = {}

    if self._build_label_pattern:
      build_label = self._extract_build_label()

      # Bail out early (but gracefully) if the build label was not found; this
      # prevents local development from failing just because the label isn't
      # present.
      if not build_label:
        return {}

      # Extract components from the label.
      resolved_pattern = self._build_label_pattern
      for name, pattern in self._capture_groups.iteritems():
        resolved_pattern = resolved_pattern.replace(
            "{%s}" % name, "(?P<%s>%s)" % (name, pattern))
      match = re.match(resolved_pattern, build_label)
      if match:
        substitutions = match.groupdict()
      else:
        raise ValueError(
            'The build label ("%s") did not match the pattern ("%s").' %
            (build_label, resolved_pattern))

    # Build the result dictionary by substituting the extracted values for
    # the placeholders.
    return {
        'build_version': self._build_version_pattern.format(**substitutions),
        'short_version_string':
            self._short_version_string_pattern.format(**substitutions),
    }

  def _extract_build_label(self):
    """Extracts and returns the build label from the build info file.

    Returns:
      The value of the `BUILD_EMBED_LABEL` line in the build info file, or None
      if the file did not exist.
    Raises:
      ValueError: if there was no build label in the build info file.
    """
    if not self._build_info_path:
      return None

    with _testable_open(self._build_info_path) as build_info_file:
      for line in build_info_file:
        match = re.match(r"^BUILD_EMBED_LABEL\s(.*)$", line)
        if match:
          return match.group(1)

    return None


def _main(control_path, output_path):
  """Called when running the tool from a shell.

  Args:
    control_path: The path to the control file.
    output_path: The path to the file where the output will be written.
  """
  with open(control_path) as control_file:
    control = json.load(control_file)

  tool = VersionTool(control)
  version_data = tool.run()

  with open(output_path, 'w') as output_file:
    json.dump(version_data, output_file)


if __name__ == '__main__':
  if len(sys.argv) < 3:
    sys.stderr.write(
        'ERROR: Path to control file and/or output file not specified.\n')
    exit(1)

  _main(sys.argv[1], sys.argv[2])
