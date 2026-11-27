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
"""Tests for xctoolrunner."""

import itertools
import os
import struct
import tempfile
import unittest

from unittest import mock

from tools.wrapper_common import execute
from tools.xctoolrunner import xctoolrunner


_UNHANDLED_DESTINATION_METRICS_MSG = (
    "2017-11-15 08:41:21.507 ibtoold[11658:7455845]"
    "WARNING: Unhandled destination metrics: (null)\n")
_CHANGE_PROPERTY_MSG = (
    "2018-08-07 13:23:26.386 ibtoold[51132:942471]"
    " <CATransformLayer: 0x7f8b000e2af0> - "
    "changing property masksToBounds in transform-only layer, "
    "will have no effect\n")
_MODEL_CHECKSUM_MSG = (
    "PersistentQueue.xcdatamodel: note: Model PersistentQueue "
    "version checksum: +liGtY4aOXak0pynyLB0+SQanU4nvQ3MLg5dwh2PE0o=\n")
_MODEL_FAILURE_MSG = (
    "CoreData: warning: no NSValueTransformer with class name "
    "'SomeTransformer' was found for attribute 'value' on entity "
    "'SomeEntity'\n")


_APPEARANCES = (
    (b"UIAppearanceAny", 0),
    (b"UIAppearanceDark", 1),
    (b"UIAppearanceLight", 4),
)


def _align(n):
  return (n + 15) & ~15


def _make_car(insertion_order):
  """Returns a minimal Assets.car BOM store with an APPEARANCEKEYS tree.

  Blocks 1 and 2 are the tree and its leaf; each appearance's key (name) and
  value (identifier) blocks follow in `insertion_order`, laid out one after
  another and 16-byte aligned, the way actool writes them.
  """
  blocks = {}
  data = bytearray(512)
  ids = {}
  next_id = 3
  for name, value in insertion_order:
    ids[name] = (next_id, next_id + 1)
    next_id += 2
  leaf = struct.pack(">HHII", 1, len(insertion_order), 0, 0)
  for name, _ in sorted(insertion_order):
    key_id, value_id = ids[name]
    leaf += struct.pack(">II", value_id, key_id)
  tree = b"tree" + struct.pack(">III", 1, 2, 4096) + bytes(9)
  for block_id, content in ((1, tree), (2, leaf)):
    blocks[block_id] = (len(data), len(content))
    data += content + bytes(_align(len(content)) - len(content))
  for name, value in insertion_order:
    key_id, value_id = ids[name]
    for block_id, content in ((key_id, name), (value_id,
                                               struct.pack("<H", value))):
      blocks[block_id] = (len(data), len(content))
      data += content + bytes(_align(len(content)) - len(content))
  index_offset = len(data)
  index = struct.pack(">I", next_id)
  for block_id in range(next_id):
    index += struct.pack(">II", *blocks.get(block_id, (0, 0)))
  data += index
  vars_offset = len(data)
  var_name = b"APPEARANCEKEYS"
  variables = struct.pack(">IIB", 1, 1, len(var_name)) + var_name
  data += variables
  struct.pack_into(">8sIIIIII", data, 0, b"BOMStore", 1, next_id,
                   index_offset, len(index), vars_offset, len(variables))
  return bytes(data)


class TestCanonicalCar(unittest.TestCase):

  def testEveryInsertionOrderGivesTheSameBytes(self):
    for count in (2, 3):
      orders = list(itertools.permutations(_APPEARANCES[:count]))
      raw = {_make_car(order) for order in orders}
      self.assertEqual(len(raw), len(orders))
      canonical = {xctoolrunner._canonical_car(car) for car in raw}
      self.assertEqual(canonical, {_make_car(sorted(_APPEARANCES[:count]))})

  def testIsIdempotent(self):
    car = xctoolrunner._canonical_car(_make_car(_APPEARANCES[::-1]))
    self.assertEqual(xctoolrunner._canonical_car(car), car)

  def testLeavesOtherFilesAlone(self):
    single = _make_car(_APPEARANCES[:1])
    self.assertEqual(xctoolrunner._canonical_car(single), single)
    self.assertEqual(xctoolrunner._canonical_car(b"not a car"), b"not a car")

  def testActoolKeepsItsOutputIfTheRewriteFails(self):
    with tempfile.TemporaryDirectory() as output_dir:
      car = os.path.join(output_dir, "Assets.car")
      with open(car, "wb") as f:
        f.write(b"BOMStore")  # Too short to parse.
      with mock.patch.object(
          xctoolrunner, "_execute_and_filter_with_retry", return_value=0):
        self.assertEqual(xctoolrunner.actool(None, ["--compile", output_dir]),
                         0)
      with open(car, "rb") as f:
        self.assertEqual(f.read(), b"BOMStore")


