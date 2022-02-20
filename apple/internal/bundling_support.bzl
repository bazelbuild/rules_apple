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

def _bundle_full_name(*, custom_bundle_extension, custom_bundle_name, label_name, rule_descriptor):
    """Returns a tuple containing information on the bundle file name.

    Args:
      custom_bundle_extension: A custom bundle extension. If one is not provided, the default
          bundle extension from the `rule_descriptor` will be used instead. Optional.
      custom_bundle_name: A custom bundle name. If one is not provided, the name of the target as
          given by `label_name` will be used instead. Optional.
      label_name: The name of the target.
      rule_descriptor: The rule descriptor for the given rule.

    Returns:
      A tuple representing the default bundle file name and extension for that rule context.
    """
    bundle_name = custom_bundle_name
    if not bundle_name:
        bundle_name = label_name

    bundle_extension = custom_bundle_extension
    if bundle_extension:
        # When the *user* specifies the bundle extension in a public attribute, we
        # do *not* require them to include the leading dot, so we add it here.
        bundle_extension = "." + bundle_extension
    else:
        bundle_extension = rule_descriptor.bundle_extension

    return (bundle_name, bundle_extension)

def _bundle_full_name_from_rule_ctx(ctx):
    """Returns a tuple containing information on the bundle file name based on the rule context."""
    return _bundle_full_name(
        custom_bundle_extension = getattr(ctx.attr, "bundle_extension", ""),
        custom_bundle_name = getattr(ctx.attr, "bundle_name", None),
        label_name = ctx.label.name,
        rule_descriptor = rule_support.rule_descriptor(ctx),
    )

def _executable_name(ctx):
    """Returns the executable name of the bundle.

    The executable of the bundle is the value of the `executable_name`
    attribute if it was given; if not, then the name of the `bundle_name`
    attribute if it was given; if not, then the name of the target will be used
    instead.

    Args:
      ctx: The Starlark context.

    Returns:
      The executable name.
    """
    executable_name = getattr(ctx.attr, "executable_name", None)
    if not executable_name:
        (executable_name, _) = _bundle_full_name_from_rule_ctx(ctx)
    return executable_name

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
    bundle_full_name = _bundle_full_name,
    bundle_full_name_from_rule_ctx = _bundle_full_name_from_rule_ctx,
    ensure_path_format = _ensure_path_format,
    ensure_single_xcassets_type = _ensure_single_xcassets_type,
    executable_name = _executable_name,
)
