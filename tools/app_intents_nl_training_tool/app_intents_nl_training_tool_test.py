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
"""Tests for app_intents_nl_training_tool."""

import struct
import unittest

from tools.app_intents_nl_training_tool import app_intents_nl_training_tool


class ZeroTimestampsTest(unittest.TestCase):

  def test_zeroes_aligned_values_in_range(self):
    data = struct.pack("<IIII", 24, 1790606161, 16, 3)
    self.assertEqual(
        app_intents_nl_training_tool.zero_timestamps(data, 1790606160, 1790606162),
        struct.pack("<IIII", 24, 0, 16, 3),
    )

  def test_ignores_values_out_of_range(self):
    data = struct.pack("<III", 1790606159, 1790606163, 7)
    self.assertEqual(
        app_intents_nl_training_tool.zero_timestamps(data, 1790606160, 1790606162),
        data,
    )

  def test_ignores_unaligned_values(self):
    data = b"\x00\x00" + struct.pack("<I", 1790606161) + b"\x00\x00"
    self.assertEqual(
        app_intents_nl_training_tool.zero_timestamps(data, 1790606160, 1790606162),
        data,
    )

  def test_ignores_trailing_bytes(self):
    data = struct.pack("<I", 1790606161) + b"\x01\x02"
    self.assertEqual(
        app_intents_nl_training_tool.zero_timestamps(data, 1790606160, 1790606162),
        struct.pack("<I", 0) + b"\x01\x02",
    )


if __name__ == "__main__":
  unittest.main()
