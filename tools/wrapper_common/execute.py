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

"""Common functionality for tool wrappers to execute jobs.
"""

import os
import re
import subprocess
import sys

_PY3 = sys.version_info[0] == 3


def execute_and_filter_output(cmd_args, filtering=None, trim_paths=False):
  """Execute a command with arguments, and suppress STDERR output.

  Args:
    cmd_args: A list of strings beginning with the command to execute followed
        by its arguments.
    filtering: Optionally specify a filter for stdout/stderr. It must be
        callable and have the following signature:

          myFilter(tool_exit_status, stdout_string, stderr_string) ->
             (stdout_string, stderr_string)

        The filter can then use the tool's exit status to process the
        output as they wish, returning what ever should be used.

    trim_paths: Optionally specify whether or not to trim the current working
        directory from any paths in the output.

  Returns:
    The result of running the command.
  """
  p = subprocess.Popen(cmd_args,
                       stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE)
  stdout, stderr = p.communicate()
  cmd_result = p.returncode

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

  if (stdout or stderr) and filtering:
    if not callable(filtering):
      raise TypeError("'filtering' must be callable.")
    stdout, stderr = filtering(cmd_result, stdout, stderr)

  if trim_paths:
    if stdout:
      stdout = _trim_paths(stdout)
    if stderr:
      stderr = _trim_paths(stderr)

  if stdout:
    sys.stdout.write("%s" % stdout)
  if stderr:
    sys.stderr.write("%s" % stderr)

  return cmd_result


def _trim_paths(stdout):
  """Trim CWD from any paths in "stdout"."""
  CWD = os.getcwd() + "/"

  def replace_path(m):
    path = m.group(0)
    # Some paths present in stdout may contain symlinks, which must be resolved
    # before we can reliably compare to CWD.
    fullpath = os.path.realpath(path)
    if fullpath.find(CWD) >= 0:
      return fullpath.replace(CWD, "")
    else:
      return path

  pattern = r"(/\w+)+/"
  return re.sub(pattern, replace_path, stdout)
