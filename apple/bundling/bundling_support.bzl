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

"""Low-level bundling name helpers."""

load(
    "@build_bazel_rules_apple//apple/bundling:product_support.bzl",
    "product_support",
)


def _binary_file(ctx, src, dest, executable=False):
  """Returns a bundlable file whose destination is in the binary directory.

  Args:
    ctx: The Skylark context.
    src: The `File` artifact that should be bundled.
    dest: The path within the bundle's binary directory where the file should
        be placed.
    executable: True if the file should be made executable.
  Returns:
    A bundlable file struct (see `bundling_support.bundlable_file`).
  """
  return _bundlable_file(src, _path_in_binary_dir(ctx, dest), executable)


def _bundlable_file(src, dest, executable=False, contents_only=False):
  """Returns a value that represents a bundlable file or ZIP archive.

  A "bundlable file" is a struct that maps a file (`"src"`) to a path within a
  bundle (`"dest"`). This can be used with plain files, where `dest` denotes
  the path within the bundle where the file should be placed (including its
  filename, which allows it to be changed), or with ZIP archives, where `dest`
  denotes the location within the bundle where the ZIP's contents should be
  extracted.

  Args:
    src: The `File` artifact that should be bundled.
    dest: The path within the bundle where the file should be placed.
    executable: True if the file should be made executable.
    contents_only: If `src` is a directory and this is True, then the _contents_
        of the directory will be added at `dest` to the bundle; if this is
        False (the default) then the directory _itself_ will be added at `dest`
        to the bundle.
  Returns:
    A struct with `src`, `dest`, and `executable` fields representing the
    bundlable file.
  """
  return struct(
      src=src, dest=dest, executable=executable, contents_only=contents_only)


def _bundlable_file_sources(bundlable_files):
  """Returns the source files from the given collection of bundlable files.

  This is a convenience function that allows a set of bundlable files to be
  quickly turned into a list of files that can be passed to an action's inputs,
  for example.

  Args:
    bundlable_files: A list or set of bundlable file values (as returned by
        `bundling_support.bundlable_file`).
  Returns:
    A `depset` containing the `File` artifacts from the given bundlable files.
  """
  return depset([bf.src for bf in bundlable_files])


def _bundle_name(ctx):
  """Returns the name of the bundle.

  The name of the bundle is the value of the `bundle_name` attribute if it was
  given; if not, then the name of the target will be used instead.

  Args:
    ctx: The Skylark context.
  Returns:
    The bundle name.
  """
  bundle_name = getattr(ctx.attr, "bundle_name", None)
  if not bundle_name:
    bundle_name = ctx.label.name
  return bundle_name


def _bundle_extension(ctx):
  """Returns the bundle extension.

  Args:
    ctx: The Skylark context.

  Returns:
    The bundle extension.
  """
  ext = getattr(ctx.attr, "bundle_extension", "")
  if ext:
    # When the *user* specifies the bundle extension in a public attribute, we
    # do *not* require them to include the leading dot, so we add it here.
    ext = "." + ext
  else:
    product_type = product_support.product_type(ctx)
    product_type_descriptor = product_support.product_type_descriptor(
        product_type)
    if product_type_descriptor:
      ext = product_type_descriptor.bundle_extension

  return ext


def _bundle_name_with_extension(ctx):
  """Returns the name of the bundle with its extension.

  Args:
    ctx: The Skylark context.

  Returns:
    The bundle name with its extension.
  """
  return _bundle_name(ctx) + _bundle_extension(ctx)


def _contents_file(ctx, src, dest, executable=False):
  """Returns a bundlable file whose destination is in the contents directory.

  Args:
    ctx: The Skylark context.
    src: The `File` artifact that should be bundled.
    dest: The path within the bundle's contents directory where the file should
        be placed.
    executable: True if the file should be made executable.
  Returns:
    A bundlable file struct (see `bundling_support.bundlable_file`).
  """
  return _bundlable_file(src, _path_in_contents_dir(ctx, dest), executable)


