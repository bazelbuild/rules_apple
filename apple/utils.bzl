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

"""Utility functions for working with strings, lists, and files in Skylark."""


XCRUNWRAPPER_LABEL = "@bazel_tools//tools/objc:xcrunwrapper"
"""The label for xcrunwrapper tool."""


DARWIN_EXECUTION_REQUIREMENTS = {"requires-darwin": ""}
"""Standard execution requirements to force building on Mac."""


def apple_action(ctx, **kw):
  """Creates an action that only runs on MacOS/Darwin.

  Call it similar to how you would call ctx.action:
    apple_action(ctx, outputs=[...], inputs=[...],...)
  """
  execution_requirements = kw.get("execution_requirements", {})
  execution_requirements["requires-darwin"] = ""

  no_sandbox = kw.pop("no_sandbox", False)
  if no_sandbox:
    execution_requirements["nosandbox"] = "1"

  kw["execution_requirements"] = execution_requirements
  ctx.action(**kw)


def basename(path):
  """Returns the basename (i.e., the file portion) of a path.

  Args:
    path: The path whose basename should be returned.
  Returns:
    The basename of the path, which includes the extension.
  """
  return path.rpartition('/')[-1]


def bash_array_string(iterable):
  """Creates a string from a sequence that can be used as a Bash array.

  Args:
    iterable: A sequence of elements.
  Returns:
    A string that represents the sequence as a Bash array; that is, parentheses
    containing the elements surrounded by double-quotes.
  """
  return '(' + ' '.join([bash_quote(i) for i in iterable]) + ')'


def bash_quote(s):
  """Returns a quoted representation of the given string for Bash.

  This function double-quotes the given string (in case it contains spaces or
  other special characters) and escapes any dollar signs or double-quotes that
  might already be inside it.

  Args:
    s: The string to quote.
  Returns:
    An escaped and quoted version of the string that can be passed to a command
    in a Bash script.
  """
  return '"' + s.replace('$', '\\$').replace('"', '\\"') + '"'


def dirname(path):
  """Returns the dirname (i.e., everything but the file portion) of a path.

  Args:
    path: The path whose dirname should be returned.
  Returns:
    The dirname of the path.
  """
  return path.rpartition('/')[0]


def full_label(l):
  """Converts a label to full format, e.g. //a/b/c -> //a/b/c:c.

  If the label is already in full format, it returns it as it is, otherwise
  appends the folder name as the target name.

  Args:
    l: The label to convert to full format.
  Returns:
    The label in full format, or the original input if it was already in full
    format.
  """
  if l.find(':') != -1:
    return l
  target_name = l.rpartition('/')[-1]
  return l + ':' + target_name


def group_files_by_directory(files, extensions, attr):
  """Groups files based on their containing directories.

  This function examines each file in |files| and looks for a containing
  directory with the given extension. It then returns a dictionary that maps
  the directory names to the files they contain.

  For example, if you had the following files:
    - some/path/foo.images/bar.png
    - some/path/foo.images/baz.png
    - some/path/quux.images/blorp.png

  Then passing the extension "images" to this function would return:
    {
        "some/path/foo.images": depset([
            "some/path/foo.images/bar.png",
            "some/path/foo.images/baz.png"
        ]),
        "some/path/quux.images": depset([
            "some/path/quux.images/blorp.png"
        ])
    }

  Note that |files| can be an iterable of either strings (paths) or File
  objects, and the returned dictionary preserves these input values. In other
  words, if it contains strings, then the sets in the dictionary will also
  contain strings (retaining the directory path as well). If the input elements
  are File objects, the returned dictionary values will also be sets of those
  File objects.

  If an input file does not have a containing directory with the given
  extension, the build will fail.

  Args:
    files: An iterable of File objects or strings representing paths.
    extensions: The list of extensions of the containing directories to return.
        The extensions should NOT include the leading dot.
    attr: The attribute to associate with the build failure if the list of
        files has an element that is not in a directory with the given
        extension.
  Returns:
    A dictionary whose keys are directories with the given extension and their
    values are the sets of files within them.
  """
  grouped_files = {}
  files_that_matched = depset()

  for extension in extensions:
    search_string = '.%s' % extension

    for f in files:
      if type(f) == type(''):
        path = f
      else:
        path = f.path

      # Make sure the matched string either has a '/' after it, or occurs at
      # the end of the string (this lets us match directories without requiring
      # a trailing slash but prevents matching something like '.xcdatamodeld'
      # when passing 'xcdatamodel'). The ordering of these checks is also
      # important, to ensure that we can handle cases that occur when working
      # with common Apple file structures, like passing 'xcdatamodel' and
      # correctly parsing paths matching 'foo.xcdatamodeld/bar.xcdatamodel/...'.
      after_index = -1
      search_len = len(search_string)
      index_with_slash = path.find(search_string + '/')
      if index_with_slash != -1:
        after_index = index_with_slash + search_len
      else:
        index_without_slash = path.find(search_string)
        after_index = index_without_slash + search_len
        # If the search string wasn't at the end of the string, it must have a
        # non-slash character after it (because we already checked the slash case
        # above), so eliminate it.
        if after_index != len(path):
          after_index = -1

      if after_index != -1:
        files_that_matched += [f]
        container = path[:after_index]
        if container in grouped_files:
          grouped_files[container] += [f]
        else:
          grouped_files[container] = depset([f])

  if len(files_that_matched) < len(files):
    unmatched_files = [f.path for f in files if f not in files_that_matched]
    formatted_files = '[\n  %s\n]' % ',\n  '.join(unmatched_files)
    fail('Expected only files inside directories named with the extensions ' +
         '%r, but found: %s' % (extensions, formatted_files), attr)

  return grouped_files


