# Lint as: python2, python3
# Copyright 2021 The Bazel Authors. All rights reserved.
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

"""A wrapper for the `symbols` tool, that can handle multiple inputs."""

import argparse
import os
import re
import sys

from build_bazel_rules_apple.tools.wrapper_common import execute

_TIMING_INFO_PATTERN = r"(.*\s\[.*,\s.*\sseconds\]:)"


def _generate_symbols(args):
  """Generate argument parser for tool."""
  output_dir = args.output_dir
  archs = args.arch
  binaries = args.binary

  if not os.path.exists(output_dir):
    os.makedirs(output_dir)

  cmd = ["/bin/bash", "-c"]
  symbols_cmds = []
  for i, arch in enumerate(archs):
    symbols_cmds += ["xcrun symbols -noTextInSOD -noDaemon -arch {arch} \
        -symbolsPackageDir {output_dir} {binary}".format(
            arch=arch,
            output_dir=output_dir,
            binary=binaries[i],
        )]
  cmd.append("\n".join(symbols_cmds))
  execute.execute_and_filter_output(
      cmd,
      filtering=_filter_symbols_tool_output,
      raise_on_failure=True,
      print_output=True)


def _filter_symbols_output(output):
  """Filters the symbols output which can be extra verbose."""
  filtered_lines = []
  for line in output.splitlines():
    if line and not _is_spurious_message(line):
      filtered_lines.append(line)
  return "\n".join(filtered_lines)


def _filter_symbols_tool_output(exit_status, stdout, stderr):
  """Filters the output from executing the symbols tool."""
  return _filter_symbols_output(stdout), _filter_symbols_output(stderr)


def _is_spurious_message(line):
  spurious_patterns = [
      re.compile(x) for x in [_TIMING_INFO_PATTERN]
  ]
  for pattern in spurious_patterns:
    match = pattern.search(line)
    if match is not None:
      return True
  return False


def generate_arg_parser():
  parser = argparse.ArgumentParser(
      description="Wrapper for the `symbols` tool")
  parser.add_argument(
      "--arch", type=str, required=True, action="append",
      help="The target architecture, or `any64bit`, or `any`, or `all`"
  )
  parser.add_argument(
      "--binary", type=str, required=True, action="append",
      help="The input binaries, must match the order of --arch flags"
  )
  parser.add_argument(
      "--output_dir", type=str, required=True,
      help="The output directory for the generated symbols files"
  )
  parser.set_defaults(func=_generate_symbols)
  return parser


if __name__ == "__main__":
  args = generate_arg_parser().parse_args()
  sys.exit(args.func(args))
