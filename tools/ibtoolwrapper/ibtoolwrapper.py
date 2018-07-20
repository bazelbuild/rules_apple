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

import sys
from build_bazel_rules_apple.tools.xctoolrunner import xctoolrunner


def _main():
  # TODO(dabelknap) Update the Bazel rules to call xctoolrunner directly.
  xctoolrunner.main(["ibtool"] + sys.argv[1:])


if __name__ == "__main__":
  _main()
