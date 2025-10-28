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

  bundle_merge_files: A list of dictionaries representing files to be merged
      into the bundle. Each dictionary contains the following fields: "src", the
      path of the file to be added to the bundle; "dest", the path inside the
      bundle where the file should live, including its filename (which lets the
      name be changed, if desired).
  bundle_merge_zips: A list of dictionaries representing ZIP archives whose
      contents should be merged into the bundle. Each dictionary contains two
      fields: "src", the path of the archive whose contents should be merged
      into the bundle; and "dest", the path inside the bundle where the ZIPs
      contents should be placed.
  output: The path to the uncompressed ZIP archive that should be created with
      the merged bundle contents.
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

    bundle_merge_files = self._control.get('bundle_merge_files', [])
    bundle_merge_zips = self._control.get('bundle_merge_zips', [])

    with zipfile.ZipFile(output_path, 'w') as out_zip:
      for z in bundle_merge_zips:
        dest = os.path.normpath(z['dest'])
        self._add_zip_contents(z['src'], dest, out_zip)

      for f in bundle_merge_files:
        dest = f['dest']
        self._add_files(f['src'], dest, out_zip)

    with zipfile.ZipFile(output_path, 'r') as test_zip:
      badfile = test_zip.testzip()
      if badfile:
        raise BadZipFileError('Bad CRC-32 for file %s' % (badfile))

  def _add_files(self, src, dest, out_zip):
    """Adds a file or a directory of files to the ZIP archive.

    Args:
      src: The path to the file or directory that should be added.
      dest: The path inside the archive where the files should be stored. If
          `src` is a single file, then `dest` should include the filename that
          the file should have within the archive. If `src` is a directory, it
          represents the directory into which the files underneath `src` will
          be recursively added.
      out_zip: The `ZipFile` into which the files should be added.
    """
    if os.path.isdir(src):
      for root, _, files in os.walk(src):
        relpath = os.path.relpath(root, src)
        for filename in files:
          fsrc = os.path.join(root, filename)
          fdest = os.path.normpath(os.path.join(dest, relpath, filename))
          fexec = os.access(fsrc, os.X_OK)
          with open(fsrc, 'rb') as f:
            self._write_entry(
                dest=fdest, data=f.read(), is_executable=fexec, out_zip=out_zip)
    elif os.path.isfile(src):
      fexec = os.access(src, os.X_OK)
      with open(src, 'rb') as f:
        self._write_entry(
            dest=dest, data=f.read(), is_executable=fexec, out_zip=out_zip)

  def _add_zip_contents(self, src, dest, out_zip):
    """Adds the contents of another ZIP file to the output ZIP archive.

    Args:
      src: The path to the ZIP file whose contents should be added.
      dest: The path inside the output archive where the contents of `src`
          should be expanded. The directory structure of `src` is preserved
          underneath this path.
      out_zip: The `ZipFile` into which the files should be added.
    """
    with zipfile.ZipFile(src, 'r') as src_zip:
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

        self._write_entry(
            dest=file_dest,
            data=src_zip.read(src_zipinfo),
            is_executable=is_executable,
            is_symlink=is_symlink,
            out_zip=out_zip)

  def _write_entry(
      self,
      *,
      data: Union[str, bytes],
      dest: str,
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
    Raises:
      BundleConflictError: If two files with different content would be placed
          at the same location in the ZIP file.
    """
    new_hash = hashlib.md5(data).digest()
    existing_hash = self._entry_hashes.get(dest)
    if existing_hash:
      if existing_hash == new_hash:
        return
      raise BundleConflictError(BUNDLE_CONFLICT_MSG_TEMPLATE % dest)

    self._entry_hashes[dest] = new_hash

    zipinfo = zipfile.ZipInfo(dest)
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
      zipinfo.external_attr |= stat.S_IFLNK << 16

    out_zip.writestr(zipinfo, data)


def _main(control_path):
  """Loads JSON parameters file and runs Bundler."""
  with open(control_path) as control_file:
    control = json.load(control_file)

  bundler = Bundler(control)
  try:
    bundler.run()
  except BundleConflictError as e:
    # Log tools errors cleanly for build output.
    sys.stderr.write('ERROR: %s\n' % e)
    sys.exit(1)


if __name__ == '__main__':
  if len(sys.argv) < 2:
    sys.stderr.write('ERROR: Path to control file not specified.\n')
    exit(1)

  _main(sys.argv[1])
