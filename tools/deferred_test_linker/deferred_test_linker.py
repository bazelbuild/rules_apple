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
"""Links an Apple test bundle's binary inside of the test action.

When the `apple.defer_test_bundle_linking` feature is enabled, the test bundle
is built without its executable and the test action receives the unlinked
inputs of the bundle's link action instead. This tool replays that link action
at test time:

1. A scratch "execution root" is created by symlinking every link input from
   its runfiles location to the execution root relative path the link action's
   command line refers to.
2. The linker is run from there with the command line files that the test rule
   wrote from the link action's `Args`, as params files like Bazel would.
3. The linked binary is moved into the (already extracted) test bundle, the
   dylibs that are bundled based on it are copied with the same tools as at
   build time, and the bundle is optionally ad-hoc codesigned.

The spec written by the test rule is a JSON object with:

*   `argv_files`: Runfiles paths of the link command line files. The first one
    only contains the linker.
*   `env`: The environment of the link action.
*   `inputs_manifest`: Runfiles path of a file with an `exec_path\tshort_path`
    line per link input.
*   `output`: Execution root relative path of the linked binary.
*   `executable_name`: The name of the binary in the bundle.
*   `swift_stdlib_platform`: The platform to copy Swift dylibs for, or `null`.
*   `clang_rt`: Whether to copy the sanitizer runtime dylibs.
*   `main_thread_checker`: Whether to copy `libMainThreadChecker.dylib`.
*   `codesign` and `codesignopts`: Whether to sign the bundle, and the extra
    options to sign it with.

The caller owns the extracted test bundle and is responsible for deleting the
linked binary once the tests have run.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
import zipfile

from tools.clangrttool import clangrttool
from tools.codesigningtool import codesigningtool
from tools.swift_stdlib_tool import swift_stdlib_tool

# The tool that copies `libMainThreadChecker.dylib` at build time, from the
# runfiles of this tool.
_MAIN_THREAD_CHECKER_TOOL = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    os.pardir,
    "main_thread_checker_tool",
    "main_thread_checker_tool.sh",
)

# Environment variables of the test action that are passed to the linker. The
# rest (e.g. `DYLD_*`, `TEST_*` or `COVERAGE*`) are meant for the test and
# could change the linker's behavior; Bazel wouldn't set them for the link
# action either. Bazel resolves `DEVELOPER_DIR` and `SDKROOT` for the test
# action from the link action's Xcode and SDK variables, which the test rule
# gives it, just as it does for the link action.
_PASSTHROUGH_ENV = (
    "DEVELOPER_DIR",
    "HOME",
    "LANG",
    "PATH",
    "SDKROOT",
    "TMPDIR",
    "USER",
)


class LinkError(Exception):
  """An error that is reported without a traceback."""


def read_inputs_manifest(manifest_path):
  """Returns a list of `(exec_path, short_path)` tuples from the manifest."""
  with open(manifest_path, encoding="utf-8") as manifest:
    return [
        tuple(line.rstrip("\n").split("\t", 1)) for line in manifest if line
    ]


def _runfile_matches(path, exec_path):
  """Returns whether a runfiles entry is the file at `exec_path`.

  Runfiles are keyed by `short_path`, so files from different configurations
  with the same `short_path` collapse into one entry. Local and sandboxed
  runfiles are (chains of) symlinks into the execution root, so following them
  one link at a time reveals which output an entry really is. Outputs can
  themselves be symlinks to other outputs (e.g. a single architecture `lipo`),
  so any link in the chain may match. Entries that can't be checked, such as
  copied runfiles (e.g. remote execution), are assumed to match.
  """
  if not exec_path.startswith("bazel-out/"):
    return True
  seen_output = False
  current = path
  for _ in range(40):
    if not os.path.islink(current):
      break
    current = os.path.normpath(
        os.path.join(os.path.dirname(current), os.readlink(current))
    )
    index = current.find("/bazel-out/")
    if index == -1:
      continue
    output = current[index + 1:]
    if output == exec_path:
      return True
    # Runfiles trees are in `bazel-out` too, but aren't outputs.
    seen_output = seen_output or ".runfiles/" not in output
  return not seen_output


def build_exec_root(*, exec_root, inputs, output, runfiles_root):
  """Recreates the link action's execution root with symlinks to runfiles.

  Args:
    exec_root: The directory to populate.
    inputs: A list of `(exec_path, short_path)` tuples for the link inputs.
    output: The execution root relative path of the linked binary; its parent
      directory is created so the linker can write to it.
    runfiles_root: The directory that `short_path`s are relative to.
  """
  problems = []
  for exec_path, short_path in inputs:
    source = os.path.normpath(os.path.join(runfiles_root, short_path))
    if not os.path.lexists(source):
      problems.append(f"{short_path}: not found in the test's runfiles")
      continue
    if not _runfile_matches(source, exec_path):
      problems.append(
          f"{short_path}: the test's runfiles contain another file at this "
          f"location (e.g. one built in a different configuration) than "
          f"{exec_path}"
      )
      continue
    destination = os.path.join(exec_root, exec_path)
    # The same file may be listed more than once.
    if not os.path.lexists(destination):
      os.makedirs(os.path.dirname(destination), exist_ok=True)
      os.symlink(source, destination)
  if problems:
    raise LinkError(
        "Some inputs of the deferred test bundle link can't be provided:\n  "
        + "\n  ".join(problems[:20])
    )
  os.makedirs(os.path.dirname(os.path.join(exec_root, output)), exist_ok=True)


def link_environment(action_env):
  """Returns the environment to run the link command line with."""
  env = {k: os.environ[k] for k in _PASSTHROUGH_ENV if k in os.environ}
  # Keep the test's PATH; the recorded one is the action's default shell
  # environment which is rarely more useful.
  env.update({k: v for k, v in action_env.items() if k not in env})
  return env


def _read_linker(argv_file):
  """Returns the linker from the first command line file."""
  with open(argv_file, encoding="utf-8") as f:
    lines = f.read().splitlines()
  if len(lines) != 1:
    raise LinkError(f"Expected only the linker in '{argv_file}'.")
  return lines[0]


def link(*, spec, bundle, work_dir, runfiles_root):
  """Links the test bundle's binary described by `spec` into `bundle`."""
  exec_root = os.path.join(os.path.abspath(work_dir), "execroot")
  argv_files = [os.path.abspath(f) for f in spec["argv_files"]]
  # The shared tools below read the process environment.
  env = link_environment(spec["env"])
  os.environ.clear()
  os.environ.update(env)
  binary = os.path.join(bundle, spec["executable_name"])
  frameworks_dir = os.path.join(bundle, "Frameworks")

  try:
    build_exec_root(
        exec_root=exec_root,
        inputs=read_inputs_manifest(spec["inputs_manifest"]),
        output=spec["output"],
        runfiles_root=runfiles_root,
    )
    subprocess.run(
        [_read_linker(argv_files[0])] + [f"@{f}" for f in argv_files[1:]],
        cwd=exec_root,
        check=True,
    )
    if os.path.lexists(binary):
      os.remove(binary)
    shutil.move(os.path.join(exec_root, spec["output"]), binary)

    if spec["swift_stdlib_platform"]:
      swift_stdlib_tool.main([
          "--binary", binary,
          "--platform", spec["swift_stdlib_platform"],
          "--output_path", frameworks_dir,
          "--strip_bitcode",
      ])

    if spec["clang_rt"]:
      clang_rt_zip = os.path.join(work_dir, "clang_rt.zip")
      clangrttool.ClangRuntimeTool(binary, clang_rt_zip).run()
      with zipfile.ZipFile(clang_rt_zip) as archive:
        archive.extractall(frameworks_dir)

    if spec["main_thread_checker"]:
      os.makedirs(frameworks_dir, exist_ok=True)
      subprocess.run(
          [
              "/bin/bash",
              _MAIN_THREAD_CHECKER_TOOL,
              os.path.join(frameworks_dir, "libMainThreadChecker.dylib"),
          ],
          check=True,
      )
  finally:
    shutil.rmtree(work_dir, ignore_errors=True)

  if spec["codesign"]:
    codesign_bundle(bundle, spec["codesignopts"])


