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

"""File-system bundling logic for Apple bundles.

The bundler takes a set of files and merges them into an uncompressed ZIP file,
without building the actual file/directory structure for the bundle on the file
system. This greatly speeds up the bundling process when a large number of
resources are used, because it avoids performing a lot of small file copies.

This script takes a single argument that points to a file containing the JSON
representation of a "control" structure, which makes it easier to pass in
complex structured data. This control structure is a dictionary with the
following keys:

  bundle_path: The path relative to the archive root where the bundle files will
      be stored. Application targets, for example, might specify a path like
      "Payload/foo.app".
  bundle_merge_files: A list of dictionaries representing files to be merged
      into the bundle. Each dictionary contains the following fields: "src", the
      path of the file to be added to the bundle; "dest", the path inside the
      bundle where the file should live, including its filename (which lets the
      name be changed, if desired); and "executable", a Boolean value indicating
      whether or not the executable bit should be set on the file. If
      `executable` is omitted, False is used.
      The destination path is relative to `bundle_path`.
  bundle_merge_zips: A list of dictionaries representing ZIP archives whose
      contents should be merged into the bundle. Each dictionary contains two
      fields: "src", the path of the archive whose contents should be merged
      into the bundle; and "dest", the path inside the bundle where the ZIPs
      contents should be placed. The destination path is relative to
      `bundle_path`.
  output: The path to the uncompressed ZIP archive that should be created with
      the merged bundle contents.
  root_merge_zips: A list of dictionaries representing the ZIP archives whose
      contents should be merged into the archive at the root. Each dictionary
      contains two fields: "src", the path of the archive whose contents should
      be merged into the archive; and "dest", the path inside the archive where
      the ZIPs contents should be placed. This is used for support files, such
      as Swift libraries and watchOS stub executables, that must be shipped to
      Apple at the root of the archive as well as within the bundle itself.
"""

import hashlib
import json
import os
import stat
import sys
from typing import Optional, Union
import zipfile

BUNDLE_CONFLICT_MSG_TEMPLATE = (
    'Cannot place two files at the same location %r in the archive')

INVALID_SYMLINK_TARGET_MSG_TEMPLATE = (
    'Cannot create bundle symlink %r -> %r because the target escapes the '
    'bundle root')


class BundleConflictError(ValueError):
  """Raised when two different files would be bundled in the same location.

  Used to allow catching (and logging) just the bundletool errors.
  """

  def __init__(self, msg):
    """Initializes an error with the given message.

    Args:
      msg: The message for the error.
    """
    ValueError.__init__(self, msg)


class BadZipFileError(Exception):
  """Raised when testzip discovers a corrupt entry in the zip file."""


class BundleSymlinkError(ValueError):
  """Raised when a bundle symlink target escapes the bundle root."""

  def __init__(self, dest, target):
    self.dest = dest
    self.target = target
    ValueError.__init__(self, INVALID_SYMLINK_TARGET_MSG_TEMPLATE % (dest, target))