def _embedded_bundle(path, target, verify_has_child_plist,
                     parent_bundle_id_reference=None):
  """Returns a value that represents an embedded bundle in another bundle.

  These values are used by the bundler to indicate how dependencies that are
  themselves bundles (such as extensions or frameworks) should be bundled in
  the application or target that depends on them.

  Args:
    path: The relative path within the depender's bundle where the given bundle
        should be located.
    target: The target representing the embedded bundle.
    verify_has_child_plist: If True, the bundler should verify the info.plist
        of this bundle against the parents. That means checking that the bundle
        identifier of the depender is a prefix of the bundle identifier of the
        embedded bundle; checking that the version numbers are the same, etc.
    parent_bundle_id_reference: A list of keys to make a keypath into this
        bundle's Info.plist where the parent's bundle_id should be found. The
        bundler will then ensure they match the parent's bundle_id.
  Returns:
    A struct with `path`, `target`, `verify_has_child_plist`, and
    `parent_bundle_id_reference` fields equal to the values given in the
    arguments.
  """
  if parent_bundle_id_reference != None and not verify_has_child_plist:
    fail("Internal Error: parent_bundle_id_reference without " +
         "verify_has_child_plist does not make sense.")
  return struct(
      path=path, target=target, verify_has_child_plist=verify_has_child_plist,
      parent_bundle_id_reference=parent_bundle_id_reference)


def _header_prefix(input_file):
  """Sets a file's bundle destination to a "Headers/" subdirectory.

  Args:
    input_file: The File to be bundled
  Returns:
    A bundlable file struct with the same File object, but whose path has been
    transformed to start with "Headers/".
  """
  new_path = "Headers/" + input_file.basename
  return _bundlable_file(input_file, new_path)


def _path_in_binary_dir(ctx, path):
  """Makes a path relative to where the bundle's binary is stored.

  On iOS/watchOS/tvOS, the binary is placed directly in the bundle's contents
  directory (which itself is actually the bundle root). On macOS, the binary is
  in a MacOS directory that is inside the bundle's Contents directory.

  Args:
    ctx: The Skylark context.
    path: The path to make relative to where the bundle's binary is stored.
  Returns:
    The path, made relative to where the bundle's binary is stored.
  """
  return _path_in_contents_dir(
      ctx, ctx.attr._bundle_binary_path_format % (path or ""))


def _path_in_contents_dir(ctx, path):
  """Makes a path relative to where the bundle's contents are stored.

  Contents include files such as:
  * A directory of resources (which itself might be flattened into contents)
  * A directory for the binary (which might be flattened)
  * Directories for Frameworks and PlugIns (extensions)
  * The bundle's Info.plist and PkgInfo
  * The code signature

  Args:
    ctx: The Skylark context.
    path: The path to make relative to where the bundle's contents are stored.
  Returns:
    The path, made relative to where the bundle's contents are stored.
  """
  return ctx.attr._bundle_contents_path_format % (path or "")


def _path_in_resources_dir(ctx, path):
  """Makes a path relative to where the bundle's resources are stored.

  On iOS/watchOS/tvOS, resources are placed directly in the bundle's contents
  directory (which itself is actually the bundle root). On macOS, resources are
  in a Resources directory that is inside the bundle's Contents directory.

  Args:
    ctx: The Skylark context.
    path: The path to make relative to where the bundle's resources are stored.
  Returns:
    The path, made relative to where the bundle's resources are stored.
  """
  return _path_in_contents_dir(
      ctx, ctx.attr._bundle_resources_path_format % (path or ""))


def _resource_file(ctx, src, dest, executable=False, contents_only=False):
  """Returns a bundlable file whose destination is in the resources directory.

  Args:
    ctx: The Skylark context.
    src: The `File` artifact that should be bundled.
    dest: The path within the bundle's resources directory where the file
        should be placed.
    executable: True if the file should be made executable.
    contents_only: If `src` is a directory and this is True, then the _contents_
        of the directory will be added at `dest` to the bundle; if this is
        False (the default) then the directory _itself_ will be added at `dest`
        to the bundle.
  Returns:
    A bundlable file struct (see `bundling_support.bundlable_file`).
  """
  return _bundlable_file(
      src, _path_in_resources_dir(ctx, dest), executable, contents_only)


