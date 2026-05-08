# Copyright 2022 The Bazel Authors. All rights reserved.
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
"""Tests for xcframework_processor_tool."""

import os
import shutil
import stat
import tempfile
import unittest
import zipfile
from unittest import mock

from tools.imported_dynamic_framework_processor import imported_dynamic_framework_processor
from tools.wrapper_common import execute
from tools.wrapper_common import lipo


class ImportedDynamicFrameworkProcessorTest(unittest.TestCase):

  def setUp(self):
    super().setUp()
    self._scratch_dir = tempfile.mkdtemp("importedDynamicFrameworkProcessor")

  def tearDown(self):
    super().tearDown()
    shutil.rmtree(self._scratch_dir)

  def _scratch_file(self, path, content=""):
    full_path = os.path.join(self._scratch_dir, path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, "w", encoding="utf-8") as fp:
      fp.write(content)
    return full_path

  def _scratch_directory(self, path):
    full_path = os.path.join(self._scratch_dir, path)
    os.makedirs(full_path, exist_ok=True)
    return full_path

  def _scratch_symlink(self, path, target):
    full_path = os.path.join(self._scratch_dir, path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    os.symlink(target, full_path)
    return full_path

  @mock.patch.object(execute, "execute_and_filter_output")
  def test_get_install_path_for_binary(self, mock_execute):
    with self.assertRaisesRegex(
        ValueError, r"Could not find framework binary.*"):
      mock_execute.return_value = (None, "no rpath", None)
      imported_dynamic_framework_processor._get_install_path_for_binary(None)

    mock_execute.return_value = (
        None, "@rpath/MyFramework.framework/MyFramework", None)
    result = imported_dynamic_framework_processor._get_install_path_for_binary(
        None)
    self.assertEqual(result, "@rpath/MyFramework.framework/MyFramework")

  @mock.patch.object(
      imported_dynamic_framework_processor, "_get_install_path_for_binary")
  def test_get_version_from_install_path_fails(self, mock_install_path):
    with self.assertRaisesRegex(
        ValueError, r"Framework binary install path does not match.*"):
      mock_install_path.return_value = "@rpath/libMyAwesomeLibrary"
      (imported_dynamic_framework_processor
       ._get_framework_version_from_install_path(None))

    with self.assertRaisesRegex(
        ValueError, r"Framework binary install path does not match.*"):
      mock_install_path.return_value = "@rpath/MyFramework.framework/MyFramework"
      (imported_dynamic_framework_processor
       ._get_framework_version_from_install_path(None))

  @mock.patch.object(
      imported_dynamic_framework_processor, "_get_install_path_for_binary")
  def test_get_version_from_install_path_parse_version(self, mock_install_path):
    mock_install_path.return_value = (
        "@rpath/MyFramework.framework/Versions/A/MyFramework")
    actual_version = (
        imported_dynamic_framework_processor
        ._get_framework_version_from_install_path(None))
    self.assertEqual(actual_version, "A")

    mock_install_path.return_value = (
        "@rpath/MyFramework.framework/Versions/105.0.5195.102/MyFramework")
    actual_version = (
        imported_dynamic_framework_processor
        ._get_framework_version_from_install_path(None))
    self.assertEqual(actual_version, "105.0.5195.102")

    mock_install_path.return_value = (
        "@rpath/MyFramework.framework/Versions/A/Resources.bundle/Info.plist"
    )
    actual_version = (
        imported_dynamic_framework_processor
        ._get_framework_version_from_install_path(None))
    self.assertEqual(actual_version, "A")

  @mock.patch.object(os, "listdir")
  def test_get_version_from_structure(self, mock_listdir):
    mock_listdir.return_value = ["A", "B", "Current"]
    result = imported_dynamic_framework_processor._try_get_framework_version_from_structure("<framework>")
    self.assertIsNone(result)

    mock_listdir.return_value = ["A", "Current"]
    result = imported_dynamic_framework_processor._try_get_framework_version_from_structure("<framework>")
    self.assertEqual(result, "A")

  @mock.patch.object(lipo, "find_archs_for_binaries")
  def test_strip_or_copy_binary_fails_with_no_binary_archs(
      self, mock_lipo):
    with self.assertRaisesRegex(
        ValueError,
        "Could not find binary architectures for binaries using lipo.*"):
      mock_lipo.return_value = (None, None)
      imported_dynamic_framework_processor._strip_or_copy_binary(
          framework_binary="/tmp/path/to/fake/binary",
          output_path="/tmp/path/to/outputs",
          strip_bitcode=False,
          requested_archs=["x86_64"])

  @mock.patch.object(lipo, "find_archs_for_binaries")
  def test_strip_or_copy_binary_fails_with_no_matching_archs(
      self, mock_lipo):
    with self.assertRaisesRegex(
        ValueError,
        ".*Precompiled framework does not share any binary architecture.*"):
      mock_lipo.return_value = (set(["x86_64"]), None)
      imported_dynamic_framework_processor._strip_or_copy_binary(
          framework_binary="/tmp/path/to/fake/binary",
          output_path="/tmp/path/to/outputs",
          strip_bitcode=False,
          requested_archs=["arm64"])

  @mock.patch.object(lipo, "find_archs_for_binaries")
  @mock.patch.object(
      imported_dynamic_framework_processor, "_copy_framework_file")
  @mock.patch.object(
      imported_dynamic_framework_processor, "_strip_framework_binary")
  def test_strip_or_copy_binary_thins_framework_binary(
      self, mock_strip_framework_binary, mock_copy_framework_file, mock_lipo):
    mock_lipo.return_value = (set(["x86_64", "arm64"]), None)
    imported_dynamic_framework_processor._strip_or_copy_binary(
        framework_binary="/tmp/path/to/fake/binary",
        output_path="/tmp/path/to/outputs",
        strip_bitcode=False,
        requested_archs=["arm64"])

    mock_copy_framework_file.assert_not_called()
    mock_strip_framework_binary.assert_called_with(
        "/tmp/path/to/fake/binary",
        "/tmp/path/to/outputs",
        set(["arm64"]))

  @mock.patch.object(lipo, "find_archs_for_binaries")
  @mock.patch.object(
      imported_dynamic_framework_processor, "_copy_framework_file")
  @mock.patch.object(
      imported_dynamic_framework_processor, "_strip_framework_binary")
  def test_strip_or_copy_binary_skips_lipo_with_single_arch_binary(
      self, mock_strip_framework_binary, mock_copy_framework_file, mock_lipo):
    mock_lipo.return_value = (set(["arm64"]), None)
    imported_dynamic_framework_processor._strip_or_copy_binary(
        framework_binary="/tmp/path/to/fake/binary",
        output_path="/tmp/path/to/outputs",
        strip_bitcode=False,
        requested_archs=["arm64"])

    mock_strip_framework_binary.assert_not_called()
    mock_copy_framework_file.assert_called_with(
        "/tmp/path/to/fake/binary",
        executable=True,
        output_path="/tmp/path/to/outputs")

  @mock.patch.object(lipo, "find_archs_for_binaries")
  @mock.patch.object(
      imported_dynamic_framework_processor, "_copy_framework_file")
  @mock.patch.object(
      imported_dynamic_framework_processor, "_strip_framework_binary")
  def test_strip_or_copy_binary_skips_lipo_with_matching_archs_bin(
      self, mock_strip_framework_binary, mock_copy_framework_file, mock_lipo):
    mock_lipo.return_value = (set(["x86_64", "arm64"]), None)
    imported_dynamic_framework_processor._strip_or_copy_binary(
        framework_binary="/tmp/path/to/fake/binary",
        output_path="/tmp/path/to/outputs",
        strip_bitcode=False,
        requested_archs=["x86_64", "arm64"])

    mock_strip_framework_binary.assert_not_called()
    mock_copy_framework_file.assert_called_with(
        "/tmp/path/to/fake/binary",
        executable=True,
        output_path="/tmp/path/to/outputs")

  @mock.patch.object(
      imported_dynamic_framework_processor.codesigningtool,
      "find_identity_and_sign_bundle_paths")
  @mock.patch.object(
      imported_dynamic_framework_processor, "_create_framework_zip")
  @mock.patch.object(
      imported_dynamic_framework_processor, "_update_modified_timestamps")
  @mock.patch.object(
      imported_dynamic_framework_processor, "_try_get_framework_version_from_structure")
  @mock.patch.object(
      imported_dynamic_framework_processor.argparse.ArgumentParser, "parse_args")
  def test_main_reconstructs_versioned_framework_and_signs_current_version(
      self,
      mock_parse_args,
      mock_try_get_framework_version_from_structure,
      mock_update_modified_timestamps,
      mock_create_framework_zip,
      mock_sign):
    framework_binary = self._scratch_file(
        "Foo.framework/Versions/A/Foo", "framework-binary")
    framework_resource = self._scratch_file(
        "Foo.framework/Versions/A/Resources/Info.plist", "plist-content")
    self._scratch_file("Foo.framework/Versions/B/Resources/Info.plist", "other")
    temp_path = os.path.join(self._scratch_dir, "out", "Foo.framework")
    output_zip = os.path.join(self._scratch_dir, "Foo.zip")

    mock_parse_args.return_value = mock.Mock(
        framework_binary=framework_binary,
        framework_file=[
            framework_binary,
            framework_resource,
            os.path.join(
                self._scratch_dir,
                "Foo.framework/Versions/B/Resources/Info.plist",
            ),
        ],
        slice=["x86_64"],
        strip_bitcode=False,
        temp_path=temp_path,
        output_zip=output_zip,
        disable_signing=False,
        target_to_sign=[],
    )
    mock_try_get_framework_version_from_structure.return_value = "A"
    mock_sign.return_value = 0

    with mock.patch.object(
        imported_dynamic_framework_processor,
        "_strip_or_copy_binary",
        side_effect=lambda **kwargs: (
            imported_dynamic_framework_processor._copy_framework_file(
                kwargs["framework_binary"],
                executable=True,
                output_path=kwargs["output_path"],
            )
        ),
    ):
      imported_dynamic_framework_processor.main()

    self.assertTrue(os.path.exists(os.path.join(temp_path, "Versions/A/Foo")))
    self.assertTrue(os.path.exists(os.path.join(
        temp_path, "Versions/A/Resources/Info.plist")))
    self.assertFalse(os.path.exists(os.path.join(
        temp_path, "Versions/B/Resources/Info.plist")))
    self.assertTrue(os.path.islink(os.path.join(temp_path, "Versions/Current")))
    self.assertEqual("A", os.readlink(os.path.join(temp_path, "Versions/Current")))
    self.assertTrue(os.path.islink(os.path.join(temp_path, "Foo")))
    self.assertEqual(
        "Versions/Current/Foo", os.readlink(os.path.join(temp_path, "Foo")))
    self.assertTrue(os.path.islink(os.path.join(temp_path, "Resources")))
    self.assertEqual(
        "Versions/Current/Resources",
        os.readlink(os.path.join(temp_path, "Resources")),
    )
    self.assertEqual(
        [os.path.join(temp_path, "Versions", "A")],
        mock_parse_args.return_value.target_to_sign,
    )
    mock_sign.assert_called_once()
    mock_update_modified_timestamps.assert_called_once_with(temp_path)
    mock_create_framework_zip.assert_called_once_with(temp_path, output_zip)

  def test_create_framework_zip_preserves_versioned_framework_symlinks(self):
    temp_path = os.path.join(self._scratch_dir, "out", "Foo.framework")
    output_zip = os.path.join(self._scratch_dir, "Foo.zip")
    self._scratch_file("out/Foo.framework/Versions/A/Foo", "binary")
    self._scratch_file(
        "out/Foo.framework/Versions/A/Resources/Info.plist", "plist")
    self._scratch_symlink("out/Foo.framework/Versions/Current", "A")
    self._scratch_symlink(
        "out/Foo.framework/Foo", "Versions/Current/Foo")
    self._scratch_symlink(
        "out/Foo.framework/Resources", "Versions/Current/Resources")

    imported_dynamic_framework_processor._create_framework_zip(
        temp_path, output_zip)

    with zipfile.ZipFile(output_zip) as zip_file:
      zip_names = zip_file.namelist()
      self.assertNotIn("Foo.framework/Versions/", zip_names)
      self.assertNotIn("Foo.framework/Versions/A/", zip_names)
      self.assertNotIn("Foo.framework/Versions/A/Resources/", zip_names)
      self.assertNotIn("Foo.framework/Resources/", zip_names)
      self.assertEqual(
          b"Versions/Current/Resources",
          zip_file.read("Foo.framework/Resources"),
      )
      self.assertTrue(stat.S_ISLNK(
          zip_file.getinfo("Foo.framework/Resources").external_attr >> 16))
      self.assertEqual(
          b"A",
          zip_file.read("Foo.framework/Versions/Current"),
      )
      self.assertTrue(stat.S_ISLNK(
          zip_file.getinfo(
              "Foo.framework/Versions/Current").external_attr >> 16))

  def test_create_framework_zip_preserves_empty_versioned_directory(self):
    temp_path = os.path.join(self._scratch_dir, "out", "Foo.framework")
    output_zip = os.path.join(self._scratch_dir, "Foo.zip")
    self._scratch_file("out/Foo.framework/Versions/A/Foo", "binary")
    self._scratch_directory("out/Foo.framework/Versions/A/Headers")
    self._scratch_symlink("out/Foo.framework/Versions/Current", "A")
    self._scratch_symlink(
        "out/Foo.framework/Headers", "Versions/Current/Headers")

    imported_dynamic_framework_processor._create_framework_zip(
        temp_path, output_zip)

    with zipfile.ZipFile(output_zip) as zip_file:
      zip_names = zip_file.namelist()
      self.assertIn("Foo.framework/Versions/A/Headers/", zip_names)
      self.assertNotIn("Foo.framework/Headers/", zip_names)
      self.assertEqual(
          b"Versions/Current/Headers",
          zip_file.read("Foo.framework/Headers"),
      )
      self.assertTrue(stat.S_ISLNK(
          zip_file.getinfo("Foo.framework/Headers").external_attr >> 16))
      self.assertTrue(stat.S_ISDIR(
          zip_file.getinfo(
              "Foo.framework/Versions/A/Headers/").external_attr >> 16))

if __name__ == "__main__":
  unittest.main()
