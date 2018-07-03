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

"""Wrapper for "xcrun mapc".

"mapcwrapper" runs "xcrun mapc", working around issues with relative paths. This
script only runs on Darwin and you must have Xcode installed.

  mapcwrapper [SOURCE] [DESTINATION] [<args>...]

  SOURCE: The path to the .xcmappingmodel directory.
  DESTINATION: The path to the output .cdm file.
  <args>: Additional arguments to pass to "mapc".
"""

import sys
from build_bazel_rules_apple.tools.xctoolrunner import xctoolrunner


def _main():
  # TODO(dabelknap) Update the Bazel rules to call xctoolrunner directly.
  xctoolrunner.main(["mapc"] + sys.argv[1:])


if __name__ == "__main__":
  _main()
