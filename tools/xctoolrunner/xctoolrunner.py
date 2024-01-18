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

  realitytool [<args>...]
"""

import argparse
import os
import re
import sys

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
    A tuple of the filtered exit_status, stdout and strerr.
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

  return (tool_exit_status, "".join(stdout), raw_stderr)


def ibtool(_, toolargs):
  """Assemble the call to "xcrun ibtool"."""
  xcrunargs = [
      "xcrun", "ibtool", "--errors", "--warnings", "--notices",
      "--auto-activate-custom-fonts", "--output-format", "human-readable-text"
  ]

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
  return_code, _, _ = execute.execute_and_filter_output(
      xcrunargs, trim_paths=True, filtering=ibtool_filtering, print_output=True)
  return return_code


def actool_filtering(tool_exit_status, raw_stdout, raw_stderr):
  """Filter the stdout messages from "actool".

  Args:
    tool_exit_status: The exit status of "xcrun actool".
    raw_stdout: This is the unmodified stdout captured from "xcrun actool".
    raw_stderr: This is the unmodified stderr captured from "xcrun actool".

  Returns:
    A tuple of the filtered exit_status, stdout and strerr.
  """
  section_header = re.compile("^/\\* ([^ ]+) \\*/$")

  excluded_sections = ["com.apple.actool.compilation-results"]

  spurious_patterns = [
      re.compile(x) for x in [
          r"\[\]\[ipad\]\[76x76\]\[\]\[\]\[1x\]\[\]\[\]\[\]: notice: \(null\)",
          r"\[\]\[ipad\]\[76x76\]\[\]\[\]\[1x\]\[\]\[\]\[\]: notice: 76x76@1x "
          r"app icons only apply to iPad apps targeting releases of iOS prior "
          r"to 10\.0\.",
      ]
  ]

  def is_spurious_message(line):
    for pattern in spurious_patterns:
      match = pattern.search(line)
      if match is not None:
        return True
    return False

  def is_warning_or_notice_an_error(line):
    """Returns True if the warning/notice should be treated as an error."""

    # Current things staying as warnings are launch image deprecations,
    # requiring a 1024x1024 for appstore (b/246165573) and "foo" is used by
    # multiple imagesets (b/139094648)
    warnings = [
        "is used by multiple", "1024x1024",
        "Launch images are deprecated in iOS 13.0",
        "Launch images are deprecated in tvOS 13.0"
    ]
    for warning in warnings:
      if warning in line:
        return False
    return True

  output = set()
  current_section = None

  for line in raw_stdout.splitlines():
    header_match = section_header.search(line)

    if header_match:
      current_section = header_match.group(1)
      continue

    if not current_section:
      output.add(line + "\n")
    elif current_section not in excluded_sections:
      if is_spurious_message(line):
        continue

      if is_warning_or_notice_an_error(line):
        line = line.replace(": warning: ", ": error: ")
        line = line.replace(": notice: ", ": error: ")
        tool_exit_status = 1

      output.add(line + "\n")

  # Some of the time, in a successful run, actool reports on stderr some
  # internal assertions and ask "Please file a bug report with Apple", but
  # it isn't clear that there is really a problem. Since everything else
  # (warnings about assets, etc.) is reported on stdout, just drop stderr
  # on successful runs.
  if tool_exit_status == 0:
    raw_stderr = None

  return (tool_exit_status, "".join(output), raw_stderr)


def actool(_, toolargs):
  """Assemble the call to "xcrun actool"."""
  xcrunargs = [
      "xcrun", "actool", "--errors", "--warnings", "--notices",
      "--output-format", "human-readable-text"
  ]

  _apply_realpath(toolargs)

  xcrunargs += toolargs

  # The argument coming after "--compile" is the output directory. "actool"
  # expects an directory to exist at that path. Create an empty directory there
  # if one doesn't exist yet.
  for idx, arg in enumerate(toolargs):
    if arg == "--compile":
      output_dir = toolargs[idx + 1]
      if not os.path.exists(output_dir):
        os.makedirs(output_dir)
      break

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
  return_code, _, _ = execute.execute_and_filter_output(
      xcrunargs, trim_paths=True, filtering=actool_filtering, print_output=True)
  return return_code


def coremlc(_, toolargs):
  """Assemble the call to "xcrun coremlc"."""
  xcrunargs = ["xcrun", "coremlc"]
  _apply_realpath(toolargs)
  xcrunargs += toolargs

  return_code, _, _ = execute.execute_and_filter_output(
      xcrunargs, print_output=True)
  return return_code


def momc(args, toolargs):
  """Assemble the call to "xcrun momc"."""
  xcrunargs = ["xcrun", "momc"]
  _apply_realpath(toolargs)
  xcrunargs += toolargs

  return_code, _, _ = execute.execute_and_filter_output(
      xcrunargs, print_output=True)

  destination_dir = args.xctoolrunner_assert_nonempty_dir
  if args.xctoolrunner_assert_nonempty_dir and not os.listdir(destination_dir):
    raise FileNotFoundError(
        f"xcrun momc did not generate artifacts at: {destination_dir}\n"
        "Core Data model was not configured to have code generation.")

  return return_code


def mapc(_, toolargs):
  """Assemble the call to "xcrun mapc"."""
  xcrunargs = ["xcrun", "mapc"]
  _apply_realpath(toolargs)
  xcrunargs += toolargs

  return_code, _, _ = execute.execute_and_filter_output(
      xcrunargs, print_output=True)
  return return_code


def realitytool(_, toolargs):
  """Assemble the call to "xcrun realitytool"."""
  xcrunargs = ["xcrun", "realitytool"]
  _apply_realpath(toolargs)
  xcrunargs += toolargs

  return_code, _, _ = execute.execute_and_filter_output(
      xcrunargs, print_output=True)
  return return_code


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

  # MOMC Argument Parser
  momc_parser = subparsers.add_parser("momc")
  momc_parser.add_argument(
      "--xctoolrunner_assert_nonempty_dir",
      help="Enables non-empty destination dir assertion after execution.")
  momc_parser.set_defaults(func=momc)

  # MAPC Argument Parser
  mapc_parser = subparsers.add_parser("mapc")
  mapc_parser.set_defaults(func=mapc)

  # REALITYTOOL Argument Parser
  realitytool_parser = subparsers.add_parser("realitytool")
  realitytool_parser.set_defaults(func=realitytool)

  # Parse the command line and execute subcommand
  args, toolargs = parser.parse_known_args(argv)
  sys.exit(args.func(args, toolargs))


if __name__ == "__main__":
  main(sys.argv[1:])
