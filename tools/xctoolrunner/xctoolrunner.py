# Lint as: python2, python3
# Copyright 2018 The Bazel Authors. All rights reserved.
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

"""Wrapper for "xcrun" tools.

This script only runs on Darwin and you must have Xcode installed.

Usage:

  xctoolrunner [SUBCOMMAND] [<args>...]

Subcommands:
  actool [<args>...]

  coremlc [<args>...]

  ibtool [<args>...]

  mapc [<args>...]

  momc [<args>...]

  swift-stdlib-tool [OUTPUT] [BUNDLE] [<args>...]
      OUTPUT: The path to place the output zip file.
      BUNDLE: The path inside of the archive to where the libs will be copied.
"""

import argparse
import os
import re
import shutil
import sys
import tempfile
import time

from build_bazel_rules_apple.tools.wrapper_common import execute

# This prefix is set for rules_apple rules in:
# apple/internal/utils/xctoolrunner.bzl
_PATH_PREFIX = "[ABSOLUTE]"
_PATH_PREFIX_LEN = len(_PATH_PREFIX)


def _apply_realpath(argv):
  """Run "realpath" on any path-related arguments.

  Paths passed into the tool will be prefixed with the contents of _PATH_PREFIX.
  If we find an argument with this prefix, we strip out the prefix and run
  "realpath".

  Args:
    argv: A list of command line arguments.
  """
  for i, arg in enumerate(argv):
    if arg.startswith(_PATH_PREFIX):
      arg = arg[_PATH_PREFIX_LEN:]
      argv[i] = os.path.realpath(arg)


def ibtool_filtering(tool_exit_status, raw_stdout, raw_stderr):
  """Filter messages from ibtool.

  Args:
    tool_exit_status: The exit status of "xcrun ibtool".
    raw_stdout: This is the unmodified stdout captured from "xcrun ibtool".
    raw_stderr: This is the unmodified stderr captured from "xcrun ibtool".

  Returns:
    A tuple of the filtered stdout and strerr.
  """

  spurious_patterns = [
      re.compile(x)
      for x in [r"WARNING: Unhandled destination metrics: \(null\)"]
  ]

  def is_spurious_message(line):
    for pattern in spurious_patterns:
      match = pattern.search(line)
      if match is not None:
        return True
    return False

  stdout = []
  for line in raw_stdout.splitlines():
    if not is_spurious_message(line):
      stdout.append(line + "\n")

  # Some of the time, in a successful run, ibtool reports on stderr some
  # internal assertions and ask "Please file a bug report with Apple", but
  # it isn't clear that there is really a problem. Since everything else
  # (warnings about assets, etc.) is reported on stdout, just drop stderr
  # on successful runs.
  if tool_exit_status == 0:
    raw_stderr = None

  return ("".join(stdout), raw_stderr)


def ibtool(_, toolargs):
  """Assemble the call to "xcrun ibtool"."""
  xcrunargs = ["xcrun",
               "ibtool",
               "--errors",
               "--warnings",
               "--notices",
               "--auto-activate-custom-fonts",
               "--output-format",
               "human-readable-text"]

  _apply_realpath(toolargs)

  xcrunargs += toolargs

  # If we are running into problems figuring out "ibtool" issues, there are a
  # couple of environment variables that may help. Both of the following must be
  # set to work.
  #   IBToolDebugLogFile=<OUTPUT FILE PATH>
  #   IBToolDebugLogLevel=4
  # You may also see if
  #   IBToolNeverDeque=1
  # helps.
  return execute.execute_and_filter_output(
      xcrunargs,
      trim_paths=True,
      filtering=ibtool_filtering)


def actool_filtering(tool_exit_status, raw_stdout, raw_stderr):
  """Filter the stdout messages from "actool".

  Args:
    tool_exit_status: The exit status of "xcrun actool".
    raw_stdout: This is the unmodified stdout captured from "xcrun actool".
    raw_stderr: This is the unmodified stderr captured from "xcrun actool".

  Returns:
    A tuple of the filtered stdout and strerr.
  """
  section_header = re.compile("^/\\* ([^ ]+) \\*/$")

  excluded_sections = ["com.apple.actool.compilation-results"]

  spurious_patterns = [
      re.compile(x) for x in [
          r"\[\]\[ipad\]\[76x76\]\[\]\[\]\[1x\]\[\]\[\]: notice: \(null\)",
          r"\[\]\[ipad\]\[76x76\]\[\]\[\]\[1x\]\[\]\[\]: notice: 76x76@1x app "
          r"icons only apply to iPad apps targeting releases of iOS prior to "
          r"10\.0\.",
      ]
  ]

  def is_spurious_message(line):
    for pattern in spurious_patterns:
      match = pattern.search(line)
      if match is not None:
        return True
    return False

  output = []
  current_section = None
  data_in_section = False

  for line in raw_stdout.splitlines():
    header_match = section_header.search(line)

    if header_match:
      data_in_section = False
      current_section = header_match.group(1)
      continue

    if not current_section:
      output.append(line + "\n")
    elif current_section not in excluded_sections:
      if is_spurious_message(line):
        continue

      if not data_in_section:
        data_in_section = True
        output.append("/* %s */\n" % current_section)

      output.append(line + "\n")

  # Some of the time, in a successful run, actool reports on stderr some
  # internal assertions and ask "Please file a bug report with Apple", but
  # it isn't clear that there is really a problem. Since everything else
  # (warnings about assets, etc.) is reported on stdout, just drop stderr
  # on successful runs.
  if tool_exit_status == 0:
    raw_stderr = None

  return ("".join(output), raw_stderr)


