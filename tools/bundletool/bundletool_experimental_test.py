#!/usr/bin/python3
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
"""Tests for the experimental tree-artifact bundler."""

import os
import shutil
import stat
import tempfile
import unittest
import zipfile

from tools.bundletool import bundletool_experimental


class BundlerExperimentalTest(unittest.TestCase):

  def setUp(self):
    super().setUp()
    self._scratch_dir = tempfile.mkdtemp("bundlerExperimentalScratch")

  def tearDown(self):
    super().tearDown()
    shutil.rmtree(self._scratch_dir)

  def _run_bundler(self, control):
    output = os.path.join(self._scratch_dir, "output")
    control["output"] = output
    bundletool_experimental.Bundler(control).run()
    return output

  def _scratch_file(self, path, content=""):
    full_path = os.path.join(self._scratch_dir, path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, "w", encoding="utf-8") as fp:
      fp.write(content)
    return full_path

  def _scratch_symlink(self, path, target):
    full_path = os.path.join(self._scratch_dir, path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    os.symlink(target, full_path)
    return full_path

  def _scratch_zip(self, name):
    path = os.path.join(self._scratch_dir, name)
    with zipfile.ZipFile(path, "w") as zf:
      self._add_zip_file(
          zf, "Foo.framework/Versions/A/Foo", "framework-binary")
      self._add_zip_file(
          zf,
          "Foo.framework/Versions/A/Resources/Info.plist",
          "plist-content",
      )
      self._add_zip_symlink(
          zf, "Foo.framework/Versions/Current", "A")
      self._add_zip_symlink(
          zf, "Foo.framework/Foo", "Versions/Current/Foo")
      self._add_zip_symlink(
          zf, "Foo.framework/Resources", "Versions/Current/Resources")
    return path

  def _add_zip_file(self, zf, path, content):
    zipinfo = zipfile.ZipInfo(path)
    zipinfo.external_attr = (stat.S_IFREG | 0o644) << 16
    zipinfo.compress_type = zipfile.ZIP_STORED
    zf.writestr(zipinfo, content)

  def _add_zip_symlink(self, zf, path, target):
    zipinfo = zipfile.ZipInfo(path)
    zipinfo.external_attr = (stat.S_IFLNK | 0o777) << 16
    zipinfo.compress_type = zipfile.ZIP_STORED
    zf.writestr(zipinfo, target)

  def _assert_symlink(self, path, target):
    self.assertTrue(os.path.islink(path), msg=f"{path} should be a symlink")
    self.assertEqual(target, os.readlink(path))

  def test_bundle_merge_files_preserves_symlinked_files_and_directories(self):
    framework_root = os.path.join(self._scratch_dir, "Foo.framework")
    self._scratch_file(
        "Foo.framework/Versions/A/Foo", "framework-binary")
    self._scratch_file(
        "Foo.framework/Versions/A/Resources/Info.plist", "plist-content")
    self._scratch_symlink("Foo.framework/Versions/Current", "A")
    self._scratch_symlink("Foo.framework/Foo", "Versions/Current/Foo")
    self._scratch_symlink(
        "Foo.framework/Resources", "Versions/Current/Resources")

    output = self._run_bundler({
        "bundle_merge_files": [{
            "src": framework_root,
            "dest": "Contents/Frameworks/Foo.framework",
        }],
    })

    bundled_framework = os.path.join(output, "Contents/Frameworks/Foo.framework")
    self.assertTrue(os.path.isfile(os.path.join(
        bundled_framework, "Versions/A/Foo")))
    self.assertTrue(os.path.isfile(os.path.join(
        bundled_framework, "Versions/A/Resources/Info.plist")))
    self._assert_symlink(os.path.join(
        bundled_framework, "Versions/Current"), "A")
    self._assert_symlink(os.path.join(
        bundled_framework, "Foo"), "Versions/Current/Foo")
    self._assert_symlink(os.path.join(
        bundled_framework, "Resources"), "Versions/Current/Resources")

  def test_bundle_merge_files_copies_sandboxed_inputs(self):
    binary = self._scratch_file("execroot/tool", "executable-content")
    assets = self._scratch_file("execroot/xcassets/Assets.car", "asset-content")
    self._scratch_symlink("sandbox/tool", binary)
    self._scratch_symlink("sandbox/xcassets/Assets.car", assets)

    output = self._run_bundler({
        "bundle_merge_files": [{
            "src": os.path.join(self._scratch_dir, "sandbox"),
            "dest": "",
            "executable": True,
        }],
    })

    for relative_path, content in [
        ("tool", "executable-content"),
        ("xcassets/Assets.car", "asset-content"),
    ]:
      path = os.path.join(output, relative_path)
      self.assertFalse(os.path.islink(path))
      with open(path, encoding="utf-8") as fp:
        self.assertEqual(content, fp.read())
      self.assertEqual(0o755, stat.S_IMODE(os.stat(path).st_mode))

  def test_bundle_merge_files_copies_symlinked_input_directories(self):
    self._scratch_file("execroot/resources/Info.plist", "plist-content")
    resources = os.path.join(self._scratch_dir, "execroot/resources")
    source = self._scratch_symlink("sandbox/resources", resources)

    for src in [source, os.path.dirname(source)]:
      with self.subTest(src=src):
        output = self._run_bundler({
            "bundle_merge_files": [{
                "src": src,
                "dest": "",
            }],
        })
        relative_path = "Info.plist" if src == source else "resources/Info.plist"
        with open(os.path.join(output, relative_path), encoding="utf-8") as fp:
          self.assertEqual("plist-content", fp.read())
        self.assertFalse(os.path.islink(os.path.join(output, "resources")))

  def test_bundle_merge_files_preserves_framework_links_behind_sandbox_links(self):
    framework = os.path.join(self._scratch_dir, "execroot/Foo.framework")
    self._scratch_file("execroot/Foo.framework/Versions/A/Foo", "framework-binary")
    self._scratch_symlink("execroot/Foo.framework/Versions/Current", "A")
    self._scratch_symlink("execroot/Foo.framework/Foo", "Versions/Current/Foo")
    for relative_path in ["Versions/A/Foo", "Versions/Current", "Foo"]:
      self._scratch_symlink(
          os.path.join("sandbox/Foo.framework", relative_path),
          os.path.join(framework, relative_path),
      )

    output = self._run_bundler({
        "bundle_merge_files": [{
            "src": os.path.join(self._scratch_dir, "sandbox/Foo.framework"),
            "dest": "Foo.framework",
        }],
    })

    bundled_framework = os.path.join(output, "Foo.framework")
    self._assert_symlink(os.path.join(
        bundled_framework, "Versions/Current"), "A")
    self._assert_symlink(os.path.join(
        bundled_framework, "Foo"), "Versions/Current/Foo")
    self.assertFalse(os.path.islink(os.path.join(
        bundled_framework, "Versions/A/Foo")))
    with open(os.path.join(bundled_framework, "Foo"), encoding="utf-8") as fp:
      self.assertEqual("framework-binary", fp.read())

  def test_bundle_merge_files_rejects_broken_absolute_symlinks(self):
    missing = os.path.join(self._scratch_dir, "missing")
    broken = self._scratch_symlink("input/broken", missing)
    chain = self._scratch_symlink("chain", broken)

    for src in [broken, chain, os.path.dirname(broken)]:
      with self.subTest(src=src):
        with self.assertRaises(FileNotFoundError) as error:
          self._run_bundler({
              "bundle_merge_files": [{"src": src, "dest": "Resources"}],
          })
        self.assertEqual(missing, error.exception.filename)

  def test_bundle_merge_files_rejects_absolute_symlink_cycles(self):
    first = os.path.join(self._scratch_dir, "input/first")
    second = self._scratch_symlink("input/second", first)
    self._scratch_symlink("input/first", second)

    for src in [first, os.path.dirname(first)]:
      with self.subTest(src=src):
        with self.assertRaisesRegex(ValueError, "Cyclic input symlink"):
          self._run_bundler({
              "bundle_merge_files": [{"src": src, "dest": "Resources"}],
          })

  def test_bundle_merge_files_rejects_absolute_directory_symlink_cycles(self):
    directory = os.path.join(self._scratch_dir, "input")
    self._scratch_file("input/Resources/Info.plist", "plist-content")
    self._scratch_symlink("input/Resources/parent", directory)

    with self.assertRaisesRegex(ValueError, "Cyclic input symlink"):
      self._run_bundler({
          "bundle_merge_files": [{"src": directory, "dest": "Resources"}],
      })

  def test_bundle_merge_files_copies_repeated_absolute_symlink_targets(self):
    self._scratch_file("execroot/Resources/Info.plist", "plist-content")
    resources = os.path.join(self._scratch_dir, "execroot/Resources")
    shared = self._scratch_symlink("shared", resources)
    self._scratch_symlink("input/first", shared)
    self._scratch_symlink("input/second", shared)

    output = self._run_bundler({
        "bundle_merge_files": [{
            "src": os.path.join(self._scratch_dir, "input"),
            "dest": "",
        }],
    })

    for directory in ["first", "second"]:
      with open(os.path.join(output, directory, "Info.plist"),
                encoding="utf-8") as fp:
        self.assertEqual("plist-content", fp.read())

  def test_bundle_symlinks(self):
    output = self._run_bundler({
        "bundle_merge_files": [{
            "src": self._scratch_file("Foo", "framework-binary"),
            "dest": "Foo.framework/Versions/A/Foo",
        }],
        "bundle_symlinks": [
            {"dest": "Foo.framework/Versions/Current", "target": "A"},
            {"dest": "Foo.framework/Foo", "target": "Versions/Current/Foo"},
        ],
    })

    bundled_framework = os.path.join(output, "Foo.framework")
    self.assertTrue(os.path.isfile(os.path.join(
        bundled_framework, "Versions/A/Foo")))
    self._assert_symlink(os.path.join(
        bundled_framework, "Versions/Current"), "A")
    self._assert_symlink(os.path.join(
        bundled_framework, "Foo"), "Versions/Current/Foo")
    self.assertTrue(os.path.isfile(os.path.join(bundled_framework, "Foo")))

  def test_bundle_merge_zips_preserves_symlink_entries(self):
    framework_zip = self._scratch_zip("Foo.zip")

    output = self._run_bundler({
        "bundle_merge_zips": [{
            "src": framework_zip,
            "dest": "Contents/Frameworks",
        }],
    })

    bundled_framework = os.path.join(output, "Contents/Frameworks/Foo.framework")
    self.assertTrue(os.path.isfile(os.path.join(
        bundled_framework, "Versions/A/Foo")))
    self.assertTrue(os.path.isfile(os.path.join(
        bundled_framework, "Versions/A/Resources/Info.plist")))
    self._assert_symlink(os.path.join(
        bundled_framework, "Versions/Current"), "A")
    self._assert_symlink(os.path.join(
        bundled_framework, "Foo"), "Versions/Current/Foo")
    self._assert_symlink(os.path.join(
        bundled_framework, "Resources"), "Versions/Current/Resources")

  def test_bundle_merge_zips_copies_sandboxed_nested_apps(self):
    files = [
        ("Contents/MacOS/Nested", "executable-content", 0o755),
        ("Contents/Info.plist", "plist-content", 0o644),
        ("Contents/Resources/Assets.car", "asset-content", 0o644),
    ]
    for relative_path, content, mode in files:
      source = self._scratch_file(
          os.path.join("execroot/Nested.app", relative_path), content)
      os.chmod(source, mode)
      self._scratch_symlink(
          os.path.join("sandbox/Nested.app", relative_path), source)
    alias = self._scratch_symlink(
        "execroot/Nested.app/Contents/MacOS/Alias", "Nested")
    self._scratch_symlink("sandbox/Nested.app/Contents/MacOS/Alias", alias)
    os.makedirs(os.path.join(
        self._scratch_dir, "sandbox/Nested.app/Contents/Resources/Empty"))
    directory_modes = [
        ("", 0o750),
        ("Contents", 0o700),
        ("Contents/Resources", 0o750),
        ("Contents/Resources/Empty", 0o710),
    ]
    for relative_path, mode in directory_modes:
      os.chmod(os.path.join(
          self._scratch_dir, "sandbox/Nested.app", relative_path), mode)

    output = self._run_bundler({
        "bundle_merge_zips": [{
            "src": os.path.join(self._scratch_dir, "sandbox/Nested.app"),
            "dest": "Contents/Library",
        }],
    })

    shutil.rmtree(os.path.join(self._scratch_dir, "execroot"))
    shutil.rmtree(os.path.join(self._scratch_dir, "sandbox"))
    nested_app = os.path.join(output, "Contents/Library/Nested.app")
    for relative_path, content, mode in files:
      path = os.path.join(nested_app, relative_path)
      self.assertFalse(os.path.islink(path))
      with open(path, encoding="utf-8") as fp:
        self.assertEqual(content, fp.read())
      self.assertEqual(mode, stat.S_IMODE(os.stat(path).st_mode))
    self._assert_symlink(
        os.path.join(nested_app, "Contents/MacOS/Alias"), "Nested")
    self.assertTrue(os.path.isfile(os.path.join(
        nested_app, "Contents/MacOS/Alias")))
    self.assertTrue(os.path.isdir(os.path.join(
        nested_app, "Contents/Resources/Empty")))
    for relative_path, mode in directory_modes:
      self.assertEqual(
          mode, stat.S_IMODE(os.stat(
              os.path.join(nested_app, relative_path)).st_mode))

  def test_bundle_merge_zips_rejects_absolute_symlink_targets(self):
    framework_zip = os.path.join(self._scratch_dir, "Foo.zip")
    with zipfile.ZipFile(framework_zip, "w") as zf:
      self._add_zip_symlink(zf, "Foo.framework/Foo", "/tmp/outside")

    with self.assertRaisesRegex(
        bundletool_experimental.BundleSymlinkError,
        r"Cannot create bundle symlink .* escapes the bundle root",
    ):
      self._run_bundler({
          "bundle_merge_zips": [{
              "src": framework_zip,
              "dest": "Contents/Frameworks",
          }],
      })

  def test_bundle_merge_zips_rejects_relative_symlink_targets_that_escape(self):
    framework_zip = os.path.join(self._scratch_dir, "Foo.zip")
    with zipfile.ZipFile(framework_zip, "w") as zf:
      self._add_zip_symlink(zf, "Foo.framework/Foo", "../../../../outside")

    with self.assertRaisesRegex(
        bundletool_experimental.BundleSymlinkError,
        r"Cannot create bundle symlink .* escapes the bundle root",
    ):
      self._run_bundler({
          "bundle_merge_zips": [{
              "src": framework_zip,
              "dest": "Contents/Frameworks",
          }],
      })

  def test_bundle_merge_zips_rejects_writes_through_escaping_symlink_ancestors(self):
    framework_zip = os.path.join(self._scratch_dir, "Foo.zip")
    with zipfile.ZipFile(framework_zip, "w") as zf:
      self._add_zip_symlink(zf, "Foo", "bar")
      self._add_zip_file(zf, "bar/.keep", "")
      self._add_zip_file(zf, "Foo/Contents/file.txt", "payload")

    output = self._run_bundler({
        "bundle_merge_zips": [{
            "src": framework_zip,
            "dest": "",
        }],
    })

    self._assert_symlink(os.path.join(output, "Foo"), "bar")
    self.assertTrue(os.path.isfile(os.path.join(output, "bar/Contents/file.txt")))

    escaping_zip = os.path.join(self._scratch_dir, "Escaping.zip")
    with zipfile.ZipFile(escaping_zip, "w") as zf:
      self._add_zip_symlink(zf, "Foo", "../outside")
      self._add_zip_file(zf, "Foo/Contents/file.txt", "payload")

    with self.assertRaisesRegex(
        bundletool_experimental.BundleSymlinkError,
        r"Cannot create bundle symlink .* escapes the bundle root",
    ):
      self._run_bundler({
          "bundle_merge_zips": [{
              "src": escaping_zip,
              "dest": "",
          }],
      })

if __name__ == "__main__":
  unittest.main()
