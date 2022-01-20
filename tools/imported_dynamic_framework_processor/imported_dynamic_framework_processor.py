# Copyright 2020 The Bazel Authors. All rights reserved.
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
#

import os
import shutil
import sys
import time

from build_bazel_rules_apple.tools.bitcode_strip import bitcode_strip
from build_bazel_rules_apple.tools.codesigningtool import codesigningtool
from build_bazel_rules_apple.tools.wrapper_common import lipo


def _zip_framework(framework_temp_path, output_zip_path):
  """Saves the framework as a zip file for caching."""
  zip_epoch_timestamp = 946684800  # 2000-01-01 00:00
  timestamp = zip_epoch_timestamp + time.timezone
  if os.path.exists(framework_temp_path):
    # Apply the fixed utime to the files within directories, then their parent
    # directories and files adjacent to those directories.
    #
    # Avoids accidentally resetting utime on the directories when utime is set
    # on the files within.
    for root, dirs, files in os.walk(framework_temp_path, topdown=False):
      for file_name in dirs + files:
        file_path = os.path.join(root, file_name)
        os.utime(file_path, (timestamp, timestamp))
    os.utime(framework_temp_path, (timestamp, timestamp))
  shutil.make_archive(os.path.splitext(output_zip_path)[0], "zip",
                      os.path.dirname(framework_temp_path),
                      os.path.basename(framework_temp_path))


def _relpath_from_framework(framework_absolute_path):
  """Returns a relative path to the root of the framework bundle."""
  framework_dir = None
  parent_dir = os.path.dirname(framework_absolute_path)
  while parent_dir != "/" and framework_dir is None:
    if parent_dir.endswith(".framework"):
      framework_dir = parent_dir
    else:
      parent_dir = os.path.dirname(parent_dir)

  if parent_dir == "/":
    print("Internal Error: Could not find path in framework: " +
          framework_absolute_path)
    return None

  return os.path.relpath(framework_absolute_path, framework_dir)


def _copy_framework_file(framework_file, executable, output_path):
  """Copies file to given path, marking as writable and executable as needed."""
  path_from_framework = _relpath_from_framework(framework_file)
  if not path_from_framework:
    return 1

  temp_framework_path = os.path.join(output_path, path_from_framework)
  temp_framework_dirs = os.path.dirname(temp_framework_path)
  if not os.path.exists(temp_framework_dirs):
    os.makedirs(temp_framework_dirs)
  shutil.copy(framework_file, temp_framework_path)
  os.chmod(temp_framework_path, 0o755 if executable else 0o644)
  return 0


def _strip_framework_binary(framework_binary, output_path, slices_needed):
  """Strips the binary to only the slices needed, saves output to given path."""
  if not slices_needed:
    print("Internal Error: Did not specify any slices needed for binary at "
          "path: " + framework_binary)
    return 1

  path_from_framework = _relpath_from_framework(framework_binary)
  if not path_from_framework:
    return 1

  temp_framework_path = os.path.join(output_path, path_from_framework)

  lipo.invoke_lipo(framework_binary, slices_needed, temp_framework_path)


def main():
  parser = codesigningtool.generate_arg_parser()
  parser.add_argument(
      "--framework_binary", type=str, required=True, action="append",
      help="path to a binary file scoped to one of the imported frameworks"
  )
  parser.add_argument(
      "--slice", type=str, required=True, action="append", help="binary slice "
      "expected to represent the target architectures"
  )
  parser.add_argument(
      "--strip_bitcode", action="store_true", default=False, help="strip "
      "bitcode from the imported frameworks."
  )
  parser.add_argument(
      "--framework_file", type=str, action="append", help="path to a file "
      "scoped to one of the imported frameworks, distinct from the binary files"
  )
  parser.add_argument(
      "--temp_path", type=str, required=True, help="temporary path to copy "
      "all framework files to"
  )
  parser.add_argument(
      "--output_zip", type=str, required=True, help="path to save the zip file "
      "containing a codesigned, lipoed version of the imported framework"
  )
  args = parser.parse_args()

  all_binary_archs = args.slice
  framework_archs, _ = lipo.find_archs_for_binaries(args.framework_binary)

  if not framework_archs:
    return 1

  # Delete any existing stale framework files, if any exist.
  if os.path.exists(args.temp_path):
    shutil.rmtree(args.temp_path)
  if os.path.exists(args.output_zip):
    os.remove(args.output_zip)
  os.makedirs(args.temp_path)

  for framework_binary in args.framework_binary:
    # If the imported framework is single architecture, and therefore assumed
    # that it doesn't need to be lipoed, or if the binary architectures match
    # the framework architectures perfectly, treat as a copy instead of a lipo
    # operation.
    if len(framework_archs) == 1 or all_binary_archs == framework_archs:
      status_code = _copy_framework_file(framework_binary,
                                         executable=True,
                                         output_path=args.temp_path)
    else:
      slices_needed = framework_archs.intersection(all_binary_archs)
      if not slices_needed:
        print("Error: Precompiled framework does not share any binary "
              "architectures with the binaries that were built.")
        return 1
      status_code = _strip_framework_binary(framework_binary,
                                            args.temp_path,
                                            slices_needed)
    if status_code:
      return 1

    # Strip bitcode from the output framework binary
    if args.strip_bitcode:
      output_binary = os.path.join(args.temp_path,
                                   os.path.basename(framework_binary))
      bitcode_strip.invoke(output_binary, output_binary)

  if args.framework_file:
    for framework_file in args.framework_file:
      status_code = _copy_framework_file(framework_file,
                                         executable=False,
                                         output_path=args.temp_path)
      if status_code:
        return 1

  # Attempt to sign the framework, check for an error when signing.
  status_code = codesigningtool.main(args)
  if status_code:
    return status_code

  _zip_framework(args.temp_path, args.output_zip)


if __name__ == "__main__":
  sys.exit(main())