def actool(_, toolargs):
  """Assemble the call to "xcrun actool"."""
  xcrunargs = ["xcrun",
               "actool",
               "--errors",
               "--warnings",
               "--notices",
               "--compress-pngs",
               "--output-format",
               "human-readable-text"]

  _apply_realpath(toolargs)

  xcrunargs += toolargs

  # If we are running into problems figuring out "actool" issues, there are a
  # couple of environment variables that may help. Both of the following must be
  # set to work.
  #   IBToolDebugLogFile=<OUTPUT FILE PATH>
  #   IBToolDebugLogLevel=4
  # You may also see if
  #   IBToolNeverDeque=1
  # helps.
  # Yes, IBTOOL appears to be correct here due to "actool" and "ibtool" being
  # based on the same codebase.
  return execute.execute_and_filter_output(
      xcrunargs,
      trim_paths=True,
      filtering=actool_filtering)

def coremlc(_, toolargs):
  """Assemble the call to "xcrun coremlc"."""
  xcrunargs = ["xcrun", "coremlc"]
  _apply_realpath(toolargs)
  xcrunargs += toolargs

  return execute.execute_and_filter_output(xcrunargs)


def _zip_directory(directory, output):
  """Zip the contents of the specified directory to the output file."""
  zip_epoch_timestamp = 946684800  # 2000-01-01 00:00

  # Set the timestamp of all files within "tmpdir" to the Zip Epoch:
  # 2000-01-01 00:00. They are adjusted for timezone since Python "zipfile"
  # checks the local timestamps of the files.
  for root, _, files in os.walk(directory):
    for f in files:
      filepath = os.path.join(root, f)
      timestamp = zip_epoch_timestamp + time.timezone
      os.utime(filepath, (timestamp, timestamp))

  shutil.make_archive(output, "zip", directory, ".")


def swift_stdlib_tool(args, toolargs):
  """Assemble the call to "xcrun swift-stdlib-tool" and zip the output."""
  tmpdir = tempfile.mkdtemp(prefix="swiftstdlibtoolZippingOutput.")
  destination = os.path.join(tmpdir, args.bundle)

  xcrunargs = ["xcrun",
               "swift-stdlib-tool",
               "--copy",
               "--destination",
               destination]

  xcrunargs += toolargs

  result = execute.execute_and_filter_output(xcrunargs)
  if not result:
    _zip_directory(tmpdir, os.path.splitext(args.output)[0])

  shutil.rmtree(tmpdir)
  return result


def momc(_, toolargs):
  """Assemble the call to "xcrun momc"."""
  xcrunargs = ["xcrun", "momc"]
  _apply_realpath(toolargs)
  xcrunargs += toolargs

  return execute.execute_and_filter_output(xcrunargs)


def mapc(_, toolargs):
  """Assemble the call to "xcrun mapc"."""
  xcrunargs = ["xcrun", "mapc"]
  _apply_realpath(toolargs)
  xcrunargs += toolargs

  return execute.execute_and_filter_output(xcrunargs)


def main(argv):
  parser = argparse.ArgumentParser()
  subparsers = parser.add_subparsers()

  # IBTOOL Argument Parser
  ibtool_parser = subparsers.add_parser("ibtool")
  ibtool_parser.set_defaults(func=ibtool)

  # ACTOOL Argument Parser
  actool_parser = subparsers.add_parser("actool")
  actool_parser.set_defaults(func=actool)

  # COREMLC Argument Parser
  mapc_parser = subparsers.add_parser("coremlc")
  mapc_parser.set_defaults(func=coremlc)

  # SWIFT-STDLIB-TOOL Argument Parser
  swiftlib_parser = subparsers.add_parser("swift-stdlib-tool")
  swiftlib_parser.add_argument("output", help="The output zip file.")
  swiftlib_parser.add_argument(
      "bundle",
      help="The path inside of the archive to where the libs are copied.")
  swiftlib_parser.set_defaults(func=swift_stdlib_tool)

  # MOMC Argument Parser
  momc_parser = subparsers.add_parser("momc")
  momc_parser.set_defaults(func=momc)

  # MAPC Argument Parser
  mapc_parser = subparsers.add_parser("mapc")
  mapc_parser.set_defaults(func=mapc)

  # Parse the command line and execute subcommand
  args, toolargs = parser.parse_known_args(argv)
  sys.exit(args.func(args, toolargs))


if __name__ == "__main__":
  main(sys.argv[1:])
