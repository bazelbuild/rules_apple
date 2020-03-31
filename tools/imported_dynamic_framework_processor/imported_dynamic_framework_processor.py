# Lint as: python2, python3
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
import subprocess
import sys
import time

from build_bazel_rules_apple.tools.codesigningtool import codesigningtool

_PY3 = sys.version_info[0] == 3


# TODO(b/152659280): Unify implementation with the execute script.
def _check_output(args):
  """Handles output from a subprocess, filtering where appropriate.

  Args:
    args: A list of arguments to be invoked as a subprocess.
    inputstr: Data to send directly to the child process.
  """
  proc = subprocess.Popen(
      args,
      stdin=subprocess.PIPE,
      stdout=subprocess.PIPE,
      stderr=subprocess.PIPE)
  stdout, stderr = proc.communicate()

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

  if proc.returncode != 0:
    # print the stdout and stderr, as the exception won't print it.
    print("ERROR:{stdout}\n\n{stderr}".format(stdout=stdout, stderr=stderr))
    raise subprocess.CalledProcessError(proc.returncode, args)
  return stdout, stderr


def _invoke_lipo(binary_path, binary_slices, output_path):
  """Wraps lipo with given arguments for inputs and outputs."""
  cmd = ["xcrun", "lipo", binary_path]
  # Create a thin binary if there's only one needed slice, otherwise create a
  # universal binary
  if len(binary_slices) == 1:
    cmd.extend(["-thin", next(iter(binary_slices))])
  else:
    for binary_slice in binary_slices:
      cmd.extend(["-extract", binary_slice])
  cmd.extend(["-output", output_path])
  stdout, stderr = _check_output(cmd)
  if stdout:
    print(stdout)
  if stderr:
    print(stderr)


def _find_archs_for_binaries(binary_list):
  """Queries lipo to identify binary archs from each of the binaries."""
  found_architectures = set()

  for binary in binary_list:
    cmd = ["xcrun", "lipo", "-info", binary]
    stdout, stderr = _check_output(cmd)
    if stderr:
      print(stderr)
    if not stdout:
      print("Internal Error: Did not receive output from lipo for inputs: " +
            " ".join(cmd))
      return None

    cut_output = stdout.split(":")
    if len(cut_output) < 3:
      print("Internal Error: Unexpected output from lipo, received: " + stdout)
      return None

    archs_found = cut_output[2].strip().split(" ")
    if not archs_found:
      print("Internal Error: Could not find architecture for binary: " + binary)
      return None

    for arch_found in archs_found:
      found_architectures.add(arch_found)

  return found_architectures


def _sign_framework(args):
  codesigningtool.main(args)


def _zip_framework(framework_temp_path, output_zip_path):
  """Saves the framework as a zip file for caching."""
  zip_epoch_timestamp = 946684800  # 2000-01-01 00:00
  if os.path.exists(framework_temp_path):
    for root, _, files in os.walk(framework_temp_path):
      for file_name in files:
        file_path = os.path.join(root, file_name)
        timestamp = zip_epoch_timestamp + time.timezone
        os.utime(file_path, (timestamp, timestamp))
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

  _invoke_lipo(framework_binary, slices_needed, temp_framework_path)


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
  framework_archs = _find_archs_for_binaries(args.framework_binary)

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

  if args.framework_file:
    for framework_file in args.framework_file:
      status_code = _copy_framework_file(framework_file,
                                         executable=False,
                                         output_path=args.temp_path)
      if status_code:
        return 1

  _sign_framework(args)

  _zip_framework(args.temp_path, args.output_zip)


if __name__ == "__main__":
  sys.exit(main())
