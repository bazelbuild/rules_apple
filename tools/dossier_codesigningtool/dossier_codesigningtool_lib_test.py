# Copyright 2023 The Bazel Authors. All rights reserved.
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
"""Tests for dossier_codesigningtool_lib."""

import os
import tempfile
import unittest
from unittest import mock

from build_bazel_rules_apple.tools.dossier_codesigningtool import dossier_codesigningtool


class DossierCodesigningtoolLibTest(unittest.TestCase):

  @mock.patch('shutil.copy')
  def test_copy_provisioning_profile_dest_filename(self, mock_copy):
    with (
        tempfile.TemporaryDirectory() as tmp_output_dir_name,
        tempfile.NamedTemporaryFile(suffix='.mobileprovision') as tmp_pp_file):
      actual_filename = dossier_codesigningtool._copy_provisioning_profile(
          tmp_pp_file.name, tmp_output_dir_name, 'my_unique_id')
      self.assertEqual(actual_filename, 'my_unique_id.mobileprovision')
      mock_copy.assert_called_with(
          tmp_pp_file.name, os.path.join(tmp_output_dir_name, actual_filename))

  @mock.patch('shutil.copy')
  def test_copy_entitlements_file_dest_filename(self, mock_copy):
    with (
        tempfile.TemporaryDirectory() as tmp_output_dir_name,
        tempfile.NamedTemporaryFile() as tmp_entitlements_file):
      actual_filename = dossier_codesigningtool._copy_entitlements_file(
          tmp_entitlements_file.name, tmp_output_dir_name, 'my_unique_id')
      self.assertEqual(actual_filename, 'my_unique_id.entitlements')
      mock_copy.assert_called_with(
          tmp_entitlements_file.name,
          os.path.join(tmp_output_dir_name, actual_filename))

  def test_copy_entitlements_file_returns_none_if_not_exists(self):
    with tempfile.TemporaryDirectory() as tmp_output_dir_name:
      self.assertIsNone(
          dossier_codesigningtool._copy_entitlements_file(
              os.path.join(tmp_output_dir_name, 'does_not_exist'),
              tmp_output_dir_name,
              'my_unique_id',
          )
      )

  def test_generate_manifest_passes_through_kwargs(self):
    actual_manifest = dossier_codesigningtool._generate_manifest(
        codesign_identity='-',
        entitlement_file='/path/to/my_app.entitlements',
        provisioning_profile_file='/path/to/my_app.mobileprovision',
        embedded_bundle_manifests={'a': 'b'},
    )
    expected_manifest = {
        'codesign_identity': '-',
        'entitlements': '/path/to/my_app.entitlements',
        'provisioning_profile': '/path/to/my_app.mobileprovision',
        'embedded_bundle_manifests': {'a': 'b'},
    }
    self.assertDictEqual(expected_manifest, actual_manifest)

  @mock.patch('shutil.copy')
  def test_merge_dossier_contents_copies_allowed_files(self, mock_copy):
    with (
        tempfile.TemporaryDirectory() as tmp_output_dir_name,
        tempfile.NamedTemporaryFile(suffix='.entitlements') as tmp_e_file,
        tempfile.NamedTemporaryFile(suffix='.mobileprovision') as tmp_pp_file,
    ):
      # tempfile API does not support creating a temporary file with an exact
      # file name, therefore this test creates the 'manifest.json' file with
      # `open` instead and lets the tempfile API automatically delete the
      # containing temporary directory.
      tmp_manifest_file = os.path.join(tempfile.gettempdir(), 'manifest.json')
      with open(tmp_manifest_file, 'w') as fp:
        fp.write('')

      dossier_codesigningtool._merge_dossier_contents(
          tempfile.gettempdir(), tmp_output_dir_name)
      mock_copy.assert_has_calls(
          [
              mock.call(tmp_pp_file.name, mock.ANY),
              mock.call(tmp_e_file.name, mock.ANY),
          ],
          any_order=True,
      )
      self.assertNotIn(
          mock.call(tmp_manifest_file, mock.ANY), mock_copy.mock_calls)

  @mock.patch.object(dossier_codesigningtool, '_copy_provisioning_profile')
  def test_extract_provisioning_profile_with_common_bundle_structure(
      self, mock_copy_provisioning_profile):
    with tempfile.TemporaryDirectory() as tmp_dir_path:
      # tempfile API does not support creating a temporary file with an exact
      # file name, therefore this test creates the 'embedded.mobileprovision'
      # file with `open` instead and lets the tempfile API automatically delete
      # the containing temporary directory.
      tmp_pp_file_path = os.path.join(tmp_dir_path, 'embedded.mobileprovision')
      with open(tmp_pp_file_path, 'w') as fp:
        fp.write('')

      dossier_codesigningtool._extract_provisioning_profile(
          tmp_dir_path, '/path/to/output_directory', 'my_unique_id')
      mock_copy_provisioning_profile.assert_called_with(
          tmp_pp_file_path, '/path/to/output_directory', 'my_unique_id')

  @mock.patch.object(dossier_codesigningtool, '_copy_provisioning_profile')
  def test_extract_provisioning_profile_with_macos_bundle_structure(
      self, mock_copy_provisioning_profile):
    with tempfile.TemporaryDirectory() as tmp_dir_path:
      # tempfile API does not support creating a temporary file with an exact
      # file name, therefore this test creates an intermediate 'Contents'
      # directory and a 'embedded.provisionprofile' file with `os.mkdir` and
      # `open` instead and lets the tempfile API automatically delete the
      # containing temporary directory.
      contents_dir_path = os.path.join(tmp_dir_path, 'Contents')
      embedded_pp_file_path = os.path.join(
          contents_dir_path, 'embedded.provisionprofile')
      os.mkdir(contents_dir_path)
      with open(embedded_pp_file_path, 'w') as fp:
        fp.write('')

      dossier_codesigningtool._extract_provisioning_profile(
          tmp_dir_path, '/path/to/output_directory', 'my_unique_id')
      mock_copy_provisioning_profile.assert_called_with(
          embedded_pp_file_path, '/path/to/output_directory', 'my_unique_id')


if __name__ == '__main__':
  unittest.main()
