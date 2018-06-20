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

"""Wrapper for "xcrun actool".

"actoolwrapper" runs "xcrun actool", working around issues with relative paths
and managing creation of the output directory. This script only runs on Darwin
and you must have Xcode installed.

  actoolwrapper [OUTDIR] [<args>...]

  OUTDIR: The directory where the output will be placed. This script will create
      it.
  <args>: Additional arguments to pass to "actool".
"""

import os
import sys
from build_bazel_rules_apple.tools.wrapper_common import execute


def _main(outdir, args):
  """Assemble the call to "xcrun actool"."""

  if not os.path.isdir(outdir):
    os.makedirs(outdir)

  fullpath = os.path.realpath(outdir)

  # "actool" needs to have absolute paths sent to it, so we call "realpath" on
  # all arguments seeing if we can expand them. "actool" and "ibtool" appear to
  # depend on the same codebase. Radar 21045660 "ibtool" has difficulty dealing
  # with relative paths.
  toolargs = []
  lastarg = ""
  for arg in args:
    if lastarg == "--output-partial-info-plist":
      # The argument for "--output-partial-info-plist" doesn't actually exist at
      # the time of flag parsing, so we create it so that we can call "realpath"
      # on it to make the path absolute.
      open(arg, "a").close()  # "touch" the file
    if os.path.isfile(arg):
      toolargs.append(os.path.realpath(arg))
    else:
      toolargs.append(arg)
    lastarg = arg

  xcrunargs = ["xcrun",
               "actool",
               "--errors",
               "--warnings",
               "--notices",
               "--compress-pngs",
               "--output-format",
               "human-readable-text",
               "--compile",
               fullpath]

  xcrunargs += toolargs

  # If we are running into problems figuring out "actool" issues, there are a
  # couple of environment variables that may help. Both of the following must be
  # set to work.
  #   IBToolDebugLogFile=<OUTPUT FILE PATH>
  #   IBToolDebugLogLevel=4
  # You may also see if
  #   IBToolNeverDeque=1
  # helps.
  # Yes, IBTOOL appears to be correct here due to "actool" and "ibtool" being
  # based on the same codebase.
  execute.execute_and_filter_output(xcrunargs)


def validate_args(args):
  if len(args) < 2:
    sys.stderr.write("ERROR: Output directory path required.")
    sys.exit(1)


if __name__ == "__main__":
  validate_args(sys.argv)
  _main(sys.argv[1], sys.argv[2:])
