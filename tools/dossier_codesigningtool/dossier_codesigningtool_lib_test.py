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

_FAKE_CODESIGN_STDERR_WITH_ADHOC_SIGNING = """\
Executable=/tmp/app_minimal.app/app_minimal
Identifier=com.google.example
Format=app bundle with Mach-O thin (arm64)
CodeDirectory v=20400 size=747 flags=0x2(adhoc) hashes=13+7 location=embedded
Signature=adhoc
Info.plist entries=18
TeamIdentifier=not set
Sealed Resources version=2 rules=10 files=1
Internal requirements count=0 size=12"""

_FAKE_CODESIGN_STDERR_WITH_SIGNING_AUTHORITY = """\
Executable=/tmp/app_minimal.app/app_minimal
Identifier=com.google.example
Format=app bundle with Mach-O thin (arm64)
CodeDirectory v=20400 size=758 flags=0x0(none) hashes=13+7 location=embedded
Signature size=4785
Authority=Apple Development: Bazel Development (XXXXXXXXXX)
Authority=Apple Worldwide Developer Relations Certification Authority
Authority=Apple Root CA
Signed Time=Jan 25, 2023 at 4:02:00 PM
Info.plist entries=18
TeamIdentifier=YYYYYYYYYY
Sealed Resources version=2 rules=10 files=1
Internal requirements count=1 size=188"""

_FAKE_APP_XML_PLIST = """\
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.get-task-allow</key>
    <true/>
</dict>
</plist>"""


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


