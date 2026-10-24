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
"""Encodes an entitlements plist as DER, byte-compatible with Apple's derq.

Drop-in for `/usr/bin/derq query -f xml -i <plist> -o <der> --raw`, so the
DER entitlements section of simulator binaries can be produced on any host.

The layout is the one TN3125 describes for the DER-Encoded-Profile
entitlements: [APPLICATION 16] { INTEGER 1, dict }, where a dict is
[CONTEXT 16] { SEQUENCE { UTF8String key, value } ... } with its entries
ordered by the UTF-8 bytes of the key, arrays are SEQUENCE, booleans BOOLEAN
and integers minimal two's-complement INTEGER. derq rejects <data> and <date>
and silently truncates <real>, so those are errors here.
"""

import argparse
import plistlib
import sys


def _length(n):
  if n < 0x80:
    return bytes([n])
  body = n.to_bytes((n.bit_length() + 7) // 8, "big")
  return bytes([0x80 | len(body)]) + body


def _tlv(tag, body):
  return bytes([tag]) + _length(len(body)) + body


def _integer(value):
  size = 1
  while True:
    try:
      return _tlv(0x02, value.to_bytes(size, "big", signed=True))
    except OverflowError:
      size += 1


def _encode(value, path):
  if isinstance(value, bool):
    return _tlv(0x01, b"\xff" if value else b"\x00")
  if isinstance(value, int):
    return _integer(value)
  if isinstance(value, str):
    return _tlv(0x0C, value.encode("utf-8"))
  if isinstance(value, list):
    return _tlv(
        0x30,
        b"".join(_encode(v, path + [str(i)]) for i, v in enumerate(value)))
  if isinstance(value, dict):
    entries = sorted((k.encode("utf-8"), v) for k, v in value.items())
    return _tlv(
        0xB0,
        b"".join(
            _tlv(0x30, _tlv(0x0C, k) + _encode(v, path + [k.decode("utf-8")]))
            for k, v in entries))
  raise ValueError("unsupported entitlement value of type %s at %s" %
                   (type(value).__name__, "/".join(path) or "<root>"))


def encode_entitlements(plist):
  """Returns the DER bytes for an entitlements dict."""
  if not isinstance(plist, dict):
    raise ValueError("entitlements must be a dictionary")
  return _tlv(0x70, _tlv(0x02, b"\x01") + _encode(plist, []))


def main(argv):
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("command", choices=["query"])
  parser.add_argument("-f", "--format", choices=["xml"], required=True)
  parser.add_argument("-i", "--input", required=True)
  parser.add_argument("-o", "--output", required=True)
  parser.add_argument("--raw", action="store_true", required=True)
  args = parser.parse_args(argv)
  with open(args.input, "rb") as f:
    plist = plistlib.load(f)
  try:
    der = encode_entitlements(plist)
  except ValueError as e:
    sys.exit("derq: %s: %s" % (args.input, e))
  with open(args.output, "wb") as f:
    f.write(der)


if __name__ == "__main__":
  main(sys.argv[1:])
