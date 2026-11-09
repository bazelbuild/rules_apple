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
"""Tests for deferred_test_linker."""

import json
import os
import stat
import sys
import tempfile
import unittest

from tools.deferred_test_linker import deferred_test_linker


def _write(path, content=""):
  os.makedirs(os.path.dirname(path), exist_ok=True)
  with open(path, "w", encoding="utf-8") as f:
    f.write(content)


class DeferredTestLinkerTest(unittest.TestCase):

  def setUp(self):
    super().setUp()
    self._tmp = tempfile.TemporaryDirectory()
    self.tmp = self._tmp.name

  def tearDown(self):
    self._tmp.cleanup()
    super().tearDown()

  def test_read_inputs_manifest(self):
    manifest = os.path.join(self.tmp, "manifest.txt")
    _write(
        manifest,
        "bazel-out/cfg/bin/pkg/libfoo.a\tpkg/libfoo.a\n"
        "external/repo/tool\t../repo/tool\n\n",
    )
    self.assertEqual(
        deferred_test_linker.read_inputs_manifest(manifest),
        [
            ("bazel-out/cfg/bin/pkg/libfoo.a", "pkg/libfoo.a"),
            ("external/repo/tool", "../repo/tool"),
        ],
    )

  def test_build_exec_root_maps_runfiles_to_exec_paths(self):
    runfiles = os.path.join(self.tmp, "runfiles", "_main")
    _write(os.path.join(runfiles, "pkg", "libfoo.a"), "foo")
    _write(os.path.join(self.tmp, "runfiles", "repo", "tool"), "tool")
    exec_root = os.path.join(self.tmp, "execroot")

    deferred_test_linker.build_exec_root(
        exec_root=exec_root,
        inputs=[
            ("bazel-out/cfg/bin/pkg/libfoo.a", "pkg/libfoo.a"),
            ("bazel-out/exec/bin/external/repo/tool", "../repo/tool"),
            # Duplicates are tolerated.
            ("bazel-out/cfg/bin/pkg/libfoo.a", "pkg/libfoo.a"),
        ],
        outputs=["bazel-out/cfg/bin/pkg/out_bin"],
        runfiles_root=runfiles,
    )

    with open(
        os.path.join(exec_root, "bazel-out/cfg/bin/pkg/libfoo.a"),
        encoding="utf-8",
    ) as f:
      self.assertEqual(f.read(), "foo")
    with open(
        os.path.join(exec_root, "bazel-out/exec/bin/external/repo/tool"),
        encoding="utf-8",
    ) as f:
      self.assertEqual(f.read(), "tool")
    self.assertTrue(
        os.path.isdir(os.path.join(exec_root, "bazel-out/cfg/bin/pkg"))
    )

  def test_build_exec_root_fails_on_missing_inputs(self):
    with self.assertRaises(SystemExit):
      deferred_test_linker.build_exec_root(
          exec_root=os.path.join(self.tmp, "execroot"),
          inputs=[("bazel-out/cfg/bin/missing.a", "missing.a")],
          outputs=[],
          runfiles_root=self.tmp,
      )

  def test_link_output_path(self):
    self.assertEqual(
        deferred_test_linker.link_output_path(
            ["clang", "-filelist", "objs", "-o", "out/bin", "-bundle"]
        ),
        "out/bin",
    )
    with self.assertRaises(SystemExit):
      deferred_test_linker.link_output_path(["clang", "-bundle"])

  def test_main_links_into_bundle_and_cleans_up(self):
    runfiles = os.path.join(self.tmp, "runfiles")
    _write(os.path.join(runfiles, "pkg", "main.o"), "object")
    manifest = os.path.join(runfiles, "pkg", "inputs.txt")
    _write(manifest, "bazel-out/cfg/bin/pkg/main.o\tpkg/main.o\n")

    # A fake "linker" that concatenates its input into the output, proving it
    # ran from the reconstructed execution root.
    spec = os.path.join(runfiles, "pkg", "spec.json")
    _write(
        spec,
        json.dumps({
            "argv": [
                sys.executable,
                "-c",
                (
                    "import shutil,sys;"
                    "shutil.copy(sys.argv[1], sys.argv[3])"
                ),
                "bazel-out/cfg/bin/pkg/main.o",
                "-o",
                "bazel-out/cfg/bin/pkg/Tests_bin",
            ],
            "codesign": False,
            "codesignopts": [],
            "env": {"ZERO_AR_DATE": "1"},
            "executable_name": "Tests",
            "inputs_manifest": "pkg/inputs.txt",
            "outputs": ["bazel-out/cfg/bin/pkg/Tests_bin"],
        }),
    )
    bundle = os.path.join(self.tmp, "Tests.xctest")
    os.makedirs(bundle)
    work_dir = os.path.join(self.tmp, "work")

    cwd = os.getcwd()
    os.chdir(runfiles)
    try:
      original_env = deferred_test_linker.link_environment
      deferred_test_linker.link_environment = dict
      try:
        deferred_test_linker.main([
            "--spec",
            "pkg/spec.json",
            "--bundle",
            bundle,
            "--work_dir",
            work_dir,
        ])
      finally:
        deferred_test_linker.link_environment = original_env
    finally:
      os.chdir(cwd)

    binary = os.path.join(bundle, "Tests")
    with open(binary, encoding="utf-8") as f:
      self.assertEqual(f.read(), "object")
    self.assertTrue(os.stat(binary).st_mode & stat.S_IXUSR)
    self.assertFalse(os.path.exists(work_dir))


if __name__ == "__main__":
  unittest.main()
