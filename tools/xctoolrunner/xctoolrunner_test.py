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
"""Tests for xctoolrunner."""

import unittest
from build_bazel_rules_apple.tools.xctoolrunner import xctoolrunner


_UNHANDLED_DESTINATION_METRICS_MSG = (
    "2017-11-15 08:41:21.507 ibtoold[11658:7455845]"
    "WARNING: Unhandled destination metrics: (null)\n")
_CHANGE_PROPERTY_MSG = (
    "2018-08-07 13:23:26.386 ibtoold[51132:942471]"
    " <CATransformLayer: 0x7f8b000e2af0> - "
    "changing property masksToBounds in transform-only layer, "
    "will have no effect\n")


class TestIBTOOL(unittest.TestCase):

  def testFiltering(self):
    stdout = _UNHANDLED_DESTINATION_METRICS_MSG + _CHANGE_PROPERTY_MSG
    stderr = ""
    tool_exit_status = 0

    (out, _) = xctoolrunner.ibtool_filtering(
        tool_exit_status,
        stdout,
        stderr)

    self.assertEqual(out, _CHANGE_PROPERTY_MSG)


if __name__ == "__main__":
  unittest.main()
