# Copyright 2023 The Bazel Authors. All rights reserved.
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
"""
A tool gets the libMainThreadChecker.dylib from the DEVELOPER_DIR and
copies it to the requested output path for IPA bundling.
"""

import os
import re
import subprocess
import sys
import shutil


class MainThreadCheckerToolError(RuntimeError):
  """Raised for all errors.

  Custom RuntimeError used to allow catching (and logging) just the
  MainThreadCheckerTool errors.
  """

  def __init__(self, msg):
    """Initializes an error with the given message.

    Args:
      msg: The message for the error.
    """
    RuntimeError.__init__(self, msg)


class MainThreadCheckerTool(object):
  """Implements the Main Thread Check dylib copy tool."""

  def __init__(self, binary_path, output_path):
    """Initializes MainThreadCheckerTool.

    Args:
      binary_path: The path to the binary to scan.
      output_path: The path to the output dylib file.
    """

    self._binary_path = binary_path
    self.output_path = output_path

  def run(self):
    if "DEVELOPER_DIR" in os.environ:
      # /Applications/Xcode.15.0.0.15A240d.app/Contents/Developer/usr/lib/libMainThreadChecker.dylib
      lib_path = os.path.join(os.environ["DEVELOPER_DIR"], "usr/lib/libMainThreadChecker.dylib")
    else:
      raise MainThreadCheckerToolError("Could not find DEVELOPER DIR")
    if os.path.exists(lib_path):
          shutil.copyfile(lib_path, self.output_path)
    else:
      raise MainThreadCheckerToolError("Could not read library at %s." %
                                      lib_path)

if __name__ == "__main__":
  binary_path = sys.argv[1]
  out_path = sys.argv[2]

  tool = MainThreadCheckerTool(binary_path, out_path)
  try:
    tool.run()
  except MainThreadCheckerToolError as e:
    # Log tools errors cleanly for build output.
    sys.stderr.write("ERROR: %s\n" % e)
    sys.exit(1)
