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
"""Unit tests for derq."""

import datetime
import plistlib
import unittest

from tools.derq import derq

_PLIST_HEADER = (
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
    '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
    '<plist version="1.0"><dict>')

# Expected bytes were produced on macOS with
# `/usr/bin/derq query -f xml -i <plist> -o <der> --raw`.
_DERQ_FIXTURES = {
    "array-of-dicts": (
        '<key>arr</key><array><dict><key>k</key><string>v</string></dict></array>',
        "7018020101b01330110c03617272300ab00830060c016b0c0176",
    ),
    "bools": (
        '<key>b-key</key><true/><key>a-key</key><false/>',
        "701d020101b018300a0c05612d6b6579010100300a0c05622d6b65790101ff",
    ),
    "empty-array": (
        '<key>empty-array</key><array/>',
        "7016020101b011300f0c0b656d7074792d61727261793000",
    ),
    "empty-dict": (
        '<key>empty-dict</key><dict/>',
        "7015020101b010300e0c0a656d7074792d64696374b000",
    ),
    "empty-string": (
        '<key>empty-string</key><string></string>',
        "7017020101b01230100c0c656d7074792d737472696e670c00",
    ),
    "ints": (
        '<key>Z-key</key><integer>42</integer><key>neg</key><integer>-7</integer><key>big</key><integer>300</integer><key>zero</key><integer>0</integer><key>huge</key><integer>9223372036854775807</integer>',
        "7043020101b03e300a0c055a2d6b657902012a30090c036269670202012c30100c046875676502087fffffffffffffff30080c036e65670201f930090c047a65726f020100",
    ),
    "keyorder": (
        '<key>b</key><string>1</string><key>B</key><string>2</string><key>a</key><string>3</string><key>_</key><string>4</string><key>aa</key><string>5</string><key>a-</key><string>6</string><key>a.</key><string>7</string>',
        "7040020101b03b30060c01420c013230060c015f0c013430060c01610c013330070c02612d0c013630070c02612e0c013730070c0261610c013530060c01620c0131",
    ),
    "long-string": (
        '<key>s</key><string>xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx</string>',
        "7082013e020101b0820137308201330c01730c82012c787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878787878",
    ),
    "nested-empty-string-array": (
        '<key>arr</key><array><string></string></array>',
        "7010020101b00b30090c0361727230020c00",
    ),
    "nested": (
        '<key>nested</key><dict><key>y</key><string>why</string><key>x</key><array><integer>1</integer><true/></array></dict>',
        "7028020101b02330210c066e6573746564b017300b0c017830060201010101ff30080c01790c03776879",
    ),
    "unicode": (
        '<key>unicode</key><string>héllo — ✓</string>',
        "7020020101b01b30190c07756e69636f64650c0e68c3a96c6c6f20e2809420e29c93",
    ),
}


class DerqTest(unittest.TestCase):

  def _encode(self, dict_body):
    xml = (_PLIST_HEADER + dict_body + "</dict></plist>").encode("utf-8")
    return derq.encode_entitlements(plistlib.loads(xml))

  def test_matches_apple_derq(self):
    for name, (dict_body, expected_hex) in _DERQ_FIXTURES.items():
      with self.subTest(name):
        self.assertEqual(self._encode(dict_body).hex(), expected_hex)

  def test_minimal_integer_encoding(self):
    # DER two's complement must use the fewest bytes; -128 and 128 are the
    # boundary cases a naive bit_length computation gets wrong.
    self.assertEqual(derq._integer(-128), b"\x02\x01\x80")
    self.assertEqual(derq._integer(128), b"\x02\x02\x00\x80")
    self.assertEqual(derq._integer(127), b"\x02\x01\x7f")
    self.assertEqual(derq._integer(-129), b"\x02\x02\xff\x7f")

  def test_rejects_values_derq_cannot_encode(self):
    for value in (b"\x01\x02", 1.5, datetime.datetime(2026, 1, 2)):
      with self.subTest(type(value).__name__):
        with self.assertRaises(ValueError):
          derq.encode_entitlements({"k": value})

  def test_rejects_non_dictionary_root(self):
    with self.assertRaises(ValueError):
      derq.encode_entitlements(["not", "a", "dict"])


if __name__ == "__main__":
  unittest.main()
