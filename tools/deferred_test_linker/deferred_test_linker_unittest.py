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
import shlex
import stat
import sys
import tempfile
import textwrap
import unittest
from unittest import mock
import zipfile

from tools.deferred_test_linker import deferred_test_linker

# A fake linker that reads its arguments from a params file and copies its
# single input to its `-o` output, proving it ran from the reconstructed
# execution root with the recorded command line.
_FAKE_LINKER = "#!" + sys.executable + "\n" + textwrap.dedent("""\
    import shlex, shutil, sys
    assert len(sys.argv) == 2 and sys.argv[1].startswith("@"), sys.argv
    with open(sys.argv[1][1:]) as f:
        args = [shlex.split(line)[0] for line in f]
    shutil.copy(args[0], args[args.index("-o") + 1])
""")


def _write(path, content=""):
  os.makedirs(os.path.dirname(path), exist_ok=True)
  with open(path, "w", encoding="utf-8") as f:
    f.write(content)


def _gcc_quote(args):
  """Quotes `args` like Bazel writes the link action's `Args`."""
  return "".join(
      "".join("\\" + c if c in " \t\n'\"\\" else c for c in arg) + "\n"
      for arg in args
  )


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

  def test_read_inputs_manifest_fails_on_malformed_line(self):
    manifest = os.path.join(self.tmp, "manifest.txt")
    _write(manifest, "no-tab-here\n")
    with self.assertRaises(deferred_test_linker.LinkError):
      deferred_test_linker.read_inputs_manifest(manifest)

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
    with self.assertRaisesRegex(
        deferred_test_linker.LinkError, "not found in the test's runfiles"
    ):
      deferred_test_linker.build_exec_root(
          exec_root=os.path.join(self.tmp, "execroot"),
          inputs=[("bazel-out/cfg/bin/missing.a", "missing.a")],
          outputs=[],
          runfiles_root=self.tmp,
      )

  def test_build_exec_root_fails_on_runfiles_collisions(self):
    _write(os.path.join(self.tmp, "pkg", "libfoo.a"))
    with self.assertRaisesRegex(
        deferred_test_linker.LinkError, "share a runfiles location"
    ):
      deferred_test_linker.build_exec_root(
          exec_root=os.path.join(self.tmp, "execroot"),
          inputs=[
              ("bazel-out/cfg-a/bin/pkg/libfoo.a", "pkg/libfoo.a"),
              ("bazel-out/cfg-b/bin/pkg/libfoo.a", "pkg/libfoo.a"),
          ],
          outputs=[],
          runfiles_root=self.tmp,
      )

  def test_link_output_path(self):
    self.assertEqual(
        deferred_test_linker.link_output_path(
            ["clang", "-filelist", "objs", "-o", "out/bin", "-bundle"],
            ["out/bin"],
        ),
        "out/bin",
    )
    # A `-o` passed through `linkopts` doesn't win over the action's output.
    self.assertEqual(
        deferred_test_linker.link_output_path(
            ["clang", "-o", "out/bin", "-Wl,-x", "-o", "other"],
            ["out/bin", "out/bin.linkmap"],
        ),
        "out/bin",
    )
    with self.assertRaises(deferred_test_linker.LinkError):
      deferred_test_linker.link_output_path(["clang", "-bundle"], [])

  def test_write_params_file_round_trips(self):
    args = ["plain", "with space", 'with "quotes"', "back\\slash", "", "$HOME"]
    params = os.path.join(self.tmp, "link.params")
    deferred_test_linker.write_params_file(params, args)
    with open(params, encoding="utf-8") as f:
      lines = f.read().splitlines()
    self.assertEqual([shlex.split(line)[0] if line != '""' else ""
                      for line in lines], args)

  def test_link_environment_drops_test_variables(self):
    test_env = {
        "COVERAGE_DIR": "/cov",
        "DEVELOPER_DIR": "/Applications/Xcode.app/Contents/Developer",
        "DYLD_INSERT_LIBRARIES": "/lib.dylib",
        "HOME": "/home",
        "PATH": "/usr/bin:/bin",
        "SDKROOT": "/sdk",
        "TEST_TMPDIR": "/tmp/test",
    }
    with mock.patch.dict(os.environ, test_env, clear=True):
      env = deferred_test_linker.link_environment({
          "APPLE_SDK_PLATFORM": "iPhoneSimulator",
          "APPLE_SDK_VERSION_OVERRIDE": "26.0",
          "PATH": "/action/path",
          "ZERO_AR_DATE": "1",
      })
    self.assertEqual(env, {
        "APPLE_SDK_PLATFORM": "iPhoneSimulator",
        "APPLE_SDK_VERSION_OVERRIDE": "26.0",
        "DEVELOPER_DIR": "/Applications/Xcode.app/Contents/Developer",
        "HOME": "/home",
        "PATH": "/usr/bin:/bin",
        "SDKROOT": "/sdk",
        "ZERO_AR_DATE": "1",
    })

  def test_write_params_file_rejects_newlines(self):
    with self.assertRaises(deferred_test_linker.LinkError):
      deferred_test_linker.write_params_file(
          os.path.join(self.tmp, "link.params"), ["a\nb"]
      )

  def test_parse_args_file(self):
    parse = deferred_test_linker.parse_args_file
    # As written by Bazel for the link action.
    self.assertEqual(
        parse("-Wl,a\\ b\nq\\'u$t\ntab\\\there\nback\\\\\\\\slash\n"),
        ["-Wl,a b", "q'u$t", "tab\there", "back\\\\slash"],
    )
    self.assertEqual(parse("'a b' \"c d\"\n\ne"), ["a b", "c d", "e"])
    self.assertEqual(parse("''\n"), [""])
    self.assertEqual(parse(""), [])
    args = ["-o", "a b", "it's", 'say "hi"', "c:\\d", "x\ny"]
    self.assertEqual(parse(_gcc_quote(args)), args)
    with self.assertRaises(deferred_test_linker.LinkError):
      parse("'unterminated")

  def test_build_exec_root_rejects_runfiles_of_other_configurations(self):
    execroot = os.path.join(self.tmp, "bazel_execroot")
    right = os.path.join(execroot, "bazel-out", "cfg", "bin", "pkg", "lib.a")
    wrong = os.path.join(execroot, "bazel-out", "other", "bin", "pkg", "lib.a")
    _write(right, "right")
    _write(wrong, "wrong")
    runfiles = os.path.join(self.tmp, "runfiles")
    os.makedirs(os.path.join(runfiles, "pkg"))
    os.symlink(wrong, os.path.join(runfiles, "pkg", "lib.a"))

    with self.assertRaisesRegex(
        deferred_test_linker.LinkError, "expected bazel-out/cfg/bin/pkg/lib.a"
    ):
      deferred_test_linker.build_exec_root(
          exec_root=os.path.join(self.tmp, "exec_root"),
          inputs=[("bazel-out/cfg/bin/pkg/lib.a", "pkg/lib.a")],
          outputs=[],
          runfiles_root=runfiles,
      )

    # An output that is a symlink to another output, like a single
    # architecture `lipo`, still matches.
    lipo = os.path.join(execroot, "bazel-out", "cfg", "bin", "pkg", "lib_lipo")
    os.symlink(right, lipo)
    os.symlink(lipo, os.path.join(runfiles, "pkg", "lib_lipo"))
    # Sandboxed runfiles link to the runfiles tree, which links to the output.
    tree = os.path.join(
        execroot, "bazel-out", "cfg", "bin", "pkg", "t.runfiles", "_main", "pkg"
    )
    os.makedirs(tree)
    os.symlink(right, os.path.join(tree, "lib.a"))
    os.remove(os.path.join(runfiles, "pkg", "lib.a"))
    os.symlink(os.path.join(tree, "lib.a"), os.path.join(runfiles, "pkg", "lib.a"))
    deferred_test_linker.build_exec_root(
        exec_root=os.path.join(self.tmp, "exec_root2"),
        inputs=[
            ("bazel-out/cfg/bin/pkg/lib.a", "pkg/lib.a"),
            ("bazel-out/cfg/bin/pkg/lib_lipo", "pkg/lib_lipo"),
        ],
        outputs=[],
        runfiles_root=runfiles,
    )
    os.remove(os.path.join(runfiles, "pkg", "lib.a"))
    os.symlink(right, os.path.join(runfiles, "pkg", "lib.a"))
    deferred_test_linker.build_exec_root(
        exec_root=os.path.join(self.tmp, "exec_root"),
        inputs=[("bazel-out/cfg/bin/pkg/lib.a", "pkg/lib.a")],
        outputs=[],
        runfiles_root=runfiles,
    )

  def test_copy_swift_dylibs_uses_swift_stdlib_tool(self):
    env = {"DEVELOPER_DIR": "/dev", "PATH": "/bin"}
    seen = {}

    def fake_main(argv):
      seen["argv"] = argv
      seen["env"] = dict(os.environ)

    with mock.patch.object(
        deferred_test_linker.swift_stdlib_tool, "main", side_effect=fake_main
    ):
      deferred_test_linker.copy_swift_dylibs(
          binary="/b/Tests.xctest/Tests",
          bundle="/b/Tests.xctest",
          env=env,
          platform="iphonesimulator",
      )
    self.assertEqual(seen["argv"], [
        "--binary", "/b/Tests.xctest/Tests",
        "--platform", "iphonesimulator",
        "--output_path", "/b/Tests.xctest/Frameworks",
        "--strip_bitcode",
    ])
    self.assertEqual(seen["env"], env)
    self.assertNotEqual(dict(os.environ), env)

  def test_copy_clang_runtime_dylibs_extracts_into_frameworks(self):
    bundle = os.path.join(self.tmp, "Tests.xctest")
    os.makedirs(bundle)
    work_dir = os.path.join(self.tmp, "clang_rt")

    class FakeTool:

      def __init__(self, binary, output_zip):
        assert binary == os.path.join(bundle, "Tests")
        self._output_zip = output_zip

      def run(self):
        with zipfile.ZipFile(self._output_zip, "w") as archive:
          archive.writestr("libclang_rt.asan_iossim_dynamic.dylib", "asan")

    with mock.patch.object(
        deferred_test_linker.clangrttool, "ClangRuntimeTool", FakeTool
    ):
      deferred_test_linker.copy_clang_runtime_dylibs(
          binary=os.path.join(bundle, "Tests"),
          bundle=bundle,
          env={},
          work_dir=work_dir,
      )
    self.assertTrue(os.path.isfile(os.path.join(
        bundle, "Frameworks", "libclang_rt.asan_iossim_dynamic.dylib"
    )))
    self.assertFalse(os.path.exists(work_dir))

  def test_copy_main_thread_checker_dylib_uses_build_tool(self):
    self.assertTrue(
        os.path.isfile(deferred_test_linker._MAIN_THREAD_CHECKER_TOOL),
        deferred_test_linker._MAIN_THREAD_CHECKER_TOOL,
    )
    developer_dir = os.path.join(self.tmp, "Developer")
    _write(
        os.path.join(developer_dir, "usr", "lib", "libMainThreadChecker.dylib"),
        "mtc",
    )
    bundle = os.path.join(self.tmp, "Tests.xctest")
    os.makedirs(bundle)
    deferred_test_linker.copy_main_thread_checker_dylib(
        bundle=bundle,
        env={"DEVELOPER_DIR": developer_dir, "PATH": os.environ["PATH"]},
    )
    with open(
        os.path.join(bundle, "Frameworks", "libMainThreadChecker.dylib")
    ) as f:
      self.assertEqual(f.read(), "mtc")

  def test_main_copies_runtime_dylibs_when_requested(self):
    runfiles = os.path.join(self.tmp, "runfiles")
    self._write_spec(runfiles, clang_rt=True, main_thread_checker=True)
    bundle = os.path.join(self.tmp, "Tests.xctest")
    os.makedirs(bundle)

    with mock.patch.object(
        deferred_test_linker, "copy_clang_runtime_dylibs"
    ) as clang_rt, mock.patch.object(
        deferred_test_linker, "copy_main_thread_checker_dylib"
    ) as mtc:
      self._run_main(runfiles, bundle, os.path.join(self.tmp, "work"))

    clang_rt.assert_called_once()
    self.assertEqual(
        clang_rt.call_args.kwargs["binary"], os.path.join(bundle, "Tests")
    )
    mtc.assert_called_once()

  def _write_spec(self, runfiles, argv=None, **overrides):
    _write(os.path.join(runfiles, "pkg", "main.o"), "object")
    _write(
        os.path.join(runfiles, "pkg", "inputs.txt"),
        "bazel-out/cfg/bin/pkg/main.o\tpkg/main.o\n",
    )
    fake_linker = os.path.join(self.tmp, "fake_linker")
    _write(fake_linker, _FAKE_LINKER)
    os.chmod(fake_linker, 0o755)
    if argv is None:
      argv = [
          fake_linker,
          "bazel-out/cfg/bin/pkg/main.o",
          "-o",
          "bazel-out/cfg/bin/pkg/Tests_bin",
      ]
    # Like the test rule, which writes the linker and its arguments from
    # separate `Args` objects.
    _write(os.path.join(runfiles, "pkg", "args_0.txt"), _gcc_quote(argv[:1]))
    _write(os.path.join(runfiles, "pkg", "args_1.txt"), _gcc_quote(argv[1:]))
    spec = {
        "argv_files": ["pkg/args_0.txt", "pkg/args_1.txt"],
        "codesign": False,
        "codesignopts": [],
        "env": {"ZERO_AR_DATE": "1"},
        "executable_name": "Tests",
        "inputs_manifest": "pkg/inputs.txt",
        "outputs": ["bazel-out/cfg/bin/pkg/Tests_bin"],
        "swift_stdlib_platform": None,
    }
    spec.update(overrides)
    _write(os.path.join(runfiles, "pkg", "spec.json"), json.dumps(spec))

  def _run_main(self, runfiles, bundle, work_dir):
    cwd = os.getcwd()
    os.chdir(runfiles)
    try:
      with mock.patch.object(
          deferred_test_linker,
          "link_environment",
          lambda _: {"DEVELOPER_DIR": "/dev", "PATH": os.environ["PATH"]},
      ):
        deferred_test_linker.main([
            "--spec",
            "pkg/spec.json",
            "--bundle",
            bundle,
            "--work_dir",
            work_dir,
        ])
    finally:
      os.chdir(cwd)

  def test_main_links_into_bundle_and_cleans_up(self):
    runfiles = os.path.join(self.tmp, "runfiles")
    self._write_spec(runfiles)
    bundle = os.path.join(self.tmp, "Tests.xctest")
    os.makedirs(bundle)
    work_dir = os.path.join(self.tmp, "work")

    self._run_main(runfiles, bundle, work_dir)

    binary = os.path.join(bundle, "Tests")
    with open(binary, encoding="utf-8") as f:
      self.assertEqual(f.read(), "object")
    self.assertTrue(os.stat(binary).st_mode & stat.S_IXUSR)
    self.assertFalse(os.path.exists(work_dir))

  def test_main_copies_swift_dylibs_when_requested(self):
    runfiles = os.path.join(self.tmp, "runfiles")
    self._write_spec(runfiles, swift_stdlib_platform="iphonesimulator")
    bundle = os.path.join(self.tmp, "Tests.xctest")
    os.makedirs(bundle)

    with mock.patch.object(deferred_test_linker, "copy_swift_dylibs") as copy:
      self._run_main(runfiles, bundle, os.path.join(self.tmp, "work"))

    copy.assert_called_once_with(
        binary=os.path.join(bundle, "Tests"),
        bundle=bundle,
        env={"DEVELOPER_DIR": "/dev", "PATH": os.environ["PATH"]},
        platform="iphonesimulator",
    )

  def test_main_reports_link_failures_without_traceback(self):
    runfiles = os.path.join(self.tmp, "runfiles")
    self._write_spec(runfiles, argv=["/usr/bin/false", "-o", "out"])
    bundle = os.path.join(self.tmp, "Tests.xctest")
    os.makedirs(bundle)
    work_dir = os.path.join(self.tmp, "work")

    with self.assertRaises(SystemExit) as e:
      self._run_main(runfiles, bundle, work_dir)
    self.assertEqual(e.exception.code, 1)
    self.assertFalse(os.path.exists(work_dir))

  def test_main_reports_invalid_spec_without_traceback(self):
    runfiles = os.path.join(self.tmp, "runfiles")
    _write(os.path.join(runfiles, "pkg", "spec.json"), "{}")
    bundle = os.path.join(self.tmp, "Tests.xctest")
    os.makedirs(bundle)

    with self.assertRaises(SystemExit) as e:
      self._run_main(runfiles, bundle, os.path.join(self.tmp, "work"))
    self.assertEqual(e.exception.code, 1)


if __name__ == "__main__":
  unittest.main()
