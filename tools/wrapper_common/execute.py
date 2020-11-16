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

import io
import os
import re
import subprocess
import sys

_PY3 = sys.version_info[0] == 3


def execute_and_filter_output(
    cmd_args,
    filtering=None,
    trim_paths=False,
    custom_env=None,
    inputstr=None,
    print_output=False,
    raise_on_failure=False):
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
        directory from any paths in the output. Based on output after filtering,
        if a filter has been specified.

    custom_env: A dictionary of custom environment variables for this session.

    inputstr: Data to send directly to the child process as input.

    print_output: Wheither to always print the output of stdout and stderr for
        this subprocess.

    raise_on_failure: Raises an exception if the subprocess does not return a
        successful result.

  Returns:
    The result of running the command.

  Raises:
    CalledProcessError: If the process did not indicate a successful result and
        raise_on_failure is True.
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
  stdout, stderr = proc.communicate(input=inputstr)
  cmd_result = proc.returncode

  # Only decode the output for Py3 so that the output type matches
  # the native string-literal type. This prevents Unicode{Encode,Decode}Errors
  # in Py2.
  if _PY3:
    # The invoked tools don't specify what encoding they use, so for lack of a
    # better option, just use utf8 with error replacement. This will replace
    # incorrect utf8 byte sequences with '?', which avoids UnicodeDecodeError
    # from raising.
    stdout = stdout.decode("utf8", "replace")
    stderr = stderr.decode("utf8", "replace")

  if (stdout or stderr) and filtering:
    if not callable(filtering):
      raise TypeError("'filtering' must be callable.")
    stdout, stderr = filtering(cmd_result, stdout, stderr)

  if trim_paths:
    stdout = _trim_paths(stdout)
    stderr = _trim_paths(stderr)

  if cmd_result != 0 and raise_on_failure:
    # print the stdout and stderr, as the exception won't print it.
    print("ERROR:{stdout}\n\n{stderr}".format(stdout=stdout, stderr=stderr))
    raise subprocess.CalledProcessError(proc.returncode, cmd_args)
  elif print_output:
    # The default encoding of stdout/stderr is 'ascii', so we need to reopen the
    # streams in utf8 mode since some messages from Apple's tools use characters
    # like curly quotes. (It would be nice to use the `reconfigure` method here,
    # but that's only available in Python 3.7, which we can't guarantee.)
    if _PY3:
      try:
        sys.stdout = open(
            sys.stdout.fileno(), mode="w", encoding="utf8", buffering=1)
        sys.stderr = open(sys.stderr.fileno(), mode="w", encoding="utf8")
      except io.UnsupportedOperation:
        # When running under test, `fileno` is not supported.
        pass

    if stdout:
      sys.stdout.write(stdout)
    if stderr:
      sys.stderr.write(stderr)

  return cmd_result, stdout, stderr


def _trim_paths(stdout):
  """Trim the current working directory from any paths in "stdout"."""
  if not stdout:
    return None
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
