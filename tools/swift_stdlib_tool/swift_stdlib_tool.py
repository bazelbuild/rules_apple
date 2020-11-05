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

import argparse
import os
import shutil
import sys
import tempfile

from build_bazel_rules_apple.tools.bitcode_strip import bitcode_strip
from build_bazel_rules_apple.tools.strip import strip
from build_bazel_rules_apple.tools.wrapper_common import execute
from build_bazel_rules_apple.tools.wrapper_common import lipo


def _copy_swift_stdlibs(binaries_to_scan, swift_dylibs_path, sdk_platform,
                        destination_path):
  """Copies the Swift stdlibs required by the binaries to the destination."""
  # Use the currently selected Xcode developer directory and SDK to determine
  # exactly which Swift stdlibs we should be copying.
  developer_dir_cmd = ["xcode-select", "--print-path"]
  _, stdout, stderr = execute.execute_and_filter_output(developer_dir_cmd,
                                                        raise_on_failure=True)
  if stderr:
    print(stderr)
  developer_dir = stdout.strip()
  library_source_dir = os.path.join(
      developer_dir, swift_dylibs_path, sdk_platform
  )

  # Rely on the swift-stdlib-tool to determine the subset of Swift stdlibs that
  # these binaries require.
  cmd = [
      "xcrun", "swift-stdlib-tool", "--copy", "--source-libraries",
      library_source_dir, "--platform", sdk_platform, "--destination",
      destination_path
  ]
  for binary_to_scan in binaries_to_scan:
    cmd.extend(["--scan-executable", binary_to_scan])

  _, stdout, stderr = execute.execute_and_filter_output(cmd,
                                                        raise_on_failure=True)
  if stderr:
    print(stderr)
  if stdout:
    print(stdout)


def _lipo_exec_files(exec_files, target_archs, strip_bitcode,
                     strip_swift_symbols, source_path, destination_path):
  """Strips executable files if needed and copies them to the destination."""
  # Find all architectures from the set of files we might have to lipo.
  exec_archs = lipo.find_archs_for_binaries(
      [os.path.join(source_path, f) for f in exec_files]
  )

  # Ensure directory for remote execution
  if not os.path.exists(destination_path):
    os.makedirs(destination_path)

  # Copy or lipo each file as needed, from source to destination.
  for exec_file in exec_files:
    exec_file_source_path = os.path.join(source_path, exec_file)
    exec_file_destination_path = os.path.join(destination_path, exec_file)
    if len(exec_archs) == 1 or target_archs == exec_archs:
      # If there is no need to lipo, copy and mark as executable.
      shutil.copy(exec_file_source_path, exec_file_destination_path)
      os.chmod(exec_file_destination_path, 0o755)
    else:
      lipo.invoke_lipo(
          exec_file_source_path, target_archs, exec_file_destination_path
      )
    if strip_bitcode:
      bitcode_strip.invoke(exec_file_destination_path, exec_file_destination_path)
    if strip_swift_symbols:
      strip.invoke(exec_file_destination_path, exec_file_destination_path)


def main():
  parser = argparse.ArgumentParser(description="swift stdlib tool")
  parser.add_argument(
      "--binary", type=str, required=True, action="append",
      help="path to a binary file which will be the basis for Swift stdlib tool"
      " operations"
  )
  parser.add_argument(
      "--platform", type=str, required=True, help="the target platform, e.g. "
      "'iphoneos'"
  )
  parser.add_argument(
      "--swift_dylibs_path", type=str, required=True, help="path relative from "
      "the developer directory to find the Swift standard libraries, "
      "independent of platform"
  )
  parser.add_argument(
      "--strip_bitcode", action="store_true", default=False, help="strip "
      "bitcode from the Swift support libraries"
  )
  parser.add_argument(
      "--strip_swift_symbols", action="store_true", default=False, help="strip "
      "Swift symbols from the Swift support libraries"
  )
  parser.add_argument(
      "--output_path", type=str, required=True, help="path to save the Swift "
      "support libraries to"
  )
  args = parser.parse_args()

  # Create a temporary location for the unstripped Swift stdlibs.
  temp_path = tempfile.mkdtemp(prefix="swift_stdlib_tool.XXXXXX")

  # Use the binaries to copy only the Swift stdlibs we need for this app.
  _copy_swift_stdlibs(
      args.binary, args.swift_dylibs_path, args.platform, temp_path
  )

  # Determine the binary slices we need to strip with lipo.
  target_archs = lipo.find_archs_for_binaries(args.binary)

  # Select all of the files in this temp directory, which are our Swift stdlibs.
  stdlib_files = [
      f for f in os.listdir(temp_path) if os.path.isfile(
          os.path.join(temp_path, f)
      )
  ]

  # Copy or use lipo to strip the executable Swift stdlibs to their destination.
  _lipo_exec_files(stdlib_files, target_archs, args.strip_bitcode,
                   args.strip_swift_symbols, temp_path, args.output_path)

  shutil.rmtree(temp_path)


if __name__ == "__main__":
  sys.exit(main())