class TestIBTOOL(unittest.TestCase):

  def testFiltering(self):
    stdout = _UNHANDLED_DESTINATION_METRICS_MSG + _CHANGE_PROPERTY_MSG
    stderr = ""
    tool_exit_status = 0

    (tool_exit_status, out, _) = xctoolrunner.ibtool_filtering(
        tool_exit_status,
        stdout,
        stderr)

    self.assertEqual(out, _CHANGE_PROPERTY_MSG)


class TestACTOOL(unittest.TestCase):

  def testFilteringHidesSpurious76x76Notice(self):
    stdout = (
        "/* com.apple.actool.document.notices */\n"
        "[][ipad][76x76][][][1x][][][]: notice: (null)\n"
        "[][ipad][76x76][][][1x][][][]: notice: 76x76@1x "
        "app icons only apply to iPad apps targeting releases of iOS prior "
        "to 10.0.\n"
    )

    (tool_exit_status, out, err) = xctoolrunner.actool_filtering(
        0, stdout, "")

    self.assertEqual(tool_exit_status, 0)
    self.assertEqual(out, "")
    self.assertEqual(err, "")

  def testFilteringPromotesWarningsToErrors(self):
    stdout = (
        "/* com.apple.actool.document.warnings */\n"
        "star.imageset: warning: The image set has an unassigned child.\n"
    )

    (tool_exit_status, out, err) = xctoolrunner.actool_filtering(
        0, stdout, "")

    self.assertEqual(tool_exit_status, 1)
    self.assertEqual(
        out,
        "star.imageset: error: The image set has an unassigned child.\n")
    self.assertEqual(err, "")

  def testFilteringPassesThroughStderrOnFailure(self):
    stderr = "error: The file \"star.png\" does not exist.\n"

    (tool_exit_status, out, err) = xctoolrunner.actool_filtering(
        1, "", stderr)

    self.assertEqual(tool_exit_status, 1)
    self.assertEqual(out, "")
    self.assertEqual(err, stderr)


class TestMomcTool(unittest.TestCase):

  def setUp(self):
    super().setUp()
    self.momc_input = tempfile.mkdtemp()
    self.momc_output = tempfile.mkdtemp()

    execute_patch = mock.patch.object(
        execute, "execute_and_filter_output", autospec=True)
    self.execute_patch = execute_patch.start()
    self.addCleanup(execute_patch.stop)

  def testFiltering(self):
    stderr = _MODEL_CHECKSUM_MSG + _MODEL_FAILURE_MSG
    tool_exit_status = 0

    (tool_exit_status, _, err) = xctoolrunner.momc_filtering(
        tool_exit_status, "", stderr)

    self.assertEqual(err, _MODEL_FAILURE_MSG)

  def testRaisesFileNotFoundError(self):
    args = [
        "momc",
        "--action",
        "generate",
        self.momc_input,
        self.momc_output,
        "--xctoolrunner_assert_nonempty_dir",
        self.momc_output,
    ]
    self.execute_patch.return_value = (0, None, None)

    with self.assertRaisesRegex(
        FileNotFoundError, "xcrun momc did not generate artifacts.*"):
      xctoolrunner.main(args)

  def testRaisesSystemExit(self):
    args = ["momc", "--action", "generate", self.momc_input, self.momc_output]
    self.execute_patch.return_value = (0, None, None)

    # empty directory
    with self.assertRaises(SystemExit):
      xctoolrunner.main(args)

    # non-empty directory
    args = [
        "momc",
        "--action",
        "generate",
        self.momc_input,
        self.momc_output,
        "--xctoolrunner_assert_nonempty_dir",
        self.momc_output,
    ]
    tempfile.mkstemp(dir=self.momc_output)
    with self.assertRaises(SystemExit):
      xctoolrunner.main(args)

if __name__ == "__main__":
  unittest.main()
