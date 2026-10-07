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
"""Tests for app_intents_nl_training_tool."""

import os
import plistlib
import tempfile
import unittest

from unittest import mock

from tools.app_intents_nl_training_tool import app_intents_nl_training_tool
from tools.wrapper_common import execute


def _write(path, contents=""):
  os.makedirs(os.path.dirname(path), exist_ok=True)
  with open(path, "w") as f:
    f.write(contents)


def _read(path):
  with open(path) as f:
    return f.read()


def _relpaths(root):
  return sorted(
      os.path.relpath(os.path.join(dirpath, name), root)
      for dirpath, _, files in os.walk(root)
      for name in files
  )


class StageResourceTreeTest(unittest.TestCase):

  def setUp(self):
    super().setUp()
    self._tmp = tempfile.TemporaryDirectory()
    self.addCleanup(self._tmp.cleanup)
    self.tree = os.path.join(self._tmp.name, "tree")
    self.product_dir = os.path.join(self._tmp.name, "product")
    os.makedirs(self.tree)
    os.makedirs(self.product_dir)

  def testRootTreeStagesStringsFromLocaleDirectories(self):
    _write(os.path.join(self.tree, "en.lproj", "AppShortcuts.strings"), "en")
    _write(os.path.join(self.tree, "fr.lproj", "InfoPlist.strings"), "fr")
    _write(os.path.join(self.tree, "fr.lproj", "Localizable.strings"))
    _write(os.path.join(self.tree, "Assets", "AppShortcuts.strings"))
    _write(os.path.join(self.tree, "AppShortcuts.strings"))

    staged_paths = set()
    app_intents_nl_training_tool._stage_resource_tree(
        ".", self.tree, self.product_dir, staged_paths)

    expected = ["en.lproj/AppShortcuts.strings", "fr.lproj/InfoPlist.strings"]
    self.assertEqual(_relpaths(self.product_dir), expected)
    self.assertEqual(staged_paths, set(expected))
    self.assertEqual(
        _read(os.path.join(self.product_dir, "en.lproj", "AppShortcuts.strings")), "en")

  def testRootTreeCreatesLocaleDirectoriesWithoutStrings(self):
    _write(os.path.join(self.tree, "de.lproj", "Localizable.strings"))

    staged_paths = set()
    app_intents_nl_training_tool._stage_resource_tree(
        ".", self.tree, self.product_dir, staged_paths)

    self.assertTrue(os.path.isdir(os.path.join(self.product_dir, "de.lproj")))
    self.assertEqual(_relpaths(self.product_dir), [])
    self.assertEqual(staged_paths, set())

  def testLocaleTreeStagesStringsIntoParentLocale(self):
    _write(os.path.join(self.tree, "AppShortcuts.strings"), "it")
    _write(os.path.join(self.tree, "InfoPlist.strings"))
    _write(os.path.join(self.tree, "Localizable.strings"))
    # A nested locale directory is not at the root of the tree's parent, so it is ignored.
    _write(os.path.join(self.tree, "en.lproj", "AppShortcuts.strings"))

    staged_paths = set()
    app_intents_nl_training_tool._stage_resource_tree(
        "it.lproj", self.tree, self.product_dir, staged_paths)

    expected = ["it.lproj/AppShortcuts.strings", "it.lproj/InfoPlist.strings"]
    self.assertEqual(_relpaths(self.product_dir), expected)
    self.assertEqual(staged_paths, set(expected))
    self.assertEqual(
        _read(os.path.join(self.product_dir, "it.lproj", "AppShortcuts.strings")), "it")


class ParseArgsTest(unittest.TestCase):

  def testResourceTreeTakesParentAndPath(self):
    args = app_intents_nl_training_tool._parse_args([
        "--bundle-id", "com.example.app",
        "--infoplist", "Info.plist",
        "--metadata", "Metadata.appintents",
        "--output", "out",
        "--resource-tree", ".", "xcstrings/Localizable",
        "--resource-tree", "en.lproj", "processed/en",
    ])

    self.assertEqual(
        args.resource_tree,
        [[".", "xcstrings/Localizable"], ["en.lproj", "processed/en"]])


