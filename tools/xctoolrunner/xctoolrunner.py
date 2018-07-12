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

  ibtool [<args>...]

  mapc [SOURCE] [DESTINATION] [<args>...]
      SOURCE: The path to the .xcmappingmodel directory.
      DESTINATION: The path to the output .cdm file.

  momc [OUTPUT] [<args>...]
      OUTPUT: The output file (.mom) or directory (.momd).

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
  xcrunargs += toolargs

  # If we are running into problems figuring out "ibtool" issues, there are a
  # couple of environment variables that may help. Both of the following must be
  # set to work.
  #   IBToolDebugLogFile=<OUTPUT FILE PATH>
  #   IBToolDebugLogLevel=4
  # You may also see if
  #   IBToolNeverDeque=1
  # helps.
  return execute.execute_and_filter_output(xcrunargs, trim_paths=True)


def actool_filtering(raw_stdout):
  """Filter the stdout messages from "actool".

  Args:
    raw_stdout: This is the unmodified stdout captured from "xcrun actool".

  Returns:
    The filtered output string.
  """
  section_header = re.compile("^/\\* ([^ ]*) \\*/$")

  excluded_sections = ["com.apple.actool.compilation-results"]

  spurious_patterns = map(re.compile, [
      r"\[\]\[ipad\]\[76x76\]\[\]\[\]\[1x\]\[\]\[\]: notice: \(null\)",
      r"\[\]\[ipad\]\[76x76\]\[\]\[\]\[1x\]\[\]\[\]: notice: 76x76@1x app icons"
      " only apply to iPad apps targeting releases of iOS prior to 10.0.",
  ])

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

    if current_section and current_section not in excluded_sections:
      if is_spurious_message(line):
        continue

      if not data_in_section:
        data_in_section = True
        output.append("/* %s */\n" % current_section)

      output.append(line + "\n")

  return "".join(output)


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


def _zip_directory(directory, output):
  """Zip the contents of the specified directory to the output file."""
  zip_epoch_timestamp = 315532800  # 1980-01-01 00:00

  # Set the timestamp of all files within "tmpdir" to the Zip Epoch:
  # 1980-01-01 00:00. They are adjusted for timezone since Python "zipfile"
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


def momc(args, toolargs):
  """Assemble the call to "xcrun momc"."""
  xcrunargs = ["xcrun", "momc"]
  xcrunargs += toolargs
  xcrunargs.append(os.path.realpath(args.output))

  return execute.execute_and_filter_output(xcrunargs)


def mapc(args, toolargs):
  """Assemble the call to "xcrun mapc"."""
  xcrunargs = ["xcrun",
               "mapc",
               os.path.realpath(args.source),
               os.path.realpath(args.destination)]
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

  # SWIFT-STDLIB-TOOL Argument Parser
  swiftlib_parser = subparsers.add_parser("swift-stdlib-tool")
  swiftlib_parser.add_argument("output", help="The output zip file.")
  swiftlib_parser.add_argument(
      "bundle",
      help="The path inside of the archive to where the libs are copied.")
  swiftlib_parser.set_defaults(func=swift_stdlib_tool)

  # MOMC Argument Parser
  momc_parser = subparsers.add_parser("momc")
  momc_parser.add_argument(
      "output",
      help=("The path to the desired output file (.mom) or directory (.momd), "
            "depending on whether or not the input is a versioned data model."))
  momc_parser.set_defaults(func=momc)

  # MAPC Argument Parser
  mapc_parser = subparsers.add_parser("mapc")
  mapc_parser.add_argument(
      "source",
      help="The path to the .xcmappingmodel directory.")
  mapc_parser.add_argument(
      "destination",
      help="The path to the output .cdm file.")
  mapc_parser.set_defaults(func=mapc)

  # Parse the command line and execute subcommand
  args, toolargs = parser.parse_known_args(argv)
  sys.exit(args.func(args, toolargs))


if __name__ == "__main__":
  main(sys.argv[1:])
