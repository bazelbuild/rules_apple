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
2. The link command line, which the test rule wrote from the link action's
   `Args`, is run from that scratch execution root, through a params file so it
   isn't limited by `ARG_MAX`.
3. The linked binary is moved into the (already extracted) test bundle, along
   with any Swift dylibs it needs, and the bundle is optionally ad-hoc
   codesigned.
4. The scratch execution root, including any linker byproducts, is deleted.

The caller owns the extracted test bundle and is responsible for deleting the
linked binary once the tests have run.
"""

import argparse
import contextlib
import json
import os
import plistlib
import re
import shutil
import subprocess
import sys
import time
import zipfile

from tools.clangrttool import clangrttool
from tools.swift_stdlib_tool import swift_stdlib_tool

_ADHOC_IDENTITY = "-"

# The tool that copies `libMainThreadChecker.dylib` at build time, from the
# runfiles of this tool.
_MAIN_THREAD_CHECKER_TOOL = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    os.pardir,
    "main_thread_checker_tool",
    "main_thread_checker_tool.sh",
)

# An Xcode build version, e.g. `17A324` or `16E5104a`.
_XCODE_BUILD_VERSION_RE = re.compile(r"\d+[A-Z]\d+[a-z]?")

# Environment variables of the test action that are passed to the linker. The
# rest (e.g. `DYLD_*`, `TEST_*` or `COVERAGE*`) are meant for the test and
# could change the linker's behavior; Bazel wouldn't set them for the link
# action either.
_PASSTHROUGH_ENV = ("HOME", "LANG", "PATH", "TMPDIR", "USER")


class LinkError(Exception):
  """An error that is reported without a traceback."""


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
        raise LinkError(
            f"Malformed line in deferred link inputs manifest: {line!r}"
        )
      entries.append((exec_path, short_path))
  return entries


def parse_args_file(content):
  """Returns the arguments of a file written from a Starlark `Args` object.

  Bazel writes the link action's `Args` with GCC style quoting, e.g. `a\\ b`
  for the argument `a b`. This parses it like GCC and clang read `@file`s:
  arguments are separated by unescaped whitespace, a backslash escapes the next
  character, and single or double quotes group characters. Like with any
  params file that Bazel writes this way, empty arguments are lost.

  Args:
    content: The contents of the file.

  Returns:
    The list of arguments.
  """
  args = []
  current = []
  in_arg = False
  quote = None
  escaped = False
  for char in content:
    if escaped:
      current.append(char)
      escaped = False
    elif char == "\\":
      escaped = True
      in_arg = True
    elif quote:
      if char == quote:
        quote = None
      else:
        current.append(char)
    elif char in ("'", '"'):
      quote = char
      in_arg = True
    elif char.isspace():
      if in_arg:
        args.append("".join(current))
        current = []
        in_arg = False
    else:
      current.append(char)
      in_arg = True
  if quote or escaped:
    raise LinkError("Unterminated quote or escape in the link command line.")
  if in_arg:
    args.append("".join(current))
  return args


def read_link_argv(paths):
  """Returns the link command line from the files written by the test rule."""
  argv = []
  for path in paths:
    with open(path, encoding="utf-8") as f:
      argv.extend(parse_args_file(f.read()))
  if not argv:
    raise LinkError("The deferred link command line is empty.")
  return argv


def _check_runfiles_collisions(inputs):
  """Fails if different link inputs share a runfiles location.

  Runfiles are keyed by `short_path`, so files from different configurations
  with the same `short_path` collapse into one entry and the link would
  silently use the wrong one.
  """
  exec_paths_by_short_path = {}
  for exec_path, short_path in inputs:
    exec_paths_by_short_path.setdefault(short_path, set()).add(exec_path)
  collisions = {
      short_path: sorted(exec_paths)
      for short_path, exec_paths in exec_paths_by_short_path.items()
      if len(exec_paths) > 1
  }
  if collisions:
    details = "\n".join(
        f"  {short_path}: {', '.join(exec_paths)}"
        for short_path, exec_paths in sorted(collisions.items())[:20]
    )
    raise LinkError(
        "The following inputs of the deferred test bundle link share a "
        "runfiles location, so they can't all be provided to the test:\n"
        f"{details}"
    )


def build_exec_root(*, exec_root, inputs, outputs, runfiles_root):
  """Recreates the link action's execution root with symlinks to runfiles.

  Args:
    exec_root: The directory to populate.
    inputs: A list of `(exec_path, short_path)` tuples for the link inputs.
    outputs: A list of execution root relative paths of the link outputs; their
      parent directories are created so the linker can write to them.
    runfiles_root: The directory that `short_path`s are relative to.
  """
  _check_runfiles_collisions(inputs)

  created_dirs = set()

  def ensure_dir(path):
    if path in created_dirs:
      return
    os.makedirs(path, exist_ok=True)
    created_dirs.add(path)

  missing = []
  mismatched = []
  for exec_path, short_path in inputs:
    source = os.path.normpath(os.path.join(runfiles_root, short_path))
    if not os.path.lexists(source):
      missing.append(short_path)
      continue
    if not _runfile_matches(source, exec_path):
      mismatched.append((short_path, exec_path, os.path.realpath(source)))
      continue
    destination = os.path.join(exec_root, exec_path)
    if os.path.lexists(destination):
      # The same file may be listed more than once (e.g. it is both a tool and
      # an input).
      continue
    ensure_dir(os.path.dirname(destination))
    os.symlink(source, destination)

  if missing:
    shown = "\n  ".join(missing[:20])
    more = f"\n  ... and {len(missing) - 20} more" if len(missing) > 20 else ""
    raise LinkError(
        "The following inputs of the deferred test bundle link were not found "
        f"in the test's runfiles:\n  {shown}{more}"
    )

  if mismatched:
    details = "\n".join(
        f"  {short_path}: expected {exec_path}, found {resolved}"
        for short_path, exec_path, resolved in mismatched[:20]
    )
    raise LinkError(
        "The following inputs of the deferred test bundle link share a "
        "runfiles location with another file of the test (e.g. one built in a "
        "different configuration), so the test's runfiles contain the other "
        f"file:\n{details}"
    )

  for output in outputs:
    ensure_dir(os.path.dirname(os.path.join(exec_root, output)))


def _runfile_matches(path, exec_path):
  """Returns whether a runfiles entry is the file at `exec_path`.

  Local and sandboxed runfiles are (chains of) symlinks into the execution
  root, so following them one link at a time reveals which output a runfiles
  entry really is. Outputs can themselves be symlinks to other outputs (e.g. a
  single architecture `lipo`), so any link in the chain may match. Entries that
  can't be checked, such as copied runfiles (e.g. remote execution) or chains
  that never point into `bazel-out`, are assumed to match.
  """
  if not exec_path.startswith("bazel-out/"):
    return True
  marker = "/bazel-out/"
  seen_output = False
  current = path
  for _ in range(40):
    if not os.path.islink(current):
      break
    target = os.readlink(current)
    current = os.path.normpath(
        os.path.join(os.path.dirname(current), target)
    )
    index = current.find(marker)
    if index == -1:
      continue
    output = current[index + 1:]
    if output == exec_path:
      return True
    # Runfiles trees are in `bazel-out` too, but aren't outputs.
    if ".runfiles/" not in output:
      seen_output = True
  return not seen_output


def _run(cmd, **kwargs):
  """Runs `cmd`, raising a `LinkError` with its output if it fails."""
  try:
    return subprocess.run(
        cmd, capture_output=True, text=True, check=True, **kwargs
    )
  except FileNotFoundError as e:
    raise LinkError(f"Unable to run '{cmd[0]}': {e}") from e
  except subprocess.CalledProcessError as e:
    output = "\n".join(o.strip() for o in (e.stdout, e.stderr) if o)
    raise LinkError(
        f"'{' '.join(cmd)}' failed with exit code {e.returncode}"
        + (f":\n{output}" if output else ".")
    ) from e


def _installed_xcode_version(developer_dir):
  """Returns the `(version, build)` of an Xcode, or `(None, None)`."""
  version_plist = os.path.join(
      os.path.dirname(os.path.normpath(developer_dir)), "version.plist"
  )
  try:
    with open(version_plist, "rb") as f:
      info = plistlib.load(f)
  except (OSError, plistlib.InvalidFileException):
    return None, None
  return info.get("CFBundleShortVersionString"), info.get("ProductBuildVersion")


def _normalized_version(version):
  """Returns `version` (e.g. `26.0.0`) without trailing zero components."""
  components = version.split(".")
  while len(components) > 1 and components[-1] == "0":
    components.pop()
  return ".".join(components)


def xcode_version_mismatch(override, developer_dir):
  """Returns a description of the installed Xcode if it isn't `override`.

  Args:
    override: The `XCODE_VERSION_OVERRIDE` of the link action, e.g.
      `26.0.0.17A324` or, for hand written `xcode_version` targets, `26.0`.
    developer_dir: The `DEVELOPER_DIR` of the Xcode that will be used.

  Returns:
    `None` if the Xcode matches `override`, or if either version is unknown.
  """
  if not override:
    return None
  version, build = _installed_xcode_version(developer_dir)
  components = override.split(".")
  if _XCODE_BUILD_VERSION_RE.fullmatch(components[-1]):
    if build and build != components[-1]:
      return f"build {build}"
    return None
  if version and (
      _normalized_version(version) != _normalized_version(override)
  ):
    return f"version {version}"
  return None


def _developer_dir(action_env):
  """Returns the `DEVELOPER_DIR` to link with.

  Bazel resolves `DEVELOPER_DIR` from `XCODE_VERSION_OVERRIDE` at execution
  time, so it isn't part of the recorded action environment. The test rule
  gives the test action the link action's `XCODE_VERSION_OVERRIDE`, so Bazel
  resolves the same one for it when it runs locally. Executors that don't
  (e.g. some remote ones) fall back to the selected Xcode, as long as it is
  the one the build was configured with.
  """
  developer_dir = os.environ.get("DEVELOPER_DIR")
  if not developer_dir:
    developer_dir = _run(["/usr/bin/xcode-select", "-p"]).stdout.strip()

  override = action_env.get("XCODE_VERSION_OVERRIDE", "")
  mismatch = xcode_version_mismatch(override, developer_dir)
  if mismatch:
    raise LinkError(
        f"The test bundle was configured to link with Xcode {override}, but "
        f"the test action's Xcode at '{developer_dir}' is {mismatch}. Set "
        "DEVELOPER_DIR for the test to the matching Xcode."
    )
  return developer_dir


def _xcrun_sdk_path(*, developer_dir, platform, version):
  sdk = f"{platform}{version}"
  try:
    path = _run(
        ["/usr/bin/xcrun", "--sdk", sdk, "--show-sdk-path"],
        env=dict(os.environ, DEVELOPER_DIR=developer_dir),
    ).stdout.strip()
  except LinkError as e:
    raise LinkError(
        f"Unable to locate the '{sdk}' SDK in '{developer_dir}': {e}"
    ) from e
  if not path:
    raise LinkError(f"Unable to locate the '{sdk}' SDK in '{developer_dir}'.")
  return path


def link_environment(action_env):
  """Returns the environment to run the link command line with.

  Args:
    action_env: The environment recorded for the link action.

  Returns:
    A dictionary with the full environment for the linker invocation.
  """
  env = {k: os.environ[k] for k in _PASSTHROUGH_ENV if k in os.environ}
  for key, value in action_env.items():
    # Keep the test's PATH; the recorded one is the action's default shell
    # environment which is rarely more useful.
    if key == "PATH" and "PATH" in env:
      continue
    env[key] = value

  developer_dir = _developer_dir(action_env)
  env["DEVELOPER_DIR"] = developer_dir

  platform = action_env.get("APPLE_SDK_PLATFORM")
  if platform and os.environ.get("SDKROOT") and (
      os.environ.get("DEVELOPER_DIR") == developer_dir
  ):
    # Resolved by Bazel from the same `APPLE_SDK_*` variables.
    env["SDKROOT"] = os.environ["SDKROOT"]
  elif platform:
    env["SDKROOT"] = _xcrun_sdk_path(
        developer_dir=developer_dir,
        platform=platform.lower(),
        version=action_env.get("APPLE_SDK_VERSION_OVERRIDE", ""),
    )
  return env


def link_output_path(argv, outputs):
  """Returns the binary path the command line writes, i.e. its `-o` value.

  Args:
    argv: The link command line.
    outputs: The execution root relative paths of the link action's outputs.
      Of several `-o` arguments (e.g. one passed through `linkopts`), the one
      naming an output of the action wins.

  Returns:
    The execution root relative path of the linked binary.
  """
  candidates = [
      argv[index + 1]
      for index, arg in enumerate(argv[:-1])
      if arg == "-o"
  ]
  for candidate in candidates:
    if candidate in outputs:
      return candidate
  if candidates:
    return candidates[-1]
  raise LinkError(
      "Could not find the '-o' output of the deferred link command line."
  )


def _quote_param(arg):
  """Quotes an argument for a clang (and `wrapped_clang`) params file."""
  return '"' + arg.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_params_file(path, args):
  """Writes `args` to a params file, one quoted argument per line."""
  for arg in args:
    # `wrapped_clang` reads one argument per line, quoted or not.
    if "\n" in arg:
      raise LinkError(
          f"Link arguments can't contain newlines, but {arg!r} does."
      )
  with open(path, "w", encoding="utf-8") as params_file:
    for arg in args:
      params_file.write(_quote_param(arg))
      params_file.write("\n")


@contextlib.contextmanager
def _environment(env):
  """Temporarily replaces `os.environ` for tools that read it."""
  saved = dict(os.environ)
  os.environ.clear()
  os.environ.update(env)
  try:
    yield
  finally:
    os.environ.clear()
    os.environ.update(saved)


def copy_swift_dylibs(*, binary, bundle, env, platform):
  """Copies the Swift dylibs that `binary` needs into the bundle.

  This runs the same tool, with the same options, as the `SwiftStdlibCopy`
  action that copies them for test bundles linked at build time.
  """
  try:
    with _environment(env):
      swift_stdlib_tool.main([
          "--binary",
          binary,
          "--platform",
          platform,
          "--output_path",
          os.path.join(bundle, "Frameworks"),
          "--strip_bitcode",
      ])
  except (OSError, subprocess.CalledProcessError) as e:
    raise LinkError(f"Copying the Swift dylibs failed: {e}") from e


def copy_clang_runtime_dylibs(*, binary, bundle, env, work_dir):
  """Copies the sanitizer runtime dylibs that `binary` needs into the bundle.

  This runs the same tool as the `ClangRuntimeLibsCopy` action that copies
  them for test bundles linked at build time.
  """
  clang_rt_zip = os.path.join(work_dir, "clang_rt.zip")
  os.makedirs(work_dir, exist_ok=True)
  try:
    with _environment(env):
      clangrttool.ClangRuntimeTool(binary, clang_rt_zip).run()
    with zipfile.ZipFile(clang_rt_zip) as archive:
      archive.extractall(os.path.join(bundle, "Frameworks"))
  except (
      OSError,
      subprocess.CalledProcessError,
      clangrttool.ClangRuntimeToolError,
  ) as e:
    raise LinkError(f"Copying the Clang runtime dylibs failed: {e}") from e
  finally:
    shutil.rmtree(work_dir, ignore_errors=True)


def copy_main_thread_checker_dylib(*, bundle, env):
  """Copies `libMainThreadChecker.dylib` into the bundle.

  This runs the same tool as the `MainThreadCheckerLibsCopy` action that
  copies it for test bundles linked at build time.
  """
  frameworks_dir = os.path.join(bundle, "Frameworks")
  os.makedirs(frameworks_dir, exist_ok=True)
  _run(
      [
          "/bin/bash",
          _MAIN_THREAD_CHECKER_TOOL,
          os.path.join(frameworks_dir, "libMainThreadChecker.dylib"),
      ],
      env=env,
  )


def _codesign(path, extra_args=()):
  _run([
      "/usr/bin/codesign",
      "--force",
      "--sign",
      _ADHOC_IDENTITY,
      "--timestamp=none",
      *extra_args,
      path,
  ])


def codesign_bundle(bundle, codesignopts):
  """Ad-hoc signs the bundle's nested code and then the bundle itself."""
  frameworks_dir = os.path.join(bundle, "Frameworks")
  if os.path.isdir(frameworks_dir):
    for name in sorted(os.listdir(frameworks_dir)):
      if name.endswith((".framework", ".dylib")):
        _codesign(os.path.join(frameworks_dir, name))
  _codesign(bundle, codesignopts)


