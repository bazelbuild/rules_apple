# coding=utf-8
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
"""Tests for dossier_codesigningtool."""

import concurrent.futures
import unittest

from unittest import mock

from build_bazel_rules_apple.tools.dossier_codesigningtool import dossier_codesigningtool

_FAKE_MANIFEST = {
    'codesign_identity': '-',
    'embedded_bundle_manifests': [
        {
            'codesign_identity': '-',
            'embedded_bundle_manifests': [],
            'embedded_relative_path': 'PlugIns/IntentsExtension.appex',
            'entitlements': 'fake.entitlements',
            'provisioning_profile': 'fake.mobileprovision'
        },
        {
            'codesign_identity': '-',
            'embedded_bundle_manifests': [],
            'embedded_relative_path': 'PlugIns/IntentsUIExtension.appex',
            'entitlements': 'fake.entitlements',
            'provisioning_profile': 'fake.mobileprovision'
        },
        {
            'codesign_identity': '-',
            'embedded_bundle_manifests': [{
                'codesign_identity': '-',
                'embedded_bundle_manifests': [],
                'embedded_relative_path': 'PlugIns/WatchExtension.appex',
                'entitlements': 'fake.entitlements',
                'provisioning_profile': 'fake.mobileprovision'
            }],
            'embedded_relative_path': 'Watch/WatchApp.app',
            'entitlements': 'fake.entitlements',
            'provisioning_profile': 'fake.mobileprovision'
        }
    ],
    'entitlements': 'fake.entitlements',
    'provisioning_profile': 'fake.mobileprovision'
}


