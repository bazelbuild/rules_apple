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
"""Generates App Shortcuts Flexible Matching assets with appintentsnltrainingprocessor.

appintentsnltrainingprocessor trains one model for each .lproj directory in the product directory,
plus the Info.plist's CFBundleDevelopmentRegion. It reads AppShortcuts.strings and InfoPlist.strings
from each .lproj directory and writes <locale>.lproj/nlu.appintents/ into the product directory.
This wrapper stages those inputs in a temporary product directory, copies the generated files to
the output directory, and zeroes the generation timestamp in each nlu.lzfse.
"""

import argparse
import os
import plistlib
import re
import shutil
import struct
import sys
import tempfile
import time

from tools.wrapper_common import execute

_LOCALIZED_STRINGS_BASENAMES = ("AppShortcuts.strings", "InfoPlist.strings")
_ERROR_RE = re.compile(r"\berror:")


def zero_timestamps(data, start, end):
  """Returns data with each 4-byte aligned little-endian integer in [start, end] set to zero.

  Each nlu.lzfse decompresses to a FlatBuffer that stores its generation time as seconds since
  the Unix epoch. The schema is not public, so this searches for values in the time range when the
  tool ran.
  """
  result = bytearray(data)
  for offset in range(0, len(result) - 3, 4):
    (value,) = struct.unpack_from("<I", result, offset)
    if start <= value <= end:
      struct.pack_into("<I", result, offset, 0)
  return bytes(result)


def _normalize_nlu_archive(src, dest, start, end, work_dir):
  """Writes src to dest with its generation timestamp set to zero."""
  decoded_path = os.path.join(work_dir, "nlu.decoded")
  normalized_path = os.path.join(work_dir, "nlu.normalized")
  _compression_tool("-decode", src, decoded_path)
  with open(decoded_path, "rb") as f:
    decoded = f.read()
  with open(normalized_path, "wb") as f:
    f.write(zero_timestamps(decoded, start, end))
  _compression_tool("-encode", normalized_path, dest)


def _compression_tool(mode, src, dest):
  execute.execute_and_filter_output(
      ["/usr/bin/compression_tool", mode, "-a", "lzfse", "-i", src, "-o", dest],
      raise_on_failure=True,
  )


def _stage_file(src, relpath, product_dir, staged_paths):
  dest = os.path.join(product_dir, relpath)
  os.makedirs(os.path.dirname(dest), exist_ok=True)
  shutil.copyfile(src, dest)
  staged_paths.add(relpath)


def _stage_resource_tree(tree, product_dir, staged_paths):
  """Stages the .lproj directories at the root of tree, such as those compiled from xcstrings."""
  for name in sorted(os.listdir(tree)):
    lproj_path = os.path.join(tree, name)
    if not name.endswith(".lproj") or not os.path.isdir(lproj_path):
      continue
    os.makedirs(os.path.join(product_dir, name), exist_ok=True)
    for basename in _LOCALIZED_STRINGS_BASENAMES:
      src = os.path.join(lproj_path, basename)
      if os.path.isfile(src):
        _stage_file(src, os.path.join(name, basename), product_dir, staged_paths)


def _development_region(infoplist):
  with open(infoplist, "rb") as f:
    return plistlib.load(f).get("CFBundleDevelopmentRegion")


def _parse_args(argv):
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("--bundle-id", required=True)
  parser.add_argument("--infoplist", required=True, help="The bundle's merged Info.plist.")
  parser.add_argument("--metadata", required=True, help="The bundle's Metadata.appintents.")
  parser.add_argument("--output", required=True, help="The output directory.")
  parser.add_argument(
      "--lproj",
      action="append",
      default=[],
      help="The name of an .lproj directory in the bundle.",
  )
  parser.add_argument(
      "--lproj-file",
      action="append",
      default=[],
      metavar=("LPROJ", "PATH"),
      nargs=2,
      help="A strings file to place in the named .lproj directory.",
  )
  parser.add_argument(
      "--resource-tree",
      action="append",
      default=[],
      help="A directory bundled at the root of the resources that may contain .lproj directories.",
  )
  return parser.parse_args(argv)


def main(argv):
  args = _parse_args(argv)
  os.makedirs(args.output, exist_ok=True)

  with tempfile.TemporaryDirectory() as work_dir:
    product_dir = os.path.join(work_dir, "product")
    ssu_dir = os.path.join(work_dir, "ssu")
    os.makedirs(product_dir)
    os.makedirs(ssu_dir)

    staged_paths = set()
    for lproj in args.lproj:
      os.makedirs(os.path.join(product_dir, lproj), exist_ok=True)
    for lproj, path in args.lproj_file:
      _stage_file(path, os.path.join(lproj, os.path.basename(path)), product_dir, staged_paths)
    for tree in args.resource_tree:
      _stage_resource_tree(tree, product_dir, staged_paths)

    # With no locale to train, the tool prints an error but exits with status 0.
    if not os.listdir(product_dir) and not _development_region(args.infoplist):
      return 0

    # The tool writes root.ssu.yaml into the --extracted-metadata-path directory, which is a
    # read-only input, unless --deployment-postprocessing is passed.
    start = int(time.time())
    returncode, stdout, stderr = execute.execute_and_filter_output([
        "/usr/bin/xcrun",
        "appintentsnltrainingprocessor",
        "--infoplist-path", args.infoplist,
        "--temp-dir-path", ssu_dir,
        "--bundle-id", args.bundle_id,
        "--product-path", product_dir,
        "--extracted-metadata-path", args.metadata,
        "--source-file", args.infoplist,
        "--deployment-postprocessing",
        "--archive-ssu-assets",
    ])
    end = int(time.time()) + 1

    # The tool reports some failures only in its output.
    if returncode != 0 or _ERROR_RE.search(stdout) or _ERROR_RE.search(stderr):
      sys.stderr.write(stdout)
      sys.stderr.write(stderr)
      return returncode or 1

    for root, _, files in os.walk(product_dir):
      for filename in files:
        src = os.path.join(root, filename)
        relpath = os.path.relpath(src, product_dir)
        if relpath in staged_paths:
          continue
        dest = os.path.join(args.output, relpath)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        if filename == "nlu.lzfse":
          _normalize_nlu_archive(src, dest, start, end, work_dir)
        else:
          shutil.copyfile(src, dest)

  return 0


if __name__ == "__main__":
  sys.exit(main(sys.argv[1:]))
