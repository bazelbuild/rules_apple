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

"""Wrapper for "xcrun ibtool".

"ibtoolwrapper" runs "xcrun ibtool", working around relative path issues and
handling the differences between file outputs and directory outputs
appropriately. This script only runs on Darwin and you must have Xcode
installed.

  ibtoolwrapper [ACTION] [OUTPUT] [<args>...]

  ACTION: The action to execute: "--compile", "--link", or
      "--compilation-directory". The last one is not technically an action, but
      we treat it as such to unify the output path handling.
  OUTPUT: The path to the file or directory where the output will be written,
      depending on the action specified.
  <args>: Additional arguments to pass to "ibtool".
"""

import os
import sys
from build_bazel_rules_apple.tools.wrapper_common import execute


def _main(action, output, toolargs):
  """Assemble the call to "xcrun ibtool"."""

  xcrunargs = ["xcrun",
               "ibtool",
               "--errors",
               "--warnings",
               "--notices",
               "--auto-activate-custom-fonts",
               "--output-format",
               "human-readable-text",
               action,
               output]

  xcrunargs += toolargs

  # If we are running into problems figuring out "ibtool" issues, there are a
  # couple of environment variables that may help. Both of the following must be
  # set to work.
  #   IBToolDebugLogFile=<OUTPUT FILE PATH>
  #   IBToolDebugLogLevel=4
  # You may also see if
  #   IBToolNeverDeque=1
  # helps.
  execute.execute_and_filter_output(xcrunargs, trim_paths=True)


def validate_args(args):
  if len(args) < 3:
    sys.stderr.write("ERROR: Action flag and output path required")
    sys.exit(1)

  if args[1] not in ["--compilation-directory", "--compile", "--link"]:
    sys.stderr.write("ERROR: Invalid flag provided as first argument")
    sys.exit(1)


if __name__ == "__main__":
  validate_args(sys.argv)
  _main(sys.argv[1], sys.argv[2], sys.argv[3:])
