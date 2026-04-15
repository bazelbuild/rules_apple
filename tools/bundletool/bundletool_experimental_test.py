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
"""Tests for bundletool_experimental."""

import os
import shutil
import stat
import tempfile
import unittest

from tools.bundletool import bundletool_experimental


class BundletoolExperimentalTest(unittest.TestCase):

    def setUp(self):
        super().setUp()
        self._scratch_dir = tempfile.mkdtemp("bundletoolExperimentalTestScratch")

    def tearDown(self):
        super().tearDown()
        shutil.rmtree(self._scratch_dir)

    def _scratch_file(self, name, content="", executable=False):
        path = os.path.join(self._scratch_dir, name)
        dirname = os.path.dirname(path)
        if not os.path.isdir(dirname):
            os.makedirs(dirname)

        with open(path, "w") as f:
            f.write(content)
        if executable:
            os.chmod(
                path,
                os.stat(path).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH,
            )
        return path

    def _run_bundler(self, control):
        output = os.path.join(self._scratch_dir, "output")
        control["output"] = output
        bundletool_experimental.Bundler(control).run()
        return output

    def test_bundle_merge_files_with_directories_preserves_executable_bits(self):
        root = os.path.join(self._scratch_dir, "Foo.framework")
        self._scratch_file("Foo.framework/Foo", executable=True)
        self._scratch_file("Foo.framework/Info.plist")

        output = self._run_bundler(
            {
                "bundle_merge_files": [
                    {"src": root, "dest": "Frameworks/Foo.framework"}
                ],
            }
        )

        framework_binary = os.path.join(output, "Frameworks/Foo.framework/Foo")
        framework_plist = os.path.join(output, "Frameworks/Foo.framework/Info.plist")
        self.assertTrue(os.access(framework_binary, os.X_OK))
        self.assertFalse(os.access(framework_plist, os.X_OK))

    def test_bundle_merge_files_with_directories_preserves_symlinks(self):
        root = os.path.join(self._scratch_dir, "Foo.framework")
        self._scratch_file("Foo.framework/Versions/A/Foo", executable=True)
        os.symlink("A", os.path.join(root, "Versions/Current"))
        os.symlink("Versions/Current/Foo", os.path.join(root, "Foo"))

        output = self._run_bundler(
            {
                "bundle_merge_files": [
                    {"src": root, "dest": "Frameworks/Foo.framework"}
                ],
            }
        )

        framework_root = os.path.join(output, "Frameworks/Foo.framework")
        self.assertEqual(
            os.readlink(os.path.join(framework_root, "Versions/Current")),
            "A",
        )
        self.assertEqual(
            os.readlink(os.path.join(framework_root, "Foo")),
            "Versions/Current/Foo",
        )

    def test_bundle_merge_files_with_top_level_file_symlink_copies_file(self):
        self._scratch_file("real_binary", content="binary", executable=True)
        symlink_path = os.path.join(self._scratch_dir, "binary_symlink")
        os.symlink("real_binary", symlink_path)

        output = self._run_bundler(
            {
                "bundle_merge_files": [{"src": symlink_path, "dest": "AppBinary"}],
            }
        )

        output_binary = os.path.join(output, "AppBinary")
        self.assertFalse(os.path.islink(output_binary))
        self.assertTrue(os.access(output_binary, os.X_OK))
        with open(output_binary, "r") as f:
            self.assertEqual(f.read(), "binary")


if __name__ == "__main__":
    unittest.main()
