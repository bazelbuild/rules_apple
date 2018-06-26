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

import subprocess
import sys


def execute_and_filter_output(xcrunargs, filtering=None):
  """Execute a command with arguments, and suppress STDERR output.

  Args:
    xcrunargs: A list of strings beginning with the command to execute followed
        by its arguments.
    filtering: Optionally specify a filter for stdout. It must be callable and
        have the following signature:

          myFilter(input_string) -> output_string
  """
  try:
    p = subprocess.Popen(xcrunargs,
                         stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE)
    stdout, _ = p.communicate()
  except subprocess.CalledProcessError as e:
    sys.stderr.write("ERROR: %s" % e.output)
    raise

  if not stdout:
    return

  if filtering:
    if not callable(filtering):
      raise TypeError("'filtering' must be callable.")
    stdout = filtering(stdout)

  if stdout:
    sys.stdout.write("%s\n" % stdout)