class MainTest(unittest.TestCase):

  def setUp(self):
    super().setUp()
    self._tmp = tempfile.TemporaryDirectory()
    self.addCleanup(self._tmp.cleanup)
    self.infoplist = os.path.join(self._tmp.name, "Info.plist")
    self.output = os.path.join(self._tmp.name, "output")
    self._write_infoplist({"CFBundleDevelopmentRegion": "en"})

  def _write_infoplist(self, contents):
    with open(self.infoplist, "wb") as f:
      plistlib.dump(contents, f)

  def _argv(self, *extra):
    return [
        "--bundle-id", "com.example.app",
        "--infoplist", self.infoplist,
        "--metadata", os.path.join(self._tmp.name, "Metadata.appintents"),
        "--output", self.output,
    ] + list(extra)

  @staticmethod
  def _product_path(cmd):
    return cmd[cmd.index("--product-path") + 1]

  @mock.patch.object(execute, "execute_and_filter_output")
  def testCopiesGeneratedAssetsButNotStagedInputs(self, mock_execute):
    strings = os.path.join(self._tmp.name, "en.lproj", "AppShortcuts.strings")
    _write(strings)
    tree = os.path.join(self._tmp.name, "tree")
    _write(os.path.join(tree, "fr.lproj", "AppShortcuts.strings"))
    seen_inputs = []

    def fake_execute(cmd):
      product_dir = self._product_path(cmd)
      seen_inputs.extend(_relpaths(product_dir))
      _write(os.path.join(product_dir, "en.lproj", "nlu.appintents", "nlu.lzfse"))
      _write(os.path.join(product_dir, "fr.lproj", "nlu.appintents", "nlu.lzfse"))
      return 0, "", ""

    mock_execute.side_effect = fake_execute

    returncode = app_intents_nl_training_tool.main(self._argv(
        "--lproj-file", "en.lproj", strings,
        "--resource-tree", ".", tree,
    ))

    self.assertEqual(returncode, 0)
    self.assertEqual(
        seen_inputs,
        ["en.lproj/AppShortcuts.strings", "fr.lproj/AppShortcuts.strings"])
    self.assertEqual(
        _relpaths(self.output),
        ["en.lproj/nlu.appintents/nlu.lzfse", "fr.lproj/nlu.appintents/nlu.lzfse"])

  @mock.patch.object(execute, "execute_and_filter_output")
  def testSkipsToolWithoutAnyLocale(self, mock_execute):
    self._write_infoplist({})

    returncode = app_intents_nl_training_tool.main(self._argv())

    self.assertEqual(returncode, 0)
    mock_execute.assert_not_called()
    self.assertEqual(_relpaths(self.output), [])

  @mock.patch.object(execute, "execute_and_filter_output")
  def testRunsToolForDevelopmentRegionOnly(self, mock_execute):
    mock_execute.return_value = (0, "", "")

    returncode = app_intents_nl_training_tool.main(self._argv())

    self.assertEqual(returncode, 0)
    mock_execute.assert_called_once()

  @mock.patch.object(execute, "execute_and_filter_output")
  def testFailsOnErrorMessageWithZeroExitStatus(self, mock_execute):
    mock_execute.return_value = (
        0, "", "error: Could not archive SSU artifacts. Check build log.\n")

    with mock.patch("sys.stderr"):
      returncode = app_intents_nl_training_tool.main(self._argv())

    self.assertEqual(returncode, 1)

  @mock.patch.object(execute, "execute_and_filter_output")
  def testPropagatesNonZeroExitStatus(self, mock_execute):
    mock_execute.return_value = (3, "", "")

    with mock.patch("sys.stderr"):
      returncode = app_intents_nl_training_tool.main(self._argv())

    self.assertEqual(returncode, 3)


if __name__ == "__main__":
  unittest.main()
