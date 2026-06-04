# Copyright 2017 The Bazel Authors. All rights reserved.
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

"""Tests for Bundler."""

import contextlib
import io
import json
import os
import re
import shutil
import stat
import tempfile
import unittest
import zipfile

from tools.bundletool import bundletool


def _run_bundler(control):
  """Helper function that runs Bundler with the given control struct.

  This function inserts a BytesIO object as the control's "output" key and
  returns it after bundling; this object will contain the binary data for the
  ZIP file that was created, which can then be reopened and tested.

  Args:
    control: The control struct to pass to Bundler. See the module doc for
        the bundletool module for a description of this format.
  Returns:
    The BytesIO object containing the binary data for a bundled ZIP file.
  """
  output = io.BytesIO()
  control['output'] = output

  tool = bundletool.Bundler(control)
  tool.run()

  return output


class BundlerTest(unittest.TestCase):

  def setUp(self):
    super().setUp()
    self._scratch_dir = tempfile.mkdtemp('bundlerTestScratch')

  def tearDown(self):
    super().tearDown()
    shutil.rmtree(self._scratch_dir)

  def _scratch_file(self, name, content='', executable=False):
    """Creates a scratch file with the given name.

    The scratch file's path, which is returned by this function, can then be
    passed into the bundler as one of its `bundle_merge_files`.

    Args:
      name: The name of the file.
      content: The content to write into the file. The default is empty.
      executable: True if the file should be executable, False otherwise.
    Returns:
      The absolute path to the file.
    """
    path = os.path.join(self._scratch_dir, name)
    dirname = os.path.dirname(path)
    if not os.path.isdir(dirname):
      os.makedirs(dirname)

    with open(path, 'w') as f:
      f.write(content)
    if executable:
      st = os.stat(path)
      os.chmod(path, st.st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    return path

  def _scratch_zip(self, name, *entries):
    """Creates a scratch ZIP file with the given entries.

    The scratch ZIP's path, which is returned by this function, can then be
    passed into the bunlder as one of its `bundle_merge_zips` or
    `root_merge_zips`.

    Args:
      name: The name of the ZIP file.
      *entries: A list of archive-relative paths that will represent empty
          files in the ZIP. If a path entry begins with a "*", it will be made
          executable. If a path entry contains a colon, the text after the
          colon will be used as the content of the file.
    Returns:
      The absolute path to the ZIP file.
    """
    path = os.path.join(self._scratch_dir, name)
    with zipfile.ZipFile(path, 'w') as z:
      for entry in entries:
        executable = entry.startswith('*')
        entry_without_content, _, content = entry.partition(':')

        zipinfo = zipfile.ZipInfo(entry_without_content.rpartition('*')[-1])
        zipinfo.compress_type = zipfile.ZIP_STORED
        # Unix rw-r--r-- permissions and S_IFREG (regular file).
        zipinfo.external_attr = 0o100644 << 16
        if executable:
          zipinfo.external_attr = 0o111 << 16
        z.writestr(zipinfo, content)
    return path

  def _scratch_symlink_zip(self, name, entry, target):
    path = os.path.join(self._scratch_dir, name)
    with zipfile.ZipFile(path, 'w') as z:
      zipinfo = zipfile.ZipInfo(entry)
      zipinfo.compress_type = zipfile.ZIP_STORED
      zipinfo.external_attr = 0o120755 << 16
      z.writestr(zipinfo, target)
    return path

  def _assert_zip_contains(self, zip_file, entry, executable=False,
                           compressed=False):
    """Asserts that a `ZipFile` has an entry with the given path.

    This is a convenience function that catches the `KeyError` that would be
    raised if the entry was not found and turns it into a test failure.

    Args:
      zip_file: The `ZipFile` object.
      entry: The archive-relative path to verify.
      executable: The expected value of the executable bit (True or False).
      compressed: If the entry should be compressed (True or False).
    """
    try:
      zipinfo = zip_file.getinfo(entry)
      if executable:
        self.assertEqual(
            0o111, zipinfo.external_attr >> 16 & 0o111,
            'Expected %r to be executable, but it was not' % entry)
      else:
        self.assertEqual(
            0, zipinfo.external_attr >> 16 & 0o111,
            'Expected %r not to be executable, but it was' % entry)

      if compressed:
        self.assertEqual(
            zipfile.ZIP_DEFLATED, zipinfo.compress_type,
            'Expected %r to be compressed, but it was not' % entry)
      else:
        self.assertEqual(
            zipfile.ZIP_STORED, zipinfo.compress_type,
            'Expected %r not to be compressed, but it was' % entry)
    except KeyError:
      self.fail('Bundled ZIP should have contained %r, but it did not' % entry)

  def _assert_zip_contains_symlink(self, zip_file, entry, target):
    try:
      zipinfo = zip_file.getinfo(entry)
      self.assertTrue(
          stat.S_ISLNK(zipinfo.external_attr >> 16),
          'Expected %r to be a symlink, but it was not' % entry)
      self.assertEqual(target.encode('utf-8'), zip_file.read(entry))
    except KeyError:
      self.fail('Bundled ZIP should have contained symlink %r, but it did not' % entry)

  def test_bundle_merge_files(self):
    out_zip = _run_bundler({
        'bundle_path': 'Payload/foo.app',
        'bundle_merge_files': [
            {'src': self._scratch_file('foo.txt'), 'dest': 'foo.txt'},
            {'src': self._scratch_file('bar.txt'), 'dest': 'bar.txt'},
        ]
    })
    with zipfile.ZipFile(out_zip, 'r') as z:
      self._assert_zip_contains(z, 'Payload/foo.app/foo.txt')
      self._assert_zip_contains(z, 'Payload/foo.app/bar.txt')

  def test_bundle_merge_files_with_executable(self):
    out_zip = _run_bundler({
        'bundle_path': 'Payload/foo.app',
        'bundle_merge_files': [
            {'src': self._scratch_file('foo.exe'), 'dest': 'foo.exe',
             'executable': True},
            {'src': self._scratch_file('bar.txt'), 'dest': 'bar.txt',
             'executable': False},
            {'src': self._scratch_file('baz.txt', executable=True),
             'dest': 'baz.txt', 'executable': False},
        ]
    })
    with zipfile.ZipFile(out_zip, 'r') as z:
      self._assert_zip_contains(z, 'Payload/foo.app/foo.exe', True)
      self._assert_zip_contains(z, 'Payload/foo.app/bar.txt', False)
      self._assert_zip_contains(z, 'Payload/foo.app/baz.txt', True)

  def test_bundle_merge_files_with_renaming(self):
    out_zip = _run_bundler({
        'bundle_path': 'Payload/foo.app',
        'bundle_merge_files': [
            {'src': self._scratch_file('foo.txt'), 'dest': 'renamed1'},
            {'src': self._scratch_file('bar.txt'), 'dest': 'renamed2'},
        ]
    })
    with zipfile.ZipFile(out_zip, 'r') as z:
      self._assert_zip_contains(z, 'Payload/foo.app/renamed1')
      self._assert_zip_contains(z, 'Payload/foo.app/renamed2')

  def test_bundle_merge_files_with_directories(self):
    a_txt = self._scratch_file('a.txt')
    root = os.path.dirname(a_txt)
    self._scratch_file('b.txt')
    self._scratch_file('c/d.txt')
    self._scratch_file('c/e/f.txt', executable=True)

    out_zip = _run_bundler({
        'bundle_path': 'Payload/foo.app',
        'bundle_merge_files': [{'src': root, 'dest': 'x/y/z'}],
    })
    with zipfile.ZipFile(out_zip, 'r') as z:
      self._assert_zip_contains(z, 'Payload/foo.app/x/y/z/a.txt')
      self._assert_zip_contains(z, 'Payload/foo.app/x/y/z/b.txt')
      self._assert_zip_contains(z, 'Payload/foo.app/x/y/z/c/d.txt')
      self._assert_zip_contains(z, 'Payload/foo.app/x/y/z/c/e/f.txt', True)

  def test_bundle_merge_files_with_directories_preserves_symlinks(self):
    root = os.path.join(self._scratch_dir, 'framework')
    versions_dir = os.path.join(root, 'Versions', 'A')
    resources_dir = os.path.join(versions_dir, 'Resources')
    os.makedirs(resources_dir)
    self._scratch_file('framework/Versions/A/generated_fmwk', executable=True)
    self._scratch_file('framework/Versions/A/Resources/Info.plist')
    os.symlink('A', os.path.join(root, 'Versions', 'Current'))
    os.symlink(
        'Versions/Current/generated_fmwk',
        os.path.join(root, 'generated_fmwk'))
    os.symlink(
        'Versions/Current/Resources',
        os.path.join(root, 'Resources'))

    out_zip = _run_bundler({
        'bundle_merge_files': [{'src': root, 'dest': 'Foo.framework'}],
    })
    with zipfile.ZipFile(out_zip, 'r') as z:
      self._assert_zip_contains(
          z, 'Foo.framework/Versions/A/generated_fmwk', True)
      self._assert_zip_contains(
          z, 'Foo.framework/Versions/A/Resources/Info.plist')
      self._assert_zip_contains_symlink(
          z, 'Foo.framework/Versions/Current', 'A')
      self._assert_zip_contains_symlink(
          z, 'Foo.framework/generated_fmwk',
          'Versions/Current/generated_fmwk')
      self._assert_zip_contains_symlink(
          z, 'Foo.framework/Resources',
          'Versions/Current/Resources')

  def test_bundle_merge_files_with_directories_rewrites_absolute_internal_symlinks(self):
    root = os.path.join(self._scratch_dir, 'framework')
    versions_dir = os.path.join(root, 'Versions', 'A')
    os.makedirs(versions_dir)
    target = self._scratch_file('framework/Versions/A/generated_fmwk', executable=True)
    os.symlink(target, os.path.join(root, 'generated_fmwk'))

    out_zip = _run_bundler({
        'bundle_merge_files': [{'src': root, 'dest': 'Foo.framework'}],
    })
    with zipfile.ZipFile(out_zip, 'r') as z:
      self._assert_zip_contains(
          z, 'Foo.framework/Versions/A/generated_fmwk', True)
      self._assert_zip_contains_symlink(
          z, 'Foo.framework/generated_fmwk',
          'Versions/A/generated_fmwk')

  def test_bundle_merge_files_with_directories_dereferences_external_symlinks(self):
    root = os.path.join(self._scratch_dir, 'app')
    os.makedirs(root)
    external_file = self._scratch_file('external/Info.plist', content='plist')
    os.symlink(external_file, os.path.join(root, 'Info.plist'))

    out_zip = _run_bundler({
        'bundle_merge_files': [{'src': root, 'dest': 'App.app'}],
    })
    with zipfile.ZipFile(out_zip, 'r') as z:
      self._assert_zip_contains(z, 'App.app/Info.plist')
      self.assertFalse(
          stat.S_ISLNK(z.getinfo('App.app/Info.plist').external_attr >> 16),
          'Expected App.app/Info.plist to be stored as a regular file')
      self.assertEqual(b'plist', z.read('App.app/Info.plist'))

  def test_bundle_merge_files_normalizes_bundle_permissions(self):
    root = os.path.join(self._scratch_dir, 'app.app', 'Contents')
    os.makedirs(os.path.join(root, 'MacOS'))
    framework_resources = os.path.join(
        root, 'Frameworks', 'Foo.framework', 'Versions', 'A', 'Resources')
    os.makedirs(framework_resources)
    self._scratch_file('app.app/Contents/Info.plist', executable=True)
    self._scratch_file('app.app/Contents/MacOS/app', executable=True)
    self._scratch_file('app.app/Contents/Helpers/tool', executable=True)
    self._scratch_file(
        'app.app/Contents/Frameworks/Foo.framework/Versions/A/Resources/Info.plist',
        executable=True)
    self._scratch_file(
        'app.app/Contents/Frameworks/Foo.framework/Versions/A/Foo',
        executable=True)

    out_zip = _run_bundler({
        'bundle_merge_files': [{
            'src': os.path.join(self._scratch_dir, 'app.app'),
            'dest': 'app.app',
            'normalize_bundle_file_permissions': True,
        }],
    })
    with zipfile.ZipFile(out_zip, 'r') as z:
      self._assert_zip_contains(z, 'app.app/Contents/Info.plist', False)
      self._assert_zip_contains(z, 'app.app/Contents/MacOS/app', True)
      self._assert_zip_contains(z, 'app.app/Contents/Helpers/tool', True)
      self._assert_zip_contains(
          z,
          'app.app/Contents/Frameworks/Foo.framework/Versions/A/Resources/Info.plist',
          False)
      self._assert_zip_contains(
          z,
          'app.app/Contents/Frameworks/Foo.framework/Versions/A/Foo',
          True)

  def test_bundle_merge_files_normalizes_nested_bundle_permissions_in_resources(self):
    os.makedirs(os.path.join(
        self._scratch_dir,
        'app.app',
        'Contents',
        'Resources',
        'Helper.app',
        'Contents',
        'MacOS'))
    self._scratch_file(
        'app.app/Contents/Resources/Helper.app/Contents/Info.plist',
        executable=True)
    self._scratch_file(
        'app.app/Contents/Resources/Helper.app/Contents/MacOS/Helper',
        executable=True)

    out_zip = _run_bundler({
        'bundle_merge_files': [{
            'src': os.path.join(self._scratch_dir, 'app.app'),
            'dest': 'app.app',
            'normalize_bundle_file_permissions': True,
        }],
    })
    with zipfile.ZipFile(out_zip, 'r') as z:
      self._assert_zip_contains(
          z,
          'app.app/Contents/Resources/Helper.app/Contents/Info.plist',
          False)
      self._assert_zip_contains(
          z,
          'app.app/Contents/Resources/Helper.app/Contents/MacOS/Helper',
          True)

  def test_bundle_merge_zips(self):
    foo_zip = self._scratch_zip('foo.zip',
                                'foo.bundle/img.png', 'foo.bundle/strings.txt')
    bar_zip = self._scratch_zip('bar.zip',
                                'bar.bundle/img.png', 'bar.bundle/strings.txt')
    out_zip = _run_bundler({
        'bundle_path': 'Payload/foo.app',
        'bundle_merge_zips': [
            {'src': foo_zip, 'dest': '.'},
            {'src': bar_zip, 'dest': '.'},
        ]
    })
    with zipfile.ZipFile(out_zip, 'r') as z:
      self._assert_zip_contains(z, 'Payload/foo.app/foo.bundle/img.png')
      self._assert_zip_contains(z, 'Payload/foo.app/foo.bundle/strings.txt')
      self._assert_zip_contains(z, 'Payload/foo.app/bar.bundle/img.png')
      self._assert_zip_contains(z, 'Payload/foo.app/bar.bundle/strings.txt')

  def test_bundle_merge_zips_propagates_executable(self):
    foo_zip = self._scratch_zip('foo.zip', '*foo.bundle/some.exe')
    out_zip = _run_bundler({
        'bundle_path': 'Payload/foo.app',
        'bundle_merge_zips': [{'src': foo_zip, 'dest': '.'}],
    })
    with zipfile.ZipFile(out_zip, 'r') as z:
      self._assert_zip_contains(z, 'Payload/foo.app/foo.bundle/some.exe', True)

  def test_root_merge_zips(self):
    support_zip = self._scratch_zip('support.zip', 'SomeSupport/some.dylib')
    out_zip = _run_bundler({
        'bundle_path': 'Payload/foo.app',
        'root_merge_zips': [{'src': support_zip, 'dest': '.'}],
    })
    with zipfile.ZipFile(out_zip, 'r') as z:
      self._assert_zip_contains(z, 'SomeSupport/some.dylib')

  def test_root_merge_zips_with_different_destination(self):
    support_zip = self._scratch_zip('support.zip', 'some.dylib')
    out_zip = _run_bundler({
        'bundle_path': 'Payload/foo.app',
        'root_merge_zips': [{'src': support_zip, 'dest': 'SomeSupport'}],
    })
    with zipfile.ZipFile(out_zip, 'r') as z:
      self._assert_zip_contains(z, 'SomeSupport/some.dylib')

  def test_root_merge_zips_propagates_executable(self):
    support_zip = self._scratch_zip('support.zip', '*SomeSupport/some.dylib')
    out_zip = _run_bundler({
        'bundle_path': 'Payload/foo.app',
        'root_merge_zips': [{'src': support_zip, 'dest': '.'}],
    })
    with zipfile.ZipFile(out_zip, 'r') as z:
      self._assert_zip_contains(z, 'SomeSupport/some.dylib', True)

  def test_duplicate_files_with_same_content_are_allowed(self):
    foo_txt = self._scratch_file('foo.txt', 'foo')
    bar_txt = self._scratch_file('bar.txt', 'foo')
    out_zip = _run_bundler({
        'bundle_path': 'Payload/foo.app',
        'bundle_merge_files': [
            {'src': foo_txt, 'dest': 'renamed'},
            {'src': bar_txt, 'dest': 'renamed'},
        ]
    })
    with zipfile.ZipFile(out_zip, 'r') as z:
      self._assert_zip_contains(z, 'Payload/foo.app/renamed')

  def test_duplicate_files_with_different_content_raise_error(self):
    foo_txt = self._scratch_file('foo.txt', 'foo')
    bar_txt = self._scratch_file('bar.txt', 'bar')
    with self.assertRaisesRegex(
        bundletool.BundleConflictError,
        re.escape(bundletool.BUNDLE_CONFLICT_MSG_TEMPLATE %
                  'Payload/foo.app/renamed')):
      _run_bundler({
          'bundle_path': 'Payload/foo.app',
          'bundle_merge_files': [
              {'src': foo_txt, 'dest': 'renamed'},
              {'src': bar_txt, 'dest': 'renamed'},
          ]
      })

  def test_zips_with_duplicate_files_but_same_content_are_allowed(self):
    one_zip = self._scratch_zip('one.zip', 'some.dylib:foo')
    two_zip = self._scratch_zip('two.zip', 'some.dylib:foo')
    out_zip = _run_bundler({
        'bundle_path': 'Payload/foo.app',
        'bundle_merge_zips': [
            {'src': one_zip, 'dest': '.'},
            {'src': two_zip, 'dest': '.'},
        ]
    })
    with zipfile.ZipFile(out_zip, 'r') as z:
      self._assert_zip_contains(z, 'Payload/foo.app/some.dylib')

  def test_zips_with_escaping_symlink_raise_error(self):
    support_zip = self._scratch_symlink_zip('support.zip', 'some.dylib', '../outside')
    with self.assertRaisesRegex(
        bundletool.BundleSymlinkError,
        re.escape(bundletool.INVALID_SYMLINK_TARGET_MSG_TEMPLATE %
                  ('some.dylib', '../outside'))):
      _run_bundler({
          'bundle_merge_zips': [{'src': support_zip, 'dest': '.'}],
      })

  def test_zips_with_absolute_symlink_raise_error(self):
    support_zip = self._scratch_symlink_zip('support.zip', 'some.dylib', '/tmp/outside')
    with self.assertRaisesRegex(
        bundletool.BundleSymlinkError,
        re.escape(bundletool.INVALID_SYMLINK_TARGET_MSG_TEMPLATE %
                  ('Payload/foo.app/some.dylib', '/tmp/outside'))):
      _run_bundler({
          'bundle_path': 'Payload/foo.app',
          'bundle_merge_zips': [{'src': support_zip, 'dest': '.'}],
      })

  def test_main_reports_symlink_errors(self):
    support_zip = self._scratch_symlink_zip(
        'support.zip', 'some.dylib', '../outside')
    expected_error = bundletool.INVALID_SYMLINK_TARGET_MSG_TEMPLATE % (
        'some.dylib', '../outside')
    control_path = self._scratch_file('control.json', json.dumps({
        'output': os.path.join(self._scratch_dir, 'out.zip'),
        'bundle_merge_zips': [{'src': support_zip, 'dest': '.'}],
    }))

    stderr = io.StringIO()
    with contextlib.redirect_stderr(stderr):
      with self.assertRaises(SystemExit) as context:
        bundletool._main(control_path)

    self.assertEqual(1, context.exception.code)
    self.assertEqual('ERROR: %s\n' % expected_error, stderr.getvalue())

  def test_zip_file_and_symlink_with_same_content_raise_error(self):
    one_zip = self._scratch_zip('one.zip', 'some.dylib:foo')
    two_zip = self._scratch_symlink_zip('two.zip', 'some.dylib', 'foo')
    with self.assertRaisesRegex(
        bundletool.BundleConflictError,
        re.escape(bundletool.BUNDLE_CONFLICT_MSG_TEMPLATE %
                  'Payload/foo.app/some.dylib')):
      _run_bundler({
          'bundle_path': 'Payload/foo.app',
          'bundle_merge_zips': [
              {'src': one_zip, 'dest': '.'},
              {'src': two_zip, 'dest': '.'},
          ]
      })

  def test_zips_with_duplicate_files_and_different_content_raise_error(self):
    one_zip = self._scratch_zip('one.zip', 'some.dylib:foo')
    two_zip = self._scratch_zip('two.zip', 'some.dylib:bar')
    with self.assertRaisesRegex(
        bundletool.BundleConflictError,
        re.escape(bundletool.BUNDLE_CONFLICT_MSG_TEMPLATE %
                  'Payload/foo.app/some.dylib')):
      _run_bundler({
          'bundle_path': 'Payload/foo.app',
          'bundle_merge_zips': [
              {'src': one_zip, 'dest': '.'},
              {'src': two_zip, 'dest': '.'},
          ]
      })

  def test_compressed_entries(self):
    a_txt = self._scratch_file('a.txt')
    root = os.path.dirname(a_txt)
    out_zip = _run_bundler({
        'bundle_path': 'Payload/foo.app',
        'bundle_merge_files': [{'src': root, 'dest': 'x/y/z'}],
        'compress': True,
    })
    with zipfile.ZipFile(out_zip, 'r') as z:
      self._assert_zip_contains(z, 'Payload/foo.app/x/y/z/a.txt', compressed=True)

if __name__ == '__main__':
  unittest.main()