class DossierCodesigningtoolTest(unittest.TestCase):

  @mock.patch.object(dossier_codesigningtool, '_invoke_codesign')
  def test_sign_bundle_with_manifest_codesign_invocations(self, mock_codesign):
    mock.patch('shutil.copy').start()
    dossier_codesigningtool._sign_bundle_with_manifest(
        root_bundle_path='/tmp/fake.app/',
        manifest=_FAKE_MANIFEST,
        dossier_directory='/tmp/dossier/',
        codesign_path='/usr/bin/fake_codesign',
        override_codesign_identity='-')

    self.assertEqual(mock_codesign.call_count, 5)
    actual_paths = [
        mock_codesign.call_args_list[0][1]['full_path_to_sign'],
        mock_codesign.call_args_list[1][1]['full_path_to_sign'],
        mock_codesign.call_args_list[2][1]['full_path_to_sign'],
        mock_codesign.call_args_list[3][1]['full_path_to_sign'],
        mock_codesign.call_args_list[4][1]['full_path_to_sign'],
    ]
    expected_paths = [
        '/tmp/fake.app/PlugIns/IntentsExtension.appex',
        '/tmp/fake.app/PlugIns/IntentsUIExtension.appex',
        '/tmp/fake.app/Watch/WatchApp.app/PlugIns/WatchExtension.appex',
        '/tmp/fake.app/Watch/WatchApp.app',
        '/tmp/fake.app/'
    ]
    self.assertSetEqual(set(actual_paths), set(expected_paths))

    # assert codesign threads block correctly (executed bottom-up)
    self.assertLess(
        actual_paths.index(
            '/tmp/fake.app/Watch/WatchApp.app/PlugIns/WatchExtension.appex'),
        actual_paths.index('/tmp/fake.app/Watch/WatchApp.app'))
    self.assertLess(
        actual_paths.index(
            '/tmp/fake.app/Watch/WatchApp.app/PlugIns/WatchExtension.appex'),
        actual_paths.index('/tmp/fake.app/'))

    self.assertLess(
        actual_paths.index('/tmp/fake.app/Watch/WatchApp.app'),
        actual_paths.index('/tmp/fake.app/'))
    self.assertLess(
        actual_paths.index('/tmp/fake.app/PlugIns/IntentsExtension.appex'),
        actual_paths.index('/tmp/fake.app/'))
    self.assertLess(
        actual_paths.index('/tmp/fake.app/PlugIns/IntentsUIExtension.appex'),
        actual_paths.index('/tmp/fake.app/'))

  @mock.patch.object(
      dossier_codesigningtool, '_fetch_preferred_signing_identity')
  def test_sign_bundle_with_manifest_raises_identity_infer_error(
      self, mock_fetch_preferred_signing_identity):
    fake_manifest = {'provisioning_profile': 'fake.mobileprovision'}
    mock_fetch_preferred_signing_identity.return_value = None

    with self.assertRaisesRegex(SystemExit, 'unable to infer identity'):
      dossier_codesigningtool._sign_bundle_with_manifest(
          root_bundle_path='/tmp/fake.app/',
          manifest=fake_manifest,
          dossier_directory='/tmp/dossier/',
          codesign_path='/usr/bin/fake_codesign')

  @mock.patch.object(dossier_codesigningtool, '_sign_bundle_with_manifest')
  def test_sign_embedded_bundles_with_manifest(self, mock_sign_bundle):
    mock_sign_bundle.return_value = concurrent.futures.Future()
    executor = concurrent.futures.ThreadPoolExecutor()
    futures = dossier_codesigningtool._sign_embedded_bundles_with_manifest(
        manifest=_FAKE_MANIFEST,
        root_bundle_path='/tmp/fake.app/',
        dossier_directory='/tmp/dossier/',
        codesign_path='/usr/bin/fake_codesign',
        codesign_identity='-',
        executor=executor)
    self.assertEqual(len(futures), 3)
    self.assertEqual(mock_sign_bundle.call_count, 3)
    default_args = ('/tmp/dossier/', '/usr/bin/fake_codesign', '-', executor)
    mock_sign_bundle.assert_has_calls([
        mock.call(
            '/tmp/fake.app/PlugIns/IntentsExtension.appex',
            {
                'codesign_identity': '-',
                'embedded_bundle_manifests': [],
                'embedded_relative_path': 'PlugIns/IntentsExtension.appex',
                'entitlements': 'fake.entitlements',
                'provisioning_profile': 'fake.mobileprovision'
            },
            *default_args),
        mock.call(
            '/tmp/fake.app/PlugIns/IntentsUIExtension.appex',
            {
                'codesign_identity': '-',
                'embedded_bundle_manifests': [],
                'embedded_relative_path': 'PlugIns/IntentsUIExtension.appex',
                'entitlements': 'fake.entitlements',
                'provisioning_profile': 'fake.mobileprovision'
            },
            *default_args),
        mock.call(
            '/tmp/fake.app/Watch/WatchApp.app',
            {
                'codesign_identity': '-',
                'embedded_bundle_manifests': [{
                    'codesign_identity': '-',
                    'embedded_bundle_manifests': [],
                    'embedded_relative_path': 'PlugIns/WatchExtension.appex',
                    'entitlements': 'fake.entitlements',
                    'provisioning_profile': 'fake.mobileprovision'
                }],
                'embedded_relative_path': 'Watch/WatchApp.app',
                'entitlements': 'fake.entitlements',
                'provisioning_profile': 'fake.mobileprovision'
            },
            *default_args),
    ])

  @mock.patch('shutil.copy')
  @mock.patch('os.path.exists')
  def test_copy_embedded_provisioning_profile(self, mock_exists, mock_copy):
    mock_exists.return_value = False
    dossier_codesigningtool._copy_embedded_provisioning_profile(
        provisioning_profile_file_path='/tmp/fake.mobileprovision',
        root_bundle_path='/tmp/fake.app/')
    mock_copy.assert_called_with(
        '/tmp/fake.mobileprovision', '/tmp/fake.app/embedded.mobileprovision')

    dossier_codesigningtool._copy_embedded_provisioning_profile(
        provisioning_profile_file_path='/tmp/fake.mobile',
        root_bundle_path='/tmp/fake.app/')
    mock_copy.assert_called_with(
        '/tmp/fake.mobile', '/tmp/fake.app/Contents/embedded.mobile')

  def test_wait_embedded_manifest_futures_reraises_exception(self):
    future_with_exception = concurrent.futures.Future()
    future_with_exception.set_exception(SystemExit)

    future_with_no_exception = concurrent.futures.Future()
    future_with_no_exception.set_result(None)
    futures = [future_with_exception, future_with_no_exception]

    with self.assertRaisesRegex(
        SystemExit, 'Signing failed.*codesign tasks failed'):
      dossier_codesigningtool._wait_embedded_manifest_futures(futures)

  def test_wait_embedded_manifest_futures_does_not_raises_exception(self):
    futures = []
    for _ in range(3):
      future = concurrent.futures.Future()
      future.set_result(None)
      futures.append(future)
    dossier_codesigningtool._wait_embedded_manifest_futures(futures)

  @mock.patch('concurrent.futures.wait')
  def test_wait_embedded_manifest_futures_cancel_futures(self, mock_wait):
    mock_future_done = mock.Mock()
    mock_future_exception = mock.Mock()
    mock_future_not_done = mock.Mock()

    mock_future_exception.exception.return_value = SystemExit()
    mock_wait.return_value = (
        [mock_future_exception, mock_future_done], [mock_future_not_done])

    futures = [
        mock_future_exception, mock_future_done, mock_future_not_done]

    with self.assertRaisesRegex(
        SystemExit, 'Signing failed.*codesign tasks failed'):
      dossier_codesigningtool._wait_embedded_manifest_futures(futures)

    mock_future_not_done.cancel.assert_called()
    mock_future_exception.cancel.assert_not_called()
    mock_future_done.cancel.assert_not_called()

if __name__ == '__main__':
  unittest.main()