class Bundler(object):
  """Implements the core functionality of the bundler."""

  def __init__(self, control):
    """Initializes Bundler with the given control options.

    Args:
      control: The dictionary of options used to control the tool. Please see
          the moduledoc for a description of the format of this dictionary.
    """
    self._control = control

    # Keep track of hashes of each entry; this will be faster than pulling the
    # data back out of the archive as it's written.
    self._entry_hashes = {}

  def run(self):
    """Performs the operations requested by the control struct."""
    output_path = self._control.get('output')
    if not output_path:
      raise BundleConflictError('No output file specified.')

    bundle_path = self._control.get('bundle_path', '')
    bundle_merge_files = self._control.get('bundle_merge_files', [])
    bundle_merge_zips = self._control.get('bundle_merge_zips', [])
    root_merge_zips = self._control.get('root_merge_zips', [])
    compress = self._control.get('compress', False)

    with zipfile.ZipFile(output_path, 'w', allowZip64 = True) as out_zip:
      for z in bundle_merge_zips:
        dest = os.path.normpath(os.path.join(bundle_path, z['dest']))
        self._add_zip_contents(z['src'], dest, out_zip, compress)

      for f in bundle_merge_files:
        dest = os.path.join(bundle_path, f['dest'])
        self._add_files(
            f['src'],
            dest,
            f.get('executable', False),
            f.get('contents_only', False),
            f.get('normalize_bundle_file_permissions', False),
            out_zip,
            compress)

      for z in root_merge_zips:
        self._add_zip_contents(z['src'], z['dest'], out_zip, compress)

    with zipfile.ZipFile(output_path, 'r') as test_zip:
      badfile = test_zip.testzip()
      if badfile:
        raise BadZipFileError('Bad CRC-32 for file %s' % (badfile))

  def _add_files(self, src, dest, executable, contents_only,
                 normalize_bundle_file_permissions, out_zip, compress):
    """Adds a file or a directory of files to the ZIP archive.

    Args:
      src: The path to the file or directory that should be added.
      dest: The path inside the archive where the files should be stored. If
          `src` is a single file, then `dest` should include the filename that
          the file should have within the archive. If `src` is a directory, it
          represents the directory into which the files underneath `src` will
          be recursively added.
      executable: A Boolean value indicating whether or not the file(s) should
          be made executable. If a file is already executable, it will remain
          executable, regardless of this value.
      contents_only: A Boolean value indicating whether only the files in `src`
          or `src` itself should be added to the bundle (if `src` is a
          directory).
      normalize_bundle_file_permissions: A Boolean value indicating whether
          bundle entries should receive normalized executable permissions
          based on their destination paths.
      out_zip: The `ZipFile` into which the files should be added.
      compress: Whether the files are compressed or just stored in the zip.
    """
    if os.path.isdir(src):
      self._add_directory(
          src=src,
          dest=dest,
          executable=executable,
          contents_only=contents_only,
          normalize_bundle_file_permissions=normalize_bundle_file_permissions,
          out_zip=out_zip,
          compress=compress)
    elif os.path.isfile(src):
      fexec = self._entry_is_executable(
          src=src,
          dest=dest,
          executable=executable,
          normalize_bundle_file_permissions=normalize_bundle_file_permissions)
      with open(src, 'rb') as f:
        self._write_entry(
            dest=dest, data=f.read(), is_executable=fexec, out_zip=out_zip, compress=compress)

  def _add_directory(self, src, dest, executable, contents_only,
                     normalize_bundle_file_permissions, out_zip, compress):
    """Adds the contents of a directory to the ZIP archive."""
    root_path = os.path.abspath(src)

    def is_within_root(path):
      return os.path.commonpath([root_path, path]) == root_path

    def add_entry(path, entry_dest):
      if os.path.islink(path):
        link_target = os.readlink(path)
        if os.path.isabs(link_target):
          logical_target = os.path.normpath(link_target)
        else:
          logical_target = os.path.normpath(
              os.path.join(os.path.dirname(os.path.abspath(path)), link_target))

        if is_within_root(logical_target):
          if os.path.isabs(link_target):
            link_target = os.path.relpath(
                logical_target,
                os.path.dirname(os.path.abspath(path)))
          self._write_entry(
              dest=entry_dest,
              data=link_target,
              is_symlink=True,
              out_zip=out_zip,
              compress=compress)
          return
        path = os.path.realpath(path)

      if os.path.isdir(path):
        for child_name in sorted(os.listdir(path)):
          add_entry(
              os.path.join(path, child_name),
              os.path.normpath(os.path.join(entry_dest, child_name)))
      elif os.path.isfile(path):
        is_executable = self._entry_is_executable(
            src=path,
            dest=entry_dest,
            executable=executable,
            normalize_bundle_file_permissions=normalize_bundle_file_permissions)
        with open(path, 'rb') as f:
          self._write_entry(
              dest=entry_dest,
              data=f.read(),
              is_executable=is_executable,
              out_zip=out_zip,
              compress=compress)

    if contents_only:
      for child_name in sorted(os.listdir(src)):
        add_entry(
            os.path.join(src, child_name),
            os.path.normpath(os.path.join(dest, child_name)))
    else:
      add_entry(src, dest)

  def _entry_is_executable(self, src, dest, executable,
                           normalize_bundle_file_permissions):
    """Determines whether the given entry should be marked executable."""
    if executable:
      return True

    if not normalize_bundle_file_permissions:
      return os.access(src, os.X_OK)

    if '/Contents/MacOS/' in dest:
      return True
    if dest.endswith('.dylib'):
      return True
    if '.framework/' in dest:
      framework_name = dest.split('.framework/', 1)[0].rsplit('/', 1)[-1]
      return os.path.basename(dest) == framework_name
    if dest.endswith('/Info.plist') or '/Resources/' in dest:
      return False
    return os.access(src, os.X_OK)

  def _add_zip_contents(self, src, dest, out_zip, compress):
    """Adds the contents of another ZIP file to the output ZIP archive.

    Args:
      src: The path to the ZIP file whose contents should be added.
      dest: The path inside the output archive where the contents of `src`
          should be expanded. The directory structure of `src` is preserved
          underneath this path.
      out_zip: The `ZipFile` into which the files should be added.
      compress: Whether the files are compressed or just stored in the zip.
    """
    with zipfile.ZipFile(src, 'r', allowZip64 = True) as src_zip:
      for src_zipinfo in src_zip.infolist():
        # Normalize the destination path to remove any extraneous internal
        # slashes or "." segments, but retain the final slash for directory
        # entries.
        file_dest = os.path.normpath(os.path.join(dest, src_zipinfo.filename))
        if src_zipinfo.filename.endswith('/'):
          file_dest += '/'

        # Check POSIX permissions instead of passing-through the file
        # zipinfo.external_attr to standardize on a preferred set of permissions
        # because permission bits from incoming archives might not be set as
        # Apple expects these to be set on a bundle executable/file.
        #
        # Example: imported (e.g. library/framework) executables permissions can
        #          be set to: 'r-xr-xr-x' as opposed to the expected 'rwxr-xr-x'
        #
        unix_permissions = src_zipinfo.external_attr >> 16

        # Mark file as executable if at least one executable bit is set.
        is_executable = unix_permissions & 0o111 != 0

        is_symlink = stat.S_ISLNK(unix_permissions)
        data = src_zip.read(src_zipinfo)
        if is_symlink:
          self._validate_symlink_target(
              file_dest,
              data.decode('utf-8'))

        self._write_entry(
            dest=file_dest,
            data=data,
            is_executable=is_executable,
            is_symlink=is_symlink,
            out_zip=out_zip,
            compress=compress)

  def _validate_symlink_target(self, dest, target):
    """Validates that a symlink target does not escape the bundle root."""
    if os.path.isabs(target):
      raise BundleSymlinkError(dest, target)

    bundle_root = os.path.normpath('/bundle_root')
    full_dest = os.path.normpath(os.path.join(bundle_root, dest))
    target_path = os.path.normpath(os.path.join(os.path.dirname(full_dest), target))
    if os.path.commonpath([bundle_root, target_path]) != bundle_root:
      raise BundleSymlinkError(dest, target)

  def _write_entry(
      self,
      *,
      data: Union[str, bytes],
      dest: str,
      compress: bool,
      is_executable: Optional[bool] = False,
      is_symlink: Optional[bool] = False,
      out_zip: zipfile.ZipFile):
    """Writes the given data as a file in the output ZIP archive.

    Args:
      data: The data to be written in the archive.
      dest: The path inside the archive where the data should be written.
      is_executable: A Boolean value indicating whether or not the file should
          be made executable.
      is_symlink: A Boolean value indicating whether or not the file should
          be made a symbolic link.
      out_zip: The `ZipFile` into which the files should be added.
      compress: Whether the files are compressed or just stored in the zip.
    Raises:
      BundleConflictError: If two files with different content would be placed
          at the same location in the ZIP file.
    """
    if isinstance(data, str):
      data = data.encode('utf-8')

    entry_kind = 'directory' if dest.endswith('/') else 'symlink' if is_symlink else 'file'
    new_fingerprint = (
        hashlib.md5(data).digest(),
        entry_kind,
        bool(is_executable) if entry_kind == 'file' else False,
    )
    existing_fingerprint = self._entry_hashes.get(dest)
    if existing_fingerprint:
      if existing_fingerprint == new_fingerprint:
        return
      raise BundleConflictError(BUNDLE_CONFLICT_MSG_TEMPLATE % dest)

    self._entry_hashes[dest] = new_fingerprint

    zipinfo = zipfile.ZipInfo(dest)
    if compress:
      zipinfo.compress_type = zipfile.ZIP_DEFLATED
    else:
      zipinfo.compress_type = zipfile.ZIP_STORED

    if dest.endswith('/'):
      # Unix rwxr-xr-x permissions and S_IFDIR (directory) on the left side of
      # the bitwise-OR; MS-DOS directory flag on the right.
      zipinfo.external_attr = 0o040755 << 16 | 0x10
    else:
      # Unix rw-r--r-- permissions and S_IFREG (regular file).
      zipinfo.external_attr = 0o100644 << 16
      if is_executable:
        # Add Unix --x--x--x permissions.
        zipinfo.external_attr |= 0o111 << 16

    if is_symlink:
      # Symlink entries carry their own file type and stable permissions; assign
      # instead of OR-ing so regular-file bits do not leak into the entry.
      zipinfo.external_attr = 0o120755 << 16

    out_zip.writestr(zipinfo, data)


def _main(control_path):
  """Loads JSON parameters file and runs Bundler."""
  with open(control_path) as control_file:
    control = json.load(control_file)

  bundler = Bundler(control)
  try:
    bundler.run()
  except (BundleConflictError, BundleSymlinkError) as e:
    # Log tools errors cleanly for build output.
    sys.stderr.write('ERROR: %s\n' % e)
    sys.exit(1)


if __name__ == '__main__':
  if len(sys.argv) < 2:
    sys.stderr.write('ERROR: Path to control file not specified.\n')
    exit(1)

  _main(sys.argv[1])
