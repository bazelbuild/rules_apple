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
import glob
import os
import re
import shutil
import sys
import tempfile

from build_bazel_rules_apple.tools.wrapper_common import execute
from build_bazel_rules_apple.tools.wrapper_common import lipo


def _copy_swift_stdlibs(
    *,
    binaries_to_scan,
    sdk_platform,
    destination_path,
    requires_bundled_swift_runtime):
  """Copies the Swift stdlibs required by the binaries to the destination."""
  # Rely on the swift-stdlib-tool to determine the subset of Swift stdlibs that
  # these binaries require.
  _, stdout, _ = execute.execute_and_filter_output(
      ["xcode-select", "--print-path"], raise_on_failure=True)

  developer_dir = stdout.strip()
  swift_dylibs_root = "Toolchains/XcodeDefault.xctoolchain/usr/lib/swift-*"
  swift_library_dir_pattern = os.path.join(developer_dir, swift_dylibs_root,
                                           sdk_platform)
  swift_library_dirs = glob.glob(swift_library_dir_pattern)

  cmd = [
      "xcrun", "swift-stdlib-tool", "--copy", "--platform", sdk_platform,
      "--destination", destination_path
  ]
  for swift_library_dir in swift_library_dirs:
    cmd.extend(["--source-libraries", swift_library_dir])
  for binary_to_scan in binaries_to_scan:
    cmd.extend(["--scan-executable", binary_to_scan])

  _, stdout, stderr = execute.execute_and_filter_output(cmd,
                                                        raise_on_failure=True)
  if stderr:
    print(stderr)
  if stdout:
    print(stdout)

  # swift-stdlib-tool currently bundles an unnecessary copy of the Swift runtime
  # whenever it bundles the back-deploy version of the Swift concurrency
  # runtime. This is because the back-deploy version of the Swift concurrency
  # runtime contains an `@rpath`-relative reference to the Swift runtime due to
  # being built with a deployment target that predates the Swift runtime being
  # shipped with operating system.
  # The Swift runtime only needs to be bundled if the binary's deployment target
  # is old enough that it may run on OS versions that lack the Swift runtime,
  # so we detect this scenario and remove the Swift runtime from the output
  # path.
  if not requires_bundled_swift_runtime:
    libswiftcore_path = os.path.join(destination_path, "libswiftCore.dylib")
    if os.path.exists(libswiftcore_path):
      os.remove(libswiftcore_path)


def _lipo_exec_files(exec_files, target_archs, source_path, destination_path):
  """Strips executable files if needed and copies them to the destination."""
  # Find all architectures from the set of files we might have to lipo.
  _, exec_archs = lipo.find_archs_for_binaries(
      [os.path.join(source_path, f) for f in exec_files]
  )

  # Copy or lipo each file as needed, from source to destination.
  for exec_file in exec_files:
    exec_file_source_path = os.path.join(source_path, exec_file)
    exec_file_destination_path = os.path.join(destination_path, exec_file)
    file_archs = exec_archs[exec_file_source_path]

    archs_to_keep = target_archs & file_archs

    # On M1 hardware, thin x86_64 libraries do not need lipo when archs_to_keep
    # is empty.
    if len(file_archs) == 1 or archs_to_keep == file_archs or not archs_to_keep:
      # If there is no need to lipo, copy and mark as executable.
      shutil.copy(exec_file_source_path, exec_file_destination_path)
      os.chmod(exec_file_destination_path, 0o755)
    else:
      lipo.invoke_lipo(
          exec_file_source_path, archs_to_keep, exec_file_destination_path
      )


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
      "--output_path", type=str, required=True, help="path to save the Swift "
      "support libraries to"
  )
  parser.add_argument(
      "--requires_bundled_swift_runtime", action="store_true", default=False,
      help="""
      if true, indicates that the Swift runtime needs to be bundled with the
      binary
      """
  )
  args = parser.parse_args()

  # Create a temporary location for the unstripped Swift stdlibs.
  temp_path = tempfile.mkdtemp(prefix="swift_stdlib_tool.XXXXXX")

  # Use the binaries to copy only the Swift stdlibs we need for this app.
  _copy_swift_stdlibs(
      binaries_to_scan=args.binary,
      sdk_platform=args.platform,
      destination_path=temp_path,
      requires_bundled_swift_runtime=args.requires_bundled_swift_runtime,
  )

  # Determine the binary slices we need to strip with lipo.
  target_archs, _ = lipo.find_archs_for_binaries(args.binary)

  # Select all of the files in this temp directory, which are our Swift stdlibs.
  stdlib_files = [
      f for f in os.listdir(temp_path) if os.path.isfile(
          os.path.join(temp_path, f)
      )
  ]

  destination_path = args.output_path
  # Ensure directory exists for remote execution.
  os.makedirs(destination_path, exist_ok=True)

  # Copy or use lipo to strip the executable Swift stdlibs to their destination.
  _lipo_exec_files(stdlib_files, target_archs, temp_path, destination_path)

  shutil.rmtree(temp_path)


if __name__ == "__main__":
  sys.exit(main())
