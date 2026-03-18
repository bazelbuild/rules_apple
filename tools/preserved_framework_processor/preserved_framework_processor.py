# Copyright 2026 The Bazel Authors. All rights reserved.
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
"""Copies the runtime subset of a framework without mutating it."""

import argparse
import os
import re
import shutil
import subprocess
import sys
import time


def _framework_directory(path):
  """Returns the .framework root for a file inside a framework bundle."""
  parent = os.path.dirname(path)
  while parent and parent != "/" and not parent.endswith(".framework"):
    parent = os.path.dirname(parent)

  if not parent or parent == "/":
    raise ValueError(f"Could not determine framework directory for {path}")

  return parent


def _is_versioned_file(filepath, version=None):
  """Returns True if file belongs to a versioned framework path."""
  if version:
    return f".framework/Versions/{version}/" in filepath
  return ".framework/Versions/" in filepath


def _get_install_path_for_binary(binary):
  """Returns the Mach-O install path for a dylib/framework binary."""
  result = subprocess.run(
      ["otool", "-D", "-X", binary],
      check=True,
      capture_output=True,
      text=True,
  )
  stripped_stdout = result.stdout.strip()
  if not re.match(r"@rpath/.*", stripped_stdout):
    raise ValueError(
        "Could not find framework binary install path with otool:\n"
        f"Framework binary: {binary}\n")
  return stripped_stdout


def _get_framework_version_from_install_path(binary):
  """Returns framework version string inferred from binary install path."""
  version_regex = r"@rpath/.*\.framework/Versions/(.*?)/"
  install_path = _get_install_path_for_binary(binary)
  result = re.match(version_regex, install_path)
  if not result or not result.groups():
    raise ValueError(
        "Framework binary install path does not match regular expression:\n"
        f"Framework binary: {binary}\n"
        f"Binary install path: {install_path}\n"
        f"Expected to match regular expression: {version_regex}")
  return result.group(1)


def _try_get_framework_version_from_structure(framework_directory):
  """Returns framework version string when there is a single version."""
  versions = list(os.listdir(os.path.join(framework_directory, "Versions")))
  versions.remove("Current")
  if len(versions) != 1:
    return None
  return versions[0]


def _update_modified_timestamps(framework_temp_path):
  """Normalizes modified times before zipping for deterministic output."""
  zip_epoch_timestamp = 946684800
  timestamp = zip_epoch_timestamp + time.timezone
  if os.path.exists(framework_temp_path):
    for root, dirs, files in os.walk(framework_temp_path, topdown=False):
      for file_name in dirs + files:
        file_path = os.path.join(root, file_name)
        if os.path.islink(file_path):
          os.utime(file_path, (timestamp, timestamp), follow_symlinks=False)
          continue
        os.utime(file_path, (timestamp, timestamp))
    os.utime(framework_temp_path, (timestamp, timestamp))


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
    raise ValueError("Internal Error: Could not find path in framework: " +
                     framework_absolute_path)

  return os.path.relpath(framework_absolute_path, framework_dir)


def _copy_framework_file(source, output_path, relative_path=None):
  """Copies a framework file while preserving file mode."""
  if relative_path is None:
    relative_path = _relpath_from_framework(source)

  destination = os.path.join(output_path, relative_path)
  os.makedirs(os.path.dirname(destination), exist_ok=True)
  shutil.copyfile(source, destination)
  shutil.copymode(source, destination)
  return destination


def _versioned_symlink_target(entry):
  """Returns the canonical top-level symlink target for a versioned framework."""
  return os.path.join("Versions", "Current", entry)


def _versioned_runtime_entries(framework_files, version):
  """Returns top-level runtime entries represented by versioned framework files."""
  version_prefix = os.path.join("Versions", version) + os.sep
  entries = set()

  for framework_file in framework_files:
    relative_path = _relpath_from_framework(framework_file)
    if not relative_path.startswith(version_prefix):
      continue

    version_relative_path = relative_path[len(version_prefix):]
    if not version_relative_path:
      continue

    entry = version_relative_path.split(os.sep, 1)[0]
    if entry == "_CodeSignature":
      continue

    entries.add(entry)

  return entries


def _copy_versioned_framework(args, framework_directory, framework_name):
  """Copies the effective version of a versioned framework."""
  version = _try_get_framework_version_from_structure(framework_directory)
  if version is None:
    version = _get_framework_version_from_install_path(args.framework_binary)

  version_relative_dir = os.path.join("Versions", version)
  _copy_framework_file(
      args.framework_binary,
      args.temp_path,
      relative_path=os.path.join(version_relative_dir, framework_name),
  )

  for framework_file in args.framework_file:
    if not _is_versioned_file(framework_file, version):
      continue
    _copy_framework_file(framework_file, args.temp_path)

  os.makedirs(os.path.join(args.temp_path, "Versions"), exist_ok=True)
  os.symlink(
      version,
      os.path.join(args.temp_path, "Versions", "Current"),
  )

  version_output_dir = os.path.join(args.temp_path, version_relative_dir)
  runtime_entries = _versioned_runtime_entries(args.framework_file, version)
  runtime_entries.add(framework_name)

  for entry in sorted(runtime_entries):
    if not os.path.exists(os.path.join(version_output_dir, entry)):
      continue
    if os.path.lexists(os.path.join(args.temp_path, entry)):
      continue
    os.symlink(
        _versioned_symlink_target(entry),
        os.path.join(args.temp_path, entry),
    )


def _get_parser():
  parser = argparse.ArgumentParser(
      description="preserved framework processor")
  parser.add_argument(
      "--framework_binary",
      type=str,
      required=True,
      help="path to the framework binary",
  )
  parser.add_argument(
      "--framework_file",
      type=str,
      default=[],
      action="append",
      help="path to a runtime framework file",
  )
  parser.add_argument(
      "--temp_path",
      type=str,
      required=True,
      help="temporary directory to copy framework files to",
  )
  parser.add_argument(
      "--output_zip",
      type=str,
      required=True,
      help="path to save the zip file containing the preserved framework",
  )
  return parser


def main():
  parser = _get_parser()
  args = parser.parse_args()

  if os.path.exists(args.temp_path):
    shutil.rmtree(args.temp_path)
  if os.path.exists(args.output_zip):
    os.remove(args.output_zip)
  os.makedirs(args.temp_path)

  framework_inputs = args.framework_file + [args.framework_binary]
  framework_directory = _framework_directory(args.framework_binary)
  framework_name, _ = os.path.splitext(os.path.basename(framework_directory))
  is_versioned = any(
      _is_versioned_file(path)
      for path in framework_inputs
  )

  if is_versioned:
    _copy_versioned_framework(args, framework_directory, framework_name)
  else:
    _copy_framework_file(args.framework_binary, args.temp_path)
    for framework_file in args.framework_file:
      _copy_framework_file(framework_file, args.temp_path)

  _update_modified_timestamps(args.temp_path)
  subprocess.run(
      [
          "/usr/bin/ditto",
          "-c",
          "-k",
          "--keepParent",
          "--norsrc",
          "--noextattr",
          args.temp_path,
          args.output_zip,
      ],
      check=True,
  )


if __name__ == "__main__":
  sys.exit(main())