class DossierCodesigningtoolGenerateTest(unittest.TestCase):

  @mock.patch.object(
      dossier_codesigningtool, '_manifest_with_dossier_for_bundle')
  def test_embedded_manifests_for_path(
      self, mock_manifest_with_dossier_for_bundle):
    mock_manifest_with_dossier_for_bundle.return_value = {
        'codesign_identity': 'My fake codesign identity',
        'entitlements': 'fake.entitlements',
        'provisioning_profile': 'fake.mobileprovision',
    }
    with (tempfile.TemporaryDirectory() as tmp_output_dir,
          tempfile.TemporaryDirectory(suffix='.app') as bundle_path):
      frameworks_path = os.path.join(bundle_path, 'Frameworks')
      my_framework_path = os.path.join(frameworks_path, 'MyFramework.framework')
      os.mkdir(frameworks_path)
      os.mkdir(my_framework_path)

      actual_embedded_manifests = (
          dossier_codesigningtool._embedded_manifests_for_path(
              bundle_path, tmp_output_dir, 'Frameworks', '/usr/bin/codesign'
          )
      )

      mock_manifest_with_dossier_for_bundle.assert_called_with(
          my_framework_path, tmp_output_dir, '/usr/bin/codesign')

      expected_embedded_manifests = [{
          'codesign_identity': 'My fake codesign identity',
          'entitlements': 'fake.entitlements',
          'provisioning_profile': 'fake.mobileprovision',
          'embedded_relative_path': 'Frameworks/MyFramework.framework',
      }]
      self.assertEqual(
          actual_embedded_manifests, expected_embedded_manifests)

  def test_embedded_manifests_for_path_with_non_existing_directory(self):
    with (tempfile.TemporaryDirectory() as tmp_output_dir,
          tempfile.TemporaryDirectory(suffix='.app') as bundle_path):
      actual_embedded_manifests = (
          dossier_codesigningtool._embedded_manifests_for_path(
              bundle_path, tmp_output_dir, 'Frameworks', '/usr/bin/codesign'
          )
      )
      self.assertEqual([], actual_embedded_manifests)

  def test_embedded_manifests_for_path_with_unknown_bundle_directory(self):
    with self.assertRaisesRegex(
        ValueError,
        'Invalid bundle directory for dossier manifest: UnknownDirectory'):
      dossier_codesigningtool._embedded_manifests_for_path(
          '/path/to/fake.app',
          '/tmp/',
          'UnknownDirectory',
          '/usr/bin/codesign')

  @mock.patch.object(dossier_codesigningtool, '_extract_codesign_data')
  @mock.patch.object(dossier_codesigningtool, '_extract_provisioning_profile')
  @mock.patch.object(dossier_codesigningtool, '_embedded_manifests_for_path')
  def test_manifest_with_dossier_for_bundle_with_embedded_manifests(
      self,
      mock_embedded_manifests_for_path,
      mock_extract_provisioning_profile,
      mock_extract_codesign_data):
    mock_extract_codesign_data.return_value = (
        '/path/to/fake.entitlements', 'My fake codesign identity')
    mock_extract_provisioning_profile.return_value = (
        '/path/to/fake.mobileprovision')

    frameworks_embedded_manifest = {
        'codesign_identity': 'My fake codesign identity',
        'entitlements': 'fake.entitlements',
        'provisioning_profile': 'fake.mobileprovision',
        'embedded_relative_path': 'Frameworks/MyFramework.framework',
        'embedded_bundle_manifests': [],
    }
    plugins_embedded_manifest = {
        'codesign_identity': 'My fake codesign identity',
        'entitlements': 'fake.entitlements',
        'provisioning_profile': 'fake.mobileprovision',
        'embedded_relative_path': 'Plugins/WatchExtension.appex',
        'embedded_bundle_manifests': [],
    }
    watch_embedded_manifest = {
        'codesign_identity': 'My fake codesign identity',
        'entitlements': 'fake.entitlements',
        'provisioning_profile': 'fake.mobileprovision',
        'embedded_relative_path': 'Watch/WatchApp.app',
        'embedded_bundle_manifests': [],
    }
    mock_embedded_manifests_for_path.side_effect = [
        [],  # AppClips
        [plugins_embedded_manifest],  # PlugIns
        [frameworks_embedded_manifest],  # Frameworks
        [watch_embedded_manifest],  # Watch
    ]

    with (tempfile.TemporaryDirectory() as tmp_output_dir,
          tempfile.TemporaryDirectory(suffix='.app') as bundle_path):
      actual_manifest = (
          dossier_codesigningtool._manifest_with_dossier_for_bundle(
              bundle_path, tmp_output_dir, '/usr/bin/codesign'
          )
      )
      expected_manifest = {
          'codesign_identity': 'My fake codesign identity',
          'entitlements': '/path/to/fake.entitlements',
          'provisioning_profile': '/path/to/fake.mobileprovision',
          'embedded_bundle_manifests': [
              plugins_embedded_manifest,
              frameworks_embedded_manifest,
              watch_embedded_manifest,
          ],
      }
      self.assertDictEqual(expected_manifest, actual_manifest)

  @mock.patch.object(dossier_codesigningtool, '_extract_codesign_data')
  def test_manifest_with_dossier_for_bundle_with_no_codesign_identity(
      self, mock_extract_codesign_data):
    mock_extract_codesign_data.return_value = (None, None)
    with (tempfile.TemporaryDirectory() as tmp_output_dir,
          tempfile.TemporaryDirectory(suffix='.app') as bundle_path):
      self.assertIsNone(
          dossier_codesigningtool._manifest_with_dossier_for_bundle(
              bundle_path, tmp_output_dir, '/usr/bin/codesign'
          )
      )

  @mock.patch.object(dossier_codesigningtool, '_extract_codesign_data')
  @mock.patch.object(dossier_codesigningtool, '_embedded_manifests_for_path')
  def test_manifest_with_dossier_for_bundle_with_no_embedded_manifests(
      self, mock_embedded_manifests_for_path, mock_extract_codesign_data):
    mock_extract_codesign_data.return_value = (
        '/path/to/fake.entitlements', 'My fake codesign identity')
    mock_embedded_manifests_for_path.return_value = []
    with (tempfile.TemporaryDirectory() as tmp_output_dir,
          tempfile.TemporaryDirectory(suffix='.app') as bundle_path):
      actual_manifest = (
          dossier_codesigningtool._manifest_with_dossier_for_bundle(
              bundle_path, tmp_output_dir, '/usr/bin/codesign'
          )
      )
      expected_manifest = {
          'codesign_identity': 'My fake codesign identity',
          'entitlements': '/path/to/fake.entitlements',
      }
      self.assertDictEqual(expected_manifest, actual_manifest)

  @mock.patch('subprocess.Popen')
  def test_extract_codesign_data(self, mock_subprocess):
    mock_subprocess.return_value.communicate.return_value = (
        _FAKE_APP_XML_PLIST, _FAKE_CODESIGN_STDERR_WITH_SIGNING_AUTHORITY)
    mock_subprocess.return_value.poll.return_value = 0
    with (tempfile.TemporaryDirectory() as tmp_output_dir,
          tempfile.TemporaryDirectory(suffix='.app') as bundle_path):
      actual_entitlements_file, actual_codesign_identity = (
          dossier_codesigningtool._extract_codesign_data(
              bundle_path,
              tmp_output_dir,
              'my_unique_id',
              '/usr/bin/codesign',
          )
      )
      # Assert extracted codesign identity matches expected identity.
      expected_codesign_identity = (
          'Apple Development: Bazel Development (XXXXXXXXXX)')
      self.assertEqual(actual_codesign_identity, expected_codesign_identity)
      self.assertEqual(actual_entitlements_file, 'my_unique_id.entitlements')

      # Assert written entitlements file matches output.
      actual_entitlements_file_path = os.path.join(
          tmp_output_dir, actual_entitlements_file)
      with open(actual_entitlements_file_path, 'r') as fp:
        actual_entitlements_file_content = fp.read()
        self.assertEqual(actual_entitlements_file_content, _FAKE_APP_XML_PLIST)

  @mock.patch('subprocess.Popen')
  def test_extract_codesign_data_returns_none_for_adhoc_signature(
      self, mock_subprocess):
    mock_subprocess.return_value.communicate.return_value = (
        _FAKE_APP_XML_PLIST, _FAKE_CODESIGN_STDERR_WITH_ADHOC_SIGNING)
    mock_subprocess.return_value.poll.return_value = 0
    with (tempfile.TemporaryDirectory() as tmp_output_dir,
          tempfile.TemporaryDirectory(suffix='.app') as bundle_path):
      actual_entitlements_file, actual_codesign_identity = (
          dossier_codesigningtool._extract_codesign_data(
              bundle_path,
              tmp_output_dir,
              'my_unique_id',
              '/usr/bin/codesign',
          )
      )
      self.assertIsNone(actual_codesign_identity)
      self.assertEqual(actual_entitlements_file, 'my_unique_id.entitlements')


if __name__ == '__main__':
  unittest.main()
