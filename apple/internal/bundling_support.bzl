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
    "@build_bazel_rules_apple//apple/internal:rule_support.bzl",
    "rule_support",
)

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
        rule_descriptor = rule_support.rule_descriptor(ctx)
        ext = rule_descriptor.bundle_extension

    return ext

def _bundle_name_with_extension(ctx):
    """Returns the name of the bundle with its extension.

    Args:
      ctx: The Skylark context.

    Returns:
      The bundle name with its extension.
    """
    return _bundle_name(ctx) + _bundle_extension(ctx)

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
            for i in range(len(part)):
                ch = part[i]
                if ch != "-" and not ch.isalnum():
                    fail("Invalid character(s) in bundle_id: \"%s\"" % bundle_id)

def _ensure_single_xcassets_type(attr, files, extension, message = None):
    """Helper for when an xcassets catalog should have a single sub type.

    Args:
      attr: The attribute to associate with the build failure if the list of
          files has an element that is not in a directory with the given
          extension.
      files: An iterable of files to use.
      extension: The extension that should be used for the different asset
          type witin the catalog.
      message: A custom error message to use, the list of found files that
          didn't match will be printed afterwards.
    """
    if not message:
        message = ("Expected the xcassets directory to only contain files " +
                   "are in sub-directories with the extension %s") % extension
    _ensure_path_format(attr, files, [["xcassets", extension]], message = message)

def _path_is_under_fragments(path, path_fragments):
    """Helper for _ensure_asset_types().

    Checks that the given path is under the given set of path fragments.

    Args:
      path: String of the path to check.
      path_fragments: List of string to check for in the path (in order).

    Returns:
      True/False for if the path includes the ordered fragments.
    """
    start_offset = 0
    for suffix in path_fragments:
        offset = path.find(suffix, start_offset)
        if offset != -1:
            start_offset = offset + len(suffix)
            continue

        if start_offset and path[start_offset:] == "Contents.json":
            # After the first segment was found, always accept a Contents.json file.
            return True

        return False

    return True

def _ensure_path_format(attr, files, path_fragments_list, message = None):
    """Ensure the files match the required path fragments.

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
      attr: The attribute to associate with the build failure if the list of
          files has an element that is not in a directory with the given
          extension.
      files: An iterable of files to use.
      path_fragments_list: A list of lists, each inner lists is a sequence of
          extensions that must be on the paths passed in (to ensure proper
          nesting).
      message: A custom error message to use, the list of found files that
          didn't match will be printed afterwards.
    """

    formatted_path_fragments_list = []
    for x in path_fragments_list:
        formatted_path_fragments_list.append([".%s/" % y for y in x])

    # Just check that the paths include the expected nesting. More complete
    # checks would likely be the number of outer directories with that suffix,
    # the number of inner ones, extra directories segments where not expected,
    # etc.
    bad_paths = {}
    for f in files:
        path = f.path

        was_good = False
        for path_fragments in formatted_path_fragments_list:
            if _path_is_under_fragments(path, path_fragments):
                was_good = True
                break  # No need to check other fragments

        if not was_good:
            bad_paths[path] = None

    if len(bad_paths):
        if not message:
            as_paths = [
                ("*" + "*".join(x) + "...")
                for x in formatted_path_fragments_list
            ]
            message = "Expected only files inside directories named '*.%s'" % (
                ", ".join(as_paths)
            )
        formatted_paths = "[\n  %s\n]" % ",\n  ".join(bad_paths.keys())
        fail("%s, but found the following: %s" % (message, formatted_paths), attr)

# Define the loadable module that lists the exported symbols in this file.
bundling_support = struct(
    bundle_name = _bundle_name,
    bundle_extension = _bundle_extension,
    bundle_name_with_extension = _bundle_name_with_extension,
    ensure_path_format = _ensure_path_format,
    ensure_single_xcassets_type = _ensure_single_xcassets_type,
    validate_bundle_id = _validate_bundle_id,
)
