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

load("//apple:utils.bzl",
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


def _lproj_rooted_path_or_basename(f):
  """Returns an `.lproj`-rooted path for the given file if possible.

  If the file is nested in a `*.lproj` directory, then the `.lproj`-rooted path
  to the file will be returned; for example, "fr.lproj/foo.strings". If the
  file is not in a `*.lproj` directory, only the basename of the file is
  returned.

  Args:
    f: The `File` whose `.lproj`-rooted name or basename should be returned.
  Returns:
    The `.lproj`-rooted name or basename.
  """
  if f.dirname.endswith(".lproj"):
    filename = f.basename
    dirname = basename(f.dirname)
    return dirname + "/" + filename

  return f.basename


def _owner_relative_path(f):
  """Returns the portion of `f`'s path relative to its owner.

  Args:
    f: A file.
  Returns:
    The owner-relative path to the file.
  """
  return relativize_path(f.short_path, f.owner.package)


def _resource_info(bundle_id,
                   bundle_dir="",
                   path_transform=_lproj_rooted_path_or_basename,
                   swift_module=None):
  """Returns an object to be passed to `resource_actions.process_resources`.

  Args:
    bundle_id: The id of the bundle to which the resources belong. Required.
    bundle_dir: The bundle directory that should be prefixed to any bundlable
        files returned by the resource processing action.
    path_transform: If provided, a function that will be called on each input
        file to obtain its relative output path in the bundle. The default
        behavior is to only preserve .lproj folders but otherwise flatten the
        directory structure and retain only the basename.
    swift_module: The name of the Swift module to which the resources belong,
        if any.
  Returns:
    A struct that should be passed to `resource_actions.process_resources`.
  """
  return struct(
      bundle_dir=bundle_dir,
      bundle_id=bundle_id,
      path_transform=path_transform,
      swift_module=swift_module
  )


# Define the loadable module that lists the exported symbols in this file.
resource_support = struct(
    bundle_relative_path=_bundle_relative_path,
    lproj_rooted_path_or_basename=_lproj_rooted_path_or_basename,
    owner_relative_path=_owner_relative_path,
    resource_info=_resource_info,
)
