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
"""Tests for wrapper_common.execute."""

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import contextlib
import io
import os
import sys
import unittest

from build_bazel_rules_apple.tools.wrapper_common import execute

try:
  import StringIO  # Doesn't exist in Python 3
except ImportError:
  StringIO = None

_PY3 = sys.version_info[0] == 3

_INVALID_UTF8 = b'\xa0\xa1'

def _cmd_filter(cmd_result, stdout, stderr):
  # Concat the input to a native string literal, to make sure
  # it doesn't trigger a unicode encode/decode error
  return stdout + ' filtered', stderr + ' filtered'


class ExecuteTest(unittest.TestCase):

  def test_execute_unicode(self):
    bytes_out = u'\u201d '.encode('utf8') + _INVALID_UTF8
    args = ['echo', '-n', bytes_out]

    with self._mock_streams() as (mock_stdout, mock_stderr):
      execute.execute_and_filter_output(args, filtering=_cmd_filter)
      stdout = mock_stdout.getvalue()
      stderr = mock_stderr.getvalue()

    if _PY3:
      expected = bytes_out.decode('utf8', 'replace')
    else:
      expected = bytes_out

    expected += ' filtered'
    self.assertEqual(expected, stdout)
    self.assertIn('filtered', stderr)

  @contextlib.contextmanager
  def _mock_streams(self):
    orig_stdout = sys.stdout
    orig_stderr = sys.stderr

    # io.StringIO() only accepts unicode in Py2, so use the older
    # StringIO.StringIO for Py2, which accepts str/unicode
    if StringIO:
      mock_stdout = StringIO.StringIO()
      mock_stderr = StringIO.StringIO()
    else:
      mock_stdout = io.StringIO()
      mock_stderr = io.StringIO()

    try:
      sys.stdout = mock_stdout
      sys.stderr = mock_stderr
      yield mock_stdout, mock_stderr
    finally:
      sys.stdout = orig_stdout
      sys.stderr = orig_stderr

if __name__ == '__main__':
  unittest.main()