def intersperse(separator, iterable):
  """Inserts separator before each item in iterable.

  Args:
    separator: The value to insert before each item in iterable.
    iterable: The list into which to intersperse the separator.
  Returns:
    A new list with separator before each item in iterable.
  """
  result = []
  for x in iterable:
    result.append(separator)
    result.append(x)

  return result


def join_commands(cmds):
  """Joins a list of shell commands with ' && '.

  Args:
    cmds: The list of commands to join.
  Returns:
    A string with the given commands joined with ' && ', suitable for use in a
    shell script action.
  """
  return ' && '.join(cmds)


def label_scoped_path(label, path):
  """Return the path scoped to the label of a build target.

  Args:
    label: The label of a build target.
    path: The path that should be scoped to the label.
  Returns:
    The path after being scoped to the label.
  """
  return label.name + "/" + path.lstrip("/")


def merge_dictionaries(*dictionaries):
  """Merges at least two dictionaries.

  If any of the dictionaries share keys, the result will contain the value from
  the latest one in the list.

  Args:
    *dictionaries: The dictionaries that should be merged.
  Returns:
    The dictionary with all the attributes.
  """
  result = {}
  for d in dictionaries:
    for name, value in d.items():
      result[name] = value
  return result


def module_cache_path(genfiles_dir):
  """Returns the Clang module cache path to use for this rule."""
  return genfiles_dir.path + "/_objc_module_cache"


def optionally_prefixed_path(path, prefix):
  """Returns a path with an optional prefix.

  The prefix will be treated as an ancestor directory, so for example:

  ```
  optionally_prefixed_path("foo", None) == "foo"
  optionally_prefixed_path("foo", "bar") == "bar/foo"
  ```

  Args:
    path: The path.
    prefix: If None or empty, `path` will be returned; otherwise, the prefix
        will be treated as an ancestor directory and will be prepended to the
        path, with a slash.
  Returns:
    The path, optionally prepended with the prefix.
  """
  if prefix:
    return prefix + "/" + path
  return path


def relativize_path(path, ancestor):
  """Returns the portion of `path` that is relative to `ancestor`.

  This function does not normalize paths (for example, it does not handle
  segments that are ".." or "."), so it should not be used in contexts where
  those segments might exist. It will fail the build if `path` is not beneath
  `ancestor`.

  Args:
    path: The path to relativize.
    ancestor: The ancestor path against which to relativize.
  Returns:
    The portion of `path` that is relative to `ancestor`.
  """
  segments = [s for s in path.split('/') if s]
  ancestor_segments = [s for s in ancestor.split('/') if s]
  ancestor_length = len(ancestor_segments)

  if (path.startswith('/') != ancestor.startswith('/') or
      len(segments) < ancestor_length):
    fail('Path %r is not beneath %r' % (path, ancestor))

  for ancestor_segment, segment in zip(ancestor_segments, segments):
    if ancestor_segment != segment:
      fail('Path %r is not beneath %r' % (path, ancestor))

  length = len(segments) - ancestor_length
  result_segments = segments[-length:]
  return '/'.join(result_segments)


def remove_extension(filename):
  """Removes the extension from a file.

  The filename is returned unchanged if the basename does not have an
  extension.

  Args:
    filename: The filename whose extension should be removed.
  Returns:
    The filename with the extension removed, or the same filename if it did not
    have an extension.
  """
  last_dot = filename.rfind('.')
  if last_dot == -1:
    return filename
  last_slash = filename.rfind('/')
  if last_slash > last_dot:
    return filename
  return filename[:last_dot]


def replace_extension(filename, new_extension):
  """Replaces the extension of the file at the end of a path.

  If the file has no extension, the new extension is added to it.

  Args:
    filename: The filename whose extension should be replaced.
    new_extension: The new extension for the file. The new extension should
        begin with a dot if you want the new filename to have one.
  Returns:
    The path with the extension replaced (or added, if it did not have one).
  """
  return remove_extension(filename) + new_extension


def split_extension(filename):
  """Splits the name of a file from its extension and returns both.

  Args:
    filename: The filename that should be split.
  Returns:
    A tuple containing two values: the name of the file without the extension,
    and the extension (with the leading dot). If the file had no extension,
    then the second element of the tuple is the empty string.
  """
  last_dot = filename.rfind('.')
  if last_dot == -1:
    return (filename, '')
  last_slash = filename.rfind('/')
  if last_slash > last_dot:
    return (filename, '')
  return (filename[:last_dot], filename[last_dot:])


def xcrun_env(ctx):
  """Returns the environment dictionary necessary to use xcrunwrapper."""
  environment_supplier = get_environment_supplier(ctx)
  platform = ctx.fragments.apple.single_arch_platform
  action_env = (environment_supplier.target_apple_env(platform) +
                environment_supplier.apple_host_system_env())
  return action_env


def xcrun_action(ctx, **kw):
  """Creates an apple action that executes xcrunwrapper.

  args:
    ctx: The context of the rule that owns this action.

  This method takes the same keyword arguments as ctx.action, however you don't
  need to specify the executable.
  """
  env = kw.get("env", {})
  kw["env"] = env + xcrun_env(ctx)

  apple_action(ctx, executable=ctx.executable._xcrunwrapper, **kw)


def get_environment_supplier(ctx):
  """Returns the object that knows about Apple environment variables.

  Args:
    ctx: The context of the rule that owns this action.

  This is necessary because an incompatible change will make Bazel publish this
  information through an xcode_config rule instead of ctx.fragments.apple .
  """
  xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]
  if hasattr(xcode_config, 'apple_host_system_env'):
    return xcode_config
  else:
    return ctx.fragments.apple