def codesign_bundle(bundle, codesignopts):
  """Ad-hoc signs the bundle's nested code and then the bundle itself."""
  frameworks_dir = os.path.join(bundle, "Frameworks")
  nested = sorted(
      os.path.join(frameworks_dir, name)
      for name in (
          os.listdir(frameworks_dir) if os.path.isdir(frameworks_dir) else []
      )
      if name.endswith((".framework", ".dylib"))
  )
  for path in nested + [bundle]:
    codesigningtool.invoke_codesign(
        codesign_path="/usr/bin/codesign",
        identity="-",
        entitlements=None,
        force_signing=True,
        disable_timestamp=True,
        full_path_to_sign=path,
        extra=codesignopts if path == bundle else [],
    )


def main(argv):
  parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
  parser.add_argument(
      "--spec",
      required=True,
      help="Path to the JSON link spec generated by the test rule.",
  )
  parser.add_argument(
      "--bundle",
      required=True,
      help="Path to the extracted test bundle that receives the binary.",
  )
  parser.add_argument(
      "--work_dir",
      required=True,
      help="Scratch directory for the link; it is deleted when done.",
  )
  args = parser.parse_args(argv)

  start = time.monotonic()
  try:
    with open(args.spec, encoding="utf-8") as spec_file:
      spec = json.load(spec_file)
    link(
        spec=spec,
        bundle=args.bundle,
        work_dir=args.work_dir,
        runfiles_root=os.getcwd(),
    )
  except (
      LinkError,
      OSError,
      KeyError,
      ValueError,
      subprocess.CalledProcessError,
      clangrttool.ClangRuntimeToolError,
  ) as e:
    print(f"error: Linking the test bundle binary failed: {e}", file=sys.stderr)
    sys.exit(1)

  print(
      f"note: Linked test bundle binary '{spec['executable_name']}' in "
      f"{time.monotonic() - start:.2f}s"
  )


if __name__ == "__main__":
  main(sys.argv[1:])
