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
"""Tests for skipping verification of already signed frameworks."""

import argparse
import unittest
from unittest import mock

from tools.codesigningtool import codesigningtool


class SignedFrameworksTest(unittest.TestCase):

  def _run_signer(self, arguments):
    parser = argparse.ArgumentParser()
    codesigningtool.add_parser_arguments(parser)
    args = parser.parse_args([
        "--codesign", "/usr/bin/codesign",
        "--identity", "-",
        "--directory_to_sign", "Frameworks",
    ] + arguments)
    with mock.patch.object(
        codesigningtool, "_all_paths_to_sign",
        return_value=[
            "Frameworks/MyFramework.framework",
            "Frameworks/Other.framework",
        ],
    ), mock.patch.object(
        codesigningtool.subprocess, "run",
        side_effect=AssertionError("Signature verification should be skipped"),
    ) as verify, mock.patch.object(
        codesigningtool, "invoke_codesign",
    ) as sign:
      self.assertEqual(
          codesigningtool.find_identity_and_sign_bundle_paths(args), 0)
    return verify, sign

  def test_skipping_verification_does_not_verify_or_resign_signed_frameworks(self):
    verify, sign = self._run_signer([
        "--skip_signed_path_verification",
        "--signed_path", "Frameworks/MyFramework.framework",
        "--signed_path", "Frameworks/Other.framework",
    ])
    verify.assert_not_called()
    sign.assert_not_called()

  def test_skipping_verification_still_signs_unsigned_frameworks(self):
    verify, sign = self._run_signer([
        "--skip_signed_path_verification",
        "--signed_path", "Frameworks/MyFramework.framework",
    ])
    verify.assert_not_called()
    sign.assert_called_once_with(
        codesign_path="/usr/bin/codesign",
        identity="-",
        entitlements=None,
        force_signing=False,
        disable_timestamp=False,
        full_path_to_sign="Frameworks/Other.framework",
        extra=[],
    )


if __name__ == "__main__":
  unittest.main()
