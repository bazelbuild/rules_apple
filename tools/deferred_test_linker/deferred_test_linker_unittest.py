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
import sys
import tempfile
import textwrap
import unittest
from unittest import mock
import zipfile

from tools.deferred_test_linker import deferred_test_linker

# A fake linker that reads its arguments from params files, like
# `wrapped_clang`, and copies its single input to its `-o` output, proving it
# ran from the reconstructed execution root with the recorded command line.
_FAKE_LINKER = "#!" + sys.executable + "\n" + textwrap.dedent("""\
    import shutil, sys
    args = []
    for arg in sys.argv[1:]:
        assert arg.startswith("@"), arg
        with open(arg[1:]) as f:
            args.extend(f.read().splitlines())
    shutil.copy(args[0], args[args.index("-o") + 1])
""")


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

  def _build_exec_root(self, inputs, runfiles):
    deferred_test_linker.build_exec_root(
        exec_root=os.path.join(self.tmp, "execroot"),
        inputs=inputs,
        output="bazel-out/cfg/bin/pkg/out_bin",
        runfiles_root=runfiles,
    )

  def test_build_exec_root_maps_runfiles_to_exec_paths(self):
    runfiles = os.path.join(self.tmp, "runfiles", "_main")
    _write(os.path.join(runfiles, "pkg", "libfoo.a"), "foo")
    _write(os.path.join(self.tmp, "runfiles", "repo", "tool"), "tool")
    manifest = os.path.join(self.tmp, "inputs.txt")
    _write(manifest, "".join([
        "bazel-out/cfg/bin/pkg/libfoo.a\tpkg/libfoo.a\n",
        "bazel-out/exec/bin/external/repo/tool\t../repo/tool\n",
        # Duplicates are tolerated.
        "bazel-out/cfg/bin/pkg/libfoo.a\tpkg/libfoo.a\n",
    ]))

    self._build_exec_root(
        deferred_test_linker.read_inputs_manifest(manifest), runfiles
    )

    exec_root = os.path.join(self.tmp, "execroot")
    for path, content in [
        ("bazel-out/cfg/bin/pkg/libfoo.a", "foo"),
        ("bazel-out/exec/bin/external/repo/tool", "tool"),
    ]:
      with open(os.path.join(exec_root, path), encoding="utf-8") as f:
        self.assertEqual(f.read(), content)
    self.assertTrue(
        os.path.isdir(os.path.join(exec_root, "bazel-out/cfg/bin/pkg"))
    )

  def test_build_exec_root_fails_on_missing_inputs(self):
    with self.assertRaisesRegex(
        deferred_test_linker.LinkError, "pkg/missing.a: not found"
    ):
      self._build_exec_root(
          [("bazel-out/cfg/bin/pkg/missing.a", "pkg/missing.a")], self.tmp
      )

  def test_build_exec_root_checks_which_output_runfiles_are(self):
    execroot = os.path.join(self.tmp, "bazel_execroot")
    right = os.path.join(execroot, "bazel-out", "cfg", "bin", "pkg", "lib.a")
    wrong = os.path.join(execroot, "bazel-out", "other", "bin", "pkg", "lib.a")
    _write(right, "right")
    _write(wrong, "wrong")
    runfiles = os.path.join(self.tmp, "runfiles")
    os.makedirs(os.path.join(runfiles, "pkg"))
    inputs = [("bazel-out/cfg/bin/pkg/lib.a", "pkg/lib.a")]

    # A file of another configuration with the same `short_path`.
    os.symlink(wrong, os.path.join(runfiles, "pkg", "lib.a"))
    with self.assertRaisesRegex(
        deferred_test_linker.LinkError, "another file"
    ):
      self._build_exec_root(inputs, runfiles)
    os.remove(os.path.join(runfiles, "pkg", "lib.a"))

    # An output that is a symlink to another output, like a single
    # architecture `lipo`, still matches.
    lipo = os.path.join(execroot, "bazel-out", "cfg", "bin", "pkg", "lipo")
    os.symlink(right, lipo)
    os.symlink(lipo, os.path.join(runfiles, "pkg", "lipo"))
    # Sandboxed runfiles link to the runfiles tree, which links to the output.
    tree = os.path.join(
        execroot, "bazel-out", "cfg", "bin", "pkg", "t.runfiles", "_main", "pkg"
    )
    _write(os.path.join(tree, "unused"))
    os.symlink(right, os.path.join(tree, "lib.a"))
    os.symlink(os.path.join(tree, "lib.a"), os.path.join(runfiles, "pkg", "lib.a"))
    self._build_exec_root(
        inputs + [("bazel-out/cfg/bin/pkg/lipo", "pkg/lipo")], runfiles
    )

  def test_link_environment_drops_test_variables(self):
    test_env = {
        "COVERAGE_DIR": "/cov",
        "DEVELOPER_DIR": "/Xcode.app/Contents/Developer",
        "DYLD_INSERT_LIBRARIES": "/lib.dylib",
        "HOME": "/home",
        "PATH": "/usr/bin:/bin",
        "SDKROOT": "/sdk",
        "TEST_TMPDIR": "/tmp/test",
    }
    with mock.patch.dict(os.environ, test_env, clear=True):
      env = deferred_test_linker.link_environment(
          {"PATH": "/action/path", "ZERO_AR_DATE": "1"}
      )
    self.assertEqual(env, {
        "DEVELOPER_DIR": "/Xcode.app/Contents/Developer",
        "HOME": "/home",
        "PATH": "/usr/bin:/bin",
        "SDKROOT": "/sdk",
        "ZERO_AR_DATE": "1",
    })

  def _run_main(self, linker=None, **overrides):
    """Runs the tool for a spec like the test rule writes, with `overrides`."""
    runfiles = os.path.join(self.tmp, "runfiles")
    _write(os.path.join(runfiles, "pkg", "main.o"), "object")
    _write(
        os.path.join(runfiles, "pkg", "inputs.txt"),
        "bazel-out/cfg/bin/pkg/main.o\tpkg/main.o\n",
    )
    if not linker:
      linker = os.path.join(self.tmp, "fake_linker")
      _write(linker, _FAKE_LINKER)
      os.chmod(linker, 0o755)
    # Like the test rule, which writes the linker and its arguments from
    # separate `Args` objects.
    _write(os.path.join(runfiles, "pkg", "args_0.txt"), linker + "\n")
    _write(
        os.path.join(runfiles, "pkg", "args_1.txt"),
        "bazel-out/cfg/bin/pkg/main.o\n-o\nbazel-out/cfg/bin/pkg/Tests_bin\n",
    )
    spec = {
        "argv_files": ["pkg/args_0.txt", "pkg/args_1.txt"],
        "clang_rt": False,
        "codesign": False,
        "codesignopts": [],
        "env": {"ZERO_AR_DATE": "1"},
        "executable_name": "Tests",
        "inputs_manifest": "pkg/inputs.txt",
        "main_thread_checker": False,
        "output": "bazel-out/cfg/bin/pkg/Tests_bin",
        "swift_stdlib_platform": None,
    } | overrides
    _write(os.path.join(runfiles, "pkg", "spec.json"), json.dumps(spec))
    bundle = os.path.join(self.tmp, "Tests.xctest")
    os.makedirs(bundle, exist_ok=True)

    cwd = os.getcwd()
    os.chdir(runfiles)
    try:
      # The tool replaces the process environment.
      with mock.patch.dict(os.environ):
        deferred_test_linker.main([
            "--spec", "pkg/spec.json",
            "--bundle", bundle,
            "--work_dir", os.path.join(self.tmp, "work"),
        ])
    finally:
      os.chdir(cwd)
    return bundle

  def test_main_links_into_bundle_and_cleans_up(self):
    bundle = self._run_main()

    with open(os.path.join(bundle, "Tests"), encoding="utf-8") as f:
      self.assertEqual(f.read(), "object")
    self.assertFalse(os.path.exists(os.path.join(self.tmp, "work")))

  def test_main_copies_dylibs_with_the_build_time_tools(self):
    developer_dir = os.path.join(self.tmp, "Developer")
    _write(
        os.path.join(developer_dir, "usr", "lib", "libMainThreadChecker.dylib"),
        "mtc",
    )

    class FakeClangRuntimeTool:

      def __init__(self, binary, output_zip):
        self._output_zip = output_zip

      def run(self):
        with zipfile.ZipFile(self._output_zip, "w") as archive:
          archive.writestr("libclang_rt.asan_iossim_dynamic.dylib", "asan")

    with mock.patch.dict(os.environ, {"DEVELOPER_DIR": developer_dir}), \
        mock.patch.object(
            deferred_test_linker.swift_stdlib_tool, "main"
        ) as swift_stdlib_tool, mock.patch.object(
            deferred_test_linker.clangrttool,
            "ClangRuntimeTool",
            FakeClangRuntimeTool,
        ):
      bundle = self._run_main(
          clang_rt=True,
          main_thread_checker=True,
          swift_stdlib_platform="iphonesimulator",
      )

    swift_stdlib_tool.assert_called_once_with([
        "--binary", os.path.join(bundle, "Tests"),
        "--platform", "iphonesimulator",
        "--output_path", os.path.join(bundle, "Frameworks"),
        "--strip_bitcode",
    ])
    for name in (
        "libclang_rt.asan_iossim_dynamic.dylib",
        "libMainThreadChecker.dylib",
    ):
      self.assertTrue(
          os.path.isfile(os.path.join(bundle, "Frameworks", name)), name
      )

  def test_main_signs_nested_code_then_bundle(self):
    _write(os.path.join(self.tmp, "Tests.xctest", "Frameworks", "a.dylib"))
    with mock.patch.object(
        deferred_test_linker.codesigningtool, "invoke_codesign"
    ) as codesign:
      bundle = self._run_main(codesign=True, codesignopts=["--deep"])

    self.assertEqual(
        [(c.kwargs["full_path_to_sign"], c.kwargs["extra"])
         for c in codesign.call_args_list],
        [(os.path.join(bundle, "Frameworks", "a.dylib"), []),
         (bundle, ["--deep"])],
    )

  def test_main_reports_failures_without_traceback(self):
    for kwargs in ({"linker": "/usr/bin/false"}, {"inputs_manifest": "no"}):
      with self.assertRaises(SystemExit) as e:
        self._run_main(**kwargs)
      self.assertEqual(e.exception.code, 1)
      self.assertFalse(os.path.exists(os.path.join(self.tmp, "work")))


if __name__ == "__main__":
  unittest.main()
