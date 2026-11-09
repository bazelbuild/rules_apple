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
2. The recorded link command line is run from that scratch execution root.
3. The linked binary is moved into the (already extracted) test bundle, which
   is then optionally ad-hoc codesigned.
4. The scratch execution root, including any linker byproducts, is deleted.

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

_ADHOC_IDENTITY = "-"


def _fail(message):
  print(f"error: {message}", file=sys.stderr)
  sys.exit(1)


def read_inputs_manifest(manifest_path):
  """Returns a list of `(exec_path, short_path)` tuples from the manifest."""
  entries = []
  with open(manifest_path, encoding="utf-8") as manifest:
    for line in manifest:
      line = line.rstrip("\n")
      if not line:
        continue
      exec_path, sep, short_path = line.partition("\t")
      if not sep:
        _fail(f"Malformed line in deferred link inputs manifest: {line!r}")
      entries.append((exec_path, short_path))
  return entries


def build_exec_root(*, exec_root, inputs, outputs, runfiles_root):
  """Recreates the link action's execution root with symlinks to runfiles.

  Args:
    exec_root: The directory to populate.
    inputs: A list of `(exec_path, short_path)` tuples for the link inputs.
    outputs: A list of execution root relative paths of the link outputs; their
      parent directories are created so the linker can write to them.
    runfiles_root: The directory that `short_path`s are relative to.
  """
  created_dirs = set()

  def ensure_dir(path):
    if path in created_dirs:
      return
    os.makedirs(path, exist_ok=True)
    created_dirs.add(path)

  missing = []
  for exec_path, short_path in inputs:
    source = os.path.normpath(os.path.join(runfiles_root, short_path))
    if not os.path.lexists(source):
      missing.append(short_path)
      continue
    destination = os.path.join(exec_root, exec_path)
    if os.path.lexists(destination):
      # The same file may be listed more than once (e.g. it is both a tool and
      # an input); the first one wins.
      continue
    ensure_dir(os.path.dirname(destination))
    os.symlink(source, destination)

  if missing:
    shown = "\n  ".join(missing[:20])
    more = f"\n  ... and {len(missing) - 20} more" if len(missing) > 20 else ""
    _fail(
        "The following inputs of the deferred test bundle link were not found "
        f"in the test's runfiles:\n  {shown}{more}"
    )

  for output in outputs:
    ensure_dir(os.path.dirname(os.path.join(exec_root, output)))


def _xcrun_sdk_path(*, developer_dir, platform, version):
  env = dict(os.environ, DEVELOPER_DIR=developer_dir)
  sdks = [f"{platform}{version}", platform] if version else [platform]
  for sdk in sdks:
    result = subprocess.run(
        ["/usr/bin/xcrun", "--sdk", sdk, "--show-sdk-path"],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode == 0 and result.stdout.strip():
      return result.stdout.strip()
  _fail(f"Unable to locate the '{sdks[0]}' SDK with 'xcrun --show-sdk-path'.")
  return None


def link_environment(action_env):
  """Returns the environment to run the link command line with.

  Bazel resolves `DEVELOPER_DIR` and `SDKROOT` for Apple actions at execution
  time, so they are not part of the recorded action environment and need to be
  computed here, the same way `xcrun` would.

  Args:
    action_env: The environment recorded for the link action.

  Returns:
    A dictionary with the full environment for the linker invocation.
  """
  env = dict(os.environ)
  for key, value in action_env.items():
    # Keep the test's PATH; the recorded one is the action's default shell
    # environment which is rarely more useful.
    if key == "PATH" and "PATH" in env:
      continue
    env[key] = value

  developer_dir = os.environ.get("DEVELOPER_DIR")
  if not developer_dir:
    developer_dir = subprocess.run(
        ["/usr/bin/xcode-select", "-p"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()
  env["DEVELOPER_DIR"] = developer_dir

  platform = action_env.get("APPLE_SDK_PLATFORM")
  if platform:
    env["SDKROOT"] = _xcrun_sdk_path(
        developer_dir=developer_dir,
        platform=platform.lower(),
        version=action_env.get("APPLE_SDK_VERSION_OVERRIDE", ""),
    )
  return env


def link_output_path(argv):
  """Returns the binary path the command line writes, i.e. the `-o` value."""
  for index, arg in enumerate(argv[:-1]):
    if arg == "-o":
      return argv[index + 1]
  _fail("Could not find the '-o' output of the deferred link command line.")
  return None


def _codesign(path, extra_args=()):
  subprocess.run(
      [
          "/usr/bin/codesign",
          "--force",
          "--sign",
          _ADHOC_IDENTITY,
          "--timestamp=none",
          *extra_args,
          path,
      ],
      check=True,
  )


def codesign_bundle(bundle, codesignopts):
  """Ad-hoc signs the bundle's nested code and then the bundle itself."""
  frameworks_dir = os.path.join(bundle, "Frameworks")
  if os.path.isdir(frameworks_dir):
    for name in sorted(os.listdir(frameworks_dir)):
      if name.endswith((".framework", ".dylib")):
        _codesign(os.path.join(frameworks_dir, name))
  _codesign(bundle, codesignopts)


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

  with open(args.spec, encoding="utf-8") as spec_file:
    spec = json.load(spec_file)

  runfiles_root = os.getcwd()
  exec_root = os.path.join(os.path.abspath(args.work_dir), "execroot")
  link_argv = spec["argv"]
  output = link_output_path(link_argv)

  start = time.monotonic()
  try:
    build_exec_root(
        exec_root=exec_root,
        inputs=read_inputs_manifest(spec["inputs_manifest"]),
        outputs=spec["outputs"],
        runfiles_root=runfiles_root,
    )
    result = subprocess.run(
        link_argv,
        cwd=exec_root,
        env=link_environment(spec["env"]),
        check=False,
    )
    if result.returncode != 0:
      _fail(
          f"Linking the test bundle binary failed with exit code {result.returncode}."
      )

    destination = os.path.join(args.bundle, spec["executable_name"])
    if os.path.lexists(destination):
      os.remove(destination)
    shutil.move(os.path.join(exec_root, output), destination)
    os.chmod(destination, 0o755)
  finally:
    shutil.rmtree(args.work_dir, ignore_errors=True)

  if spec.get("codesign"):
    codesign_bundle(args.bundle, spec.get("codesignopts", []))

  print(
      f"note: Linked test bundle binary '{spec['executable_name']}' in "
      f"{time.monotonic() - start:.2f}s"
  )


if __name__ == "__main__":
  main(sys.argv[1:])