def _validate_bundle_id(bundle_id):
  """Ensure the value is a valid bundle it or fail the build.

  Args:
    bundle_id: The string to check.
  """
  # Make sure the bundle id seems like a valid one. Apple's docs for
  # CFBundleIdentifier are all we have to go on, which are pretty minimal. The
  # only they they specifically document is the character set, so the other
  # two checks here are just added safety to catch likely errors by developers
  # setting things up.
  bundle_id_parts = bundle_id.split(".")
  for part in bundle_id_parts:
    if part == "":
      fail("Empty segment in bundle_id: \"%s\"" % bundle_id)
    if not part.isalnum():
      # Only non alpha numerics that are allowed are '.' and '-'. '.' was
      # handled by the split(), so just have to check for '-'.
      for ch in part:
        if ch != "-" and not ch.isalnum():
          fail("Invalid character(s) in bundle_id: \"%s\"" % bundle_id)


def _ensure_single_asset_type(
      files, extensions, attr,
      assets_catalog_suffix="xcassets",
      message=None):
  """Ensure the files are valid for the sub type of an asset bundle.

  TODO(b/77804841): The places calling this should go away and these types of
  checks should be done during the resource processing. Right now these checks
  are being wedged in at the attribute collection steps, and they then get
  combined into a single list of resources; the bundling then resplits them
  up in groups to process they by type. So the more validation/splitting done
  here the slower things get (as double work is done). The bug is to revisit
  all of this and instead pass through individual things in a structured way
  so they don't have to be resplit. That would allow the validation to be
  done while processing (in a single pass) instead.

  Args:
    files: An iterable of files to use.
    extensions: The extensions that should be used for the different asset
        types witin the catalog.
    attr: The attribute to associate with the build failure if the list of
        files has an element that is not in a directory with the given
        extension.
    assets_catalog_suffix: The suffix for the asset catalog directory.
    message: A custom error message to use instead, the list of found
        files that didn't match will be printed afterwards.
  """
  bad_paths = {}
  catalog_suffix = ".%s/" % assets_catalog_suffix

  ext_suffixes = [".%s/" % e for e in extensions]

  # Just check that the paths include the expected nesting. More complete
  # checks would likely be the number of outer directories with that suffix,
  # the number of inner ones, extra directories segments where not expected,
  # etc.
  for f in files:
    path = f.path
    catalog_offset = path.find(catalog_suffix)
    if catalog_offset == -1:
      bad_paths[path] = True
      continue
    not_found = True
    for ext_suffix in ext_suffixes:
      if path.find(ext_suffix, start=catalog_offset) != -1:
        not_found = False
        break  # No need to check other extensions
      # The only thing that shouldn't be within the sub folder is the root
      # Contents.json.
      if path[catalog_offset:] == (catalog_suffix + "Contents.json"):
        not_found = False

    if not_found:
      bad_paths[path] = True

  if len(bad_paths):
    if message == None:
      message = ("Expected only files inside directory named '*.%s' and " +
                 "then with directories with the extensions %r") % (
                assets_catalog_suffix, extensions)
    formatted_paths = '[\n  %s\n]' % ',\n  '.join(bad_paths.keys())
    fail('%s, but found the following: %s' % (message, formatted_paths), attr)


# Define the loadable module that lists the exported symbols in this file.
bundling_support = struct(
    binary_file=_binary_file,
    bundlable_file=_bundlable_file,
    bundlable_file_sources=_bundlable_file_sources,
    bundle_name=_bundle_name,
    bundle_extension=_bundle_extension,
    bundle_name_with_extension=_bundle_name_with_extension,
    contents_file=_contents_file,
    embedded_bundle=_embedded_bundle,
    ensure_single_asset_type=_ensure_single_asset_type,
    header_prefix=_header_prefix,
    path_in_binary_dir=_path_in_binary_dir,
    path_in_contents_dir=_path_in_contents_dir,
    path_in_resources_dir=_path_in_resources_dir,
    resource_file=_resource_file,
    validate_bundle_id=_validate_bundle_id,
)