def link(*, spec, bundle, work_dir, runfiles_root):
  """Links the test bundle's binary described by `spec` into `bundle`."""
  exec_root = os.path.join(os.path.abspath(work_dir), "execroot")
  link_argv = read_link_argv(spec["argv_files"])
  output = link_output_path(link_argv, spec["outputs"])
  env = link_environment(spec["env"])

  try:
    build_exec_root(
        exec_root=exec_root,
        inputs=read_inputs_manifest(spec["inputs_manifest"]),
        outputs=spec["outputs"],
        runfiles_root=runfiles_root,
    )

    # The command line of a large link can exceed `ARG_MAX`, so it is passed
    # through a params file like Bazel would.
    params_file = os.path.join(os.path.abspath(work_dir), "link.params")
    write_params_file(params_file, link_argv[1:])
    try:
      result = subprocess.run(
          [link_argv[0], f"@{params_file}"],
          cwd=exec_root,
          env=env,
          check=False,
      )
    except OSError as e:
      raise LinkError(f"Unable to run the linker '{link_argv[0]}': {e}") from e
    if result.returncode != 0:
      raise LinkError(
          "Linking the test bundle binary failed with exit code "
          f"{result.returncode}."
      )

    linked_binary = os.path.join(exec_root, output)
    if not os.path.isfile(linked_binary):
      raise LinkError(
          f"The linker didn't produce the expected output '{output}'."
      )
    destination = os.path.join(bundle, spec["executable_name"])
    if os.path.lexists(destination):
      os.remove(destination)
    shutil.move(linked_binary, destination)
    os.chmod(destination, 0o755)
  finally:
    shutil.rmtree(work_dir, ignore_errors=True)

  if spec.get("swift_stdlib_platform"):
    copy_swift_dylibs(
        binary=destination,
        bundle=bundle,
        env=env,
        platform=spec["swift_stdlib_platform"],
    )

  if spec.get("clang_rt"):
    copy_clang_runtime_dylibs(
        binary=destination,
        bundle=bundle,
        env=env,
        work_dir=work_dir,
    )

  if spec.get("main_thread_checker"):
    copy_main_thread_checker_dylib(bundle=bundle, env=env)

  if spec.get("codesign"):
    codesign_bundle(bundle, spec.get("codesignopts", []))


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
  except (LinkError, OSError) as e:
    _fail(str(e))
  except (KeyError, ValueError) as e:
    _fail(f"Invalid deferred link spec '{args.spec}': {e!r}")

  print(
      f"note: Linked test bundle binary '{spec['executable_name']}' in "
      f"{time.monotonic() - start:.2f}s"
  )


if __name__ == "__main__":
  main(sys.argv[1:])
