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

"""Tests for symbols_tool."""

import unittest
from build_bazel_rules_apple.tools.symbols_tool import symbols_tool


_TIMING_INFO_MSG = ("path/to/binary.dwarf [arm64, 0.988856 seconds]:\n")


class TestSymbolsTool(unittest.TestCase):

  def testFiltering(self):
    out = symbols_tool._filter_symbols_output(_TIMING_INFO_MSG)
    self.assertEqual(out, "")


if __name__ == "__main__":
  unittest.main()
