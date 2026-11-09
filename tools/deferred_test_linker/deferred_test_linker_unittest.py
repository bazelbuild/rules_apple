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
import plistlib
import shlex
import stat
import sys
import tempfile
import textwrap
import unittest
from unittest import mock

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
        "TEST_TMPDIR": "/tmp/test",
    }
    with mock.patch.dict(os.environ, test_env, clear=True), mock.patch.object(
        deferred_test_linker, "_installed_xcode_version",
        return_value=(None, None),
    ), mock.patch.object(
        deferred_test_linker, "_xcrun_sdk_path", return_value="/sdk"
    ):
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

  def test_link_environment_fails_on_xcode_mismatch(self):
    with mock.patch.dict(
        os.environ, {"DEVELOPER_DIR": "/Xcode.app/Contents/Developer"},
        clear=True,
    ), mock.patch.object(
        deferred_test_linker, "_installed_xcode_version",
        return_value=("26.0", "17A100"),
    ):
      with self.assertRaisesRegex(
          deferred_test_linker.LinkError, "configured to link with Xcode"
      ):
        deferred_test_linker.link_environment(
            {"XCODE_VERSION_OVERRIDE": "26.0.0.17A324"}
        )

  def test_xcode_version_mismatch(self):
    developer_dir = os.path.join(self.tmp, "Xcode.app", "Contents", "Developer")
    os.makedirs(developer_dir)
    with open(
        os.path.join(os.path.dirname(developer_dir), "version.plist"), "wb"
    ) as f:
      plistlib.dump(
          {"CFBundleShortVersionString": "26.0", "ProductBuildVersion": "17A324"},
          f,
      )

    mismatch = deferred_test_linker.xcode_version_mismatch
    for override in ("26.0.0.17A324", "26.0", "26.0.0", "26"):
      self.assertIsNone(mismatch(override, developer_dir), override)
      # A trailing slash doesn't hide the installed version.
      self.assertIsNone(mismatch(override, developer_dir + "/"), override)
    self.assertEqual(mismatch("26.0.0.17A100", developer_dir), "build 17A324")
    self.assertEqual(mismatch("26.1", developer_dir), "version 26.0")
    self.assertEqual(
        mismatch("26.1", developer_dir + "/"), "version 26.0"
    )
    self.assertIsNone(mismatch("", developer_dir))
    # Unknown when there is no version.plist.
    self.assertIsNone(mismatch("26.1", self.tmp))

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

  def test_xcrun_sdk_path_does_not_fall_back_to_another_sdk(self):
    with mock.patch.object(
        deferred_test_linker,
        "_run",
        side_effect=deferred_test_linker.LinkError("no such SDK"),
    ) as run:
      with self.assertRaisesRegex(
          deferred_test_linker.LinkError, "'iphonesimulator99.0' SDK"
      ):
        deferred_test_linker._xcrun_sdk_path(
            developer_dir="/dev",
            platform="iphonesimulator",
            version="99.0",
        )
    self.assertEqual(run.call_count, 1)

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
