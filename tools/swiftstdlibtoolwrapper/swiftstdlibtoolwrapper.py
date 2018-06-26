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

r"""Wrapper for "xcrun swift-stdlib-tool".

"swiftstdlibtoolwrapper" runs "xcrun swift-stdlib-tool" and zips up the output.
This script only runs on Darwin and you must have Xcode installed.

  swiftstdlibtoolwrapper \
      --output_zip_path [OUTPUT_ZIP_PATH] \
      --bundle_path [BUNDLE_PATH] \
      [<args>...]

  --output_zip_path: The path to place the output zip file.
  --bundle_path: The path inside of the archive to where the libs will be
      copied.
  <args>: Additional args to pass to "swift-stdlib-tool".
"""

import argparse
import os
import shutil
import tempfile
import time
from build_bazel_rules_apple.tools.wrapper_common import execute


_ZIP_EPOCH_TIMESTAMP = 315532800  # 1980-01-01 00:00


def _main(args, toolargs):
  """Assemble the call to "xcrun swift-stdlib-tool"."""
  output_zip_path = args.output_zip_path[0]
  bundle_path = args.bundle_path[0]

  output_zip_path = os.path.realpath(output_zip_path)

  tmpdir = tempfile.mkdtemp(prefix="swiftstdlibtoolZippingOutput.")

  fullpath = os.path.join(tmpdir, bundle_path)

  xcrunargs = ["xcrun",
               "swift-stdlib-tool",
               "--copy",
               "--destination",
               fullpath]

  xcrunargs += toolargs

  execute.execute_and_filter_output(xcrunargs)

  # Set the timestamp of all files within "tmpdir" to the Zip Epoch:
  # 1980-01-01 00:00. They are adjusted for timezone since Python "zipfile"
  # checks the local timestamps of the files.
  for root, _, files in os.walk(tmpdir):
    for f in files:
      filepath = os.path.join(root, f)
      timestamp = _ZIP_EPOCH_TIMESTAMP + time.timezone
      os.utime(filepath, (timestamp, timestamp))

  shutil.make_archive(os.path.splitext(output_zip_path)[0], "zip", tmpdir, ".")

  # Clean up the temporary directory and its contents.
  shutil.rmtree(tmpdir)


def _parse_args():
  """Parse the command line arguments.

  Returns:
    (args, toolargs) where "args" is a Namespace object containing the parsed
    arguments, and "toolargs" is a list of the remaining arguments.
  """
  parser = argparse.ArgumentParser(
      description="Wrapper for \"xcrun swift-stdlib-tool\".",
      usage="""swiftstdlibtoolwrapper.py --output_zip_path OUTPUT_ZIP_PATH
                                 --bundle_path BUNDLE_PATH
                                 [TOOLARG [TOOLARG ...]]
      """,
      add_help=False)
  # TODO(dabelknap): Change these to basic positional arguments.
  parser.add_argument("--output_zip_path", type=str, nargs=1, required=True)
  parser.add_argument("--bundle_path", type=str, nargs=1, required=True)
  return parser.parse_known_args()


if __name__ == "__main__":
  _args, _toolargs = _parse_args()
  _main(_args, _toolargs)
