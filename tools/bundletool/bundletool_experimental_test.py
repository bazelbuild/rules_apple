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

"""Tests for the experimental filesystem bundler."""

import os
import shutil
import stat
import tempfile
import unittest
import zipfile

from tools.bundletool import bundletool_experimental


class ExperimentalBundlerTest(unittest.TestCase):

  def setUp(self):
    super().setUp()
    self._scratch_dir = tempfile.mkdtemp("bundletoolExperimentalTest")

  def tearDown(self):
    super().tearDown()
    shutil.rmtree(self._scratch_dir)

  def _scratch_file(self, name, content="", executable=False):
    path = os.path.join(self._scratch_dir, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
      f.write(content)
    if executable:
      st = os.stat(path)
      os.chmod(path, st.st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    return path

  def _scratch_zip_with_symlink(self):
    path = os.path.join(self._scratch_dir, "framework.zip")
    with zipfile.ZipFile(path, "w") as z:
      file_info = zipfile.ZipInfo("My.framework/Versions/A/My")
      file_info.external_attr = 0o100755 << 16
      z.writestr(file_info, "binary")

      link_info = zipfile.ZipInfo("My.framework/My")
      link_info.external_attr = 0o120755 << 16
      z.writestr(link_info, "Versions/Current/My")

      current_info = zipfile.ZipInfo("My.framework/Versions/Current")
      current_info.external_attr = 0o120755 << 16
      z.writestr(current_info, "A")
    return path

  def test_bundle_merge_zips_preserves_symlinks(self):
    output = os.path.join(self._scratch_dir, "out")
    bundletool_experimental.Bundler({
        "bundle_merge_zips": [{
            "src": self._scratch_zip_with_symlink(),
            "dest": "Contents/Frameworks",
        }],
        "output": output,
    }).run()

    framework_root = os.path.join(output, "Contents", "Frameworks", "My.framework")
    self.assertTrue(os.path.islink(os.path.join(framework_root, "My")))
    self.assertEqual(
        "Versions/Current/My",
        os.readlink(os.path.join(framework_root, "My")),
    )
    self.assertTrue(os.path.islink(os.path.join(framework_root, "Versions", "Current")))
    self.assertEqual(
        "A",
        os.readlink(os.path.join(framework_root, "Versions", "Current")),
    )

  def test_bundle_merge_files_preserves_symlinks(self):
    source_root = os.path.join(self._scratch_dir, "EditorExtension.appex")
    framework_root = os.path.join(source_root, "Contents", "Frameworks", "My.framework")
    self._scratch_file(
        "EditorExtension.appex/Contents/Frameworks/My.framework/Versions/A/My",
        content="binary",
        executable=True,
    )
    os.symlink(
        "A",
        os.path.join(framework_root, "Versions", "Current"),
    )
    os.symlink(
        "Versions/Current/My",
        os.path.join(framework_root, "My"),
    )

    output = os.path.join(self._scratch_dir, "out")
    bundletool_experimental.Bundler({
        "bundle_merge_files": [{
            "src": source_root,
            "dest": "PlugIns/EditorExtension.appex",
        }],
        "output": output,
    }).run()

    embedded_framework_root = os.path.join(
        output,
        "PlugIns",
        "EditorExtension.appex",
        "Contents",
        "Frameworks",
        "My.framework",
    )
    self.assertTrue(os.path.islink(os.path.join(embedded_framework_root, "My")))
    self.assertEqual(
        "Versions/Current/My",
        os.readlink(os.path.join(embedded_framework_root, "My")),
    )
    self.assertTrue(
        os.path.islink(os.path.join(embedded_framework_root, "Versions", "Current"))
    )
    self.assertEqual(
        "A",
        os.readlink(os.path.join(embedded_framework_root, "Versions", "Current")),
    )

  def test_bundle_merge_files_dereferences_top_level_symlink_inputs(self):
    source = self._scratch_file("bin/EditorExtension_lipobin", content="binary", executable=True)
    symlink_path = os.path.join(self._scratch_dir, "bin", "EditorExtension")
    os.symlink(source, symlink_path)

    output = os.path.join(self._scratch_dir, "out")
    bundletool_experimental.Bundler({
        "bundle_merge_files": [{
            "src": symlink_path,
            "dest": "Contents/MacOS/EditorExtension",
            "executable": True,
        }],
        "output": output,
    }).run()

    bundled_binary = os.path.join(output, "Contents", "MacOS", "EditorExtension")
    self.assertFalse(os.path.islink(bundled_binary))
    with open(bundled_binary, "r", encoding="utf-8") as f:
      self.assertEqual("binary", f.read())

  def test_bundle_merge_files_dereferences_top_level_symlink_directories(self):
    source_root = os.path.join(self._scratch_dir, "bin", "EditorExtension.appex")
    self._scratch_file(
        "bin/EditorExtension.appex/Contents/MacOS/EditorExtension",
        content="binary",
        executable=True,
    )
    symlink_path = os.path.join(self._scratch_dir, "bin", "EditorExtension_link.appex")
    os.symlink(source_root, symlink_path)

    output = os.path.join(self._scratch_dir, "out")
    bundletool_experimental.Bundler({
        "bundle_merge_files": [{
            "src": symlink_path,
            "dest": "PlugIns/EditorExtension.appex",
        }],
        "output": output,
    }).run()

    bundled_binary = os.path.join(
        output,
        "PlugIns",
        "EditorExtension.appex",
        "Contents",
        "MacOS",
        "EditorExtension",
    )
    self.assertFalse(os.path.islink(bundled_binary))
    with open(bundled_binary, "r", encoding="utf-8") as f:
      self.assertEqual("binary", f.read())


if __name__ == "__main__":
  unittest.main()
