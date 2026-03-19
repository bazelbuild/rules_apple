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
"""Tests for preserved_framework_processor."""

import os
import tempfile
import time
import unittest
from argparse import Namespace
from unittest import mock

from tools.preserved_framework_processor import preserved_framework_processor


class PreservedFrameworkProcessorTest(unittest.TestCase):

  def test_copy_framework_file_preserves_mode(self):
    with tempfile.TemporaryDirectory() as temp_dir:
      framework_dir = os.path.join(temp_dir, "My.framework")
      os.makedirs(framework_dir)
      source = os.path.join(framework_dir, "My")
      with open(source, "w", encoding="utf-8") as file:
        file.write("binary")
      os.chmod(source, 0o755)

      output_dir = os.path.join(temp_dir, "output")
      preserved_framework_processor._copy_framework_file(source, output_dir)

      copied_file = os.path.join(output_dir, "My")
      self.assertTrue(os.path.exists(copied_file))
      self.assertEqual(0o755, os.stat(copied_file).st_mode & 0o777)

  @mock.patch.object(
      preserved_framework_processor,
      "_get_framework_version_from_install_path")
  @mock.patch.object(
      preserved_framework_processor,
      "_try_get_framework_version_from_structure")
  def test_copy_versioned_framework_preserves_runtime_symlinks(
      self, mock_try_get_version, mock_get_version):
    del mock_get_version
    mock_try_get_version.return_value = "A"

    with tempfile.TemporaryDirectory() as temp_dir:
      framework_dir = os.path.join(temp_dir, "My.framework")
      version_dir = os.path.join(framework_dir, "Versions", "A")
      resources_dir = os.path.join(version_dir, "Resources")
      os.makedirs(resources_dir)
      binary = os.path.join(framework_dir, "My")
      binary_target = os.path.join(version_dir, "My")
      resources_file = os.path.join(resources_dir, "Info.plist")
      top_level_resources_dir = os.path.join(framework_dir, "Resources")
      top_level_resources_file = os.path.join(top_level_resources_dir, "Info.plist")
      with open(binary_target, "w", encoding="utf-8") as file:
        file.write("binary")
      with open(resources_file, "w", encoding="utf-8") as file:
        file.write("plist")
      os.makedirs(top_level_resources_dir)
      with open(top_level_resources_file, "w", encoding="utf-8") as file:
        file.write("plist")

      os.symlink(version_dir, os.path.join(framework_dir, "Versions", "Current"))
      # Source symlinks may be materialized as absolute targets in a Bazel
      # action's execroot, and top-level directories such as Resources may be
      # materialized instead of preserved as symlinks. The preserved bundle
      # should still emit canonical relative framework links.
      os.symlink(binary_target, binary)

      args = Namespace(
          framework_binary=binary,
          framework_file=[top_level_resources_file, resources_file],
          output_zip=os.path.join(temp_dir, "out.zip"),
          temp_path=os.path.join(temp_dir, "out", "My.framework"),
      )
      os.makedirs(os.path.dirname(args.temp_path), exist_ok=True)

      preserved_framework_processor._copy_versioned_framework(
          args, framework_dir, "My")

      self.assertTrue(
          os.path.exists(os.path.join(args.temp_path, "Versions", "A", "My")))
      self.assertTrue(
          os.path.exists(
              os.path.join(args.temp_path, "Versions", "A", "Resources",
                           "Info.plist")))
      self.assertTrue(
          os.path.islink(os.path.join(args.temp_path, "Versions", "Current")))
      self.assertEqual(
          "A", os.readlink(os.path.join(args.temp_path, "Versions", "Current")))
      self.assertTrue(os.path.islink(os.path.join(args.temp_path, "My")))
      self.assertEqual(
          "Versions/Current/My", os.readlink(os.path.join(args.temp_path, "My")))
      self.assertTrue(os.path.islink(os.path.join(args.temp_path, "Resources")))
      self.assertEqual(
          "Versions/Current/Resources",
          os.readlink(os.path.join(args.temp_path, "Resources")))

  def test_copy_versioned_framework_without_current_in_source_structure(self):
    with tempfile.TemporaryDirectory() as temp_dir:
      framework_dir = os.path.join(temp_dir, "My.framework")
      version_dir = os.path.join(framework_dir, "Versions", "A")
      resources_dir = os.path.join(version_dir, "Resources")
      os.makedirs(resources_dir)
      binary = os.path.join(framework_dir, "My")
      resources_file = os.path.join(resources_dir, "Info.plist")
      with open(binary, "w", encoding="utf-8") as file:
        file.write("binary")
      with open(resources_file, "w", encoding="utf-8") as file:
        file.write("plist")

      args = Namespace(
          framework_binary=binary,
          framework_file=[resources_file],
          output_zip=os.path.join(temp_dir, "out.zip"),
          temp_path=os.path.join(temp_dir, "out", "My.framework"),
      )
      os.makedirs(os.path.dirname(args.temp_path), exist_ok=True)

      preserved_framework_processor._copy_versioned_framework(
          args, framework_dir, "My")

      self.assertTrue(
          os.path.exists(os.path.join(args.temp_path, "Versions", "A", "My")))
      self.assertTrue(
          os.path.exists(
              os.path.join(args.temp_path, "Versions", "A", "Resources",
                           "Info.plist")))
      self.assertTrue(
          os.path.islink(os.path.join(args.temp_path, "Versions", "Current")))
      self.assertEqual(
          "A", os.readlink(os.path.join(args.temp_path, "Versions", "Current")))
      self.assertTrue(os.path.islink(os.path.join(args.temp_path, "My")))
      self.assertEqual(
          "Versions/Current/My", os.readlink(os.path.join(args.temp_path, "My")))
      self.assertTrue(os.path.islink(os.path.join(args.temp_path, "Resources")))
      self.assertEqual(
          "Versions/Current/Resources",
          os.readlink(os.path.join(args.temp_path, "Resources")))

  def test_update_modified_timestamps_normalizes_symlink_mtime(self):
    with tempfile.TemporaryDirectory() as temp_dir:
      framework_dir = os.path.join(temp_dir, "My.framework")
      os.makedirs(framework_dir)
      target = os.path.join(framework_dir, "My")
      with open(target, "w", encoding="utf-8") as file:
        file.write("binary")
      symlink = os.path.join(framework_dir, "Current")
      os.symlink("My", symlink)

      preserved_framework_processor._update_modified_timestamps(framework_dir)

      expected_timestamp = 946684800 + time.timezone
      self.assertEqual(expected_timestamp, os.stat(target).st_mtime)
      self.assertEqual(expected_timestamp, os.lstat(symlink).st_mtime)


if __name__ == "__main__":
  unittest.main()
