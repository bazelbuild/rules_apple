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

"""Support functions used when processing resources in Apple bundles."""

load("@build_bazel_rules_apple//apple:utils.bzl",
     "basename",
     "relativize_path")


def _bundle_relative_path(f):
  """Returns the portion of `f`'s path relative to its containing `.bundle`.

  This function fails if `f` does not have an ancestor directory named with the
  `.bundle` extension.

  Args:
    f: A file.
  Returns:
    The `.bundle`-relative path to the file.
  """
  return relativize_path(
      f.short_path, _farthest_directory_matching(f.short_path, "bundle"))


def _farthest_directory_matching(path, extension):
  """Returns the part of a path with the given extension closest to the root.

  For example, if `path` is `"foo/bar.bundle/baz.bundle"`, passing `".bundle"`
  as the extension will return `"foo/bar.bundle"`.

  Args:
    path: The path.
    extension: The extension of the directory to find.
  Returns:
    The portion of the path that ends in the given extension that is closest
    to the root of the path.
  """
  prefix, ext, _ = path.partition("." + extension)
  if ext:
    return prefix + ext

  fail("Expected path %r to contain %r, but it did not" % (
      path, "." + extension))


def _owner_relative_path(f):
  """Returns the portion of `f`'s path relative to its owner.

  Args:
    f: A file.
  Returns:
    The owner-relative path to the file.
  """
  return relativize_path(f.short_path, f.owner.package)


# Define the loadable module that lists the exported symbols in this file.
resource_support = struct(
    bundle_relative_path=_bundle_relative_path,
    owner_relative_path=_owner_relative_path,
)
