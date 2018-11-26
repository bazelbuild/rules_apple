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
        execution_requirements["no-sandbox"] = "1"

    kw["execution_requirements"] = execution_requirements
    ctx.action(**kw)

def apple_actions_run(ctx_actions, **kw):
    """Creates an actions.run() that only runs on MacOS/Darwin.

    Call it similar to how you would call ctx.actions.run:
      apple_actions_run(ctx.actions, outputs=[...], inputs=[...],...)

    Args:
      ctx_actions: The ctx.actions object to use.
      **kw: Additional arguments that are passed directly to `actions.run`.
    """
    execution_requirements = kw.get("execution_requirements", {})
    execution_requirements["requires-darwin"] = ""

    no_sandbox = kw.pop("no_sandbox", False)
    if no_sandbox:
        execution_requirements["no-sandbox"] = "1"

    kw["execution_requirements"] = execution_requirements
    ctx_actions.run(**kw)

def apple_actions_runshell(ctx_actions, **kw):
    """Creates an actions.run_shell() that only runs on MacOS/Darwin.

    Call it similar to how you would call ctx.actions.run_shell:
      apple_actions_runshell(ctx.actions, outputs=[...], inputs=[...],...)

    Args:
      ctx_actions: The ctx.actions object to use.
      **kw: Additional arguments that are passed directly to
        `actions.run_shell`.
    """
    execution_requirements = kw.get("execution_requirements", {})
    execution_requirements["requires-darwin"] = ""

    no_sandbox = kw.pop("no_sandbox", False)
    if no_sandbox:
        execution_requirements["no-sandbox"] = "1"

    kw["execution_requirements"] = execution_requirements
    ctx_actions.run_shell(**kw)

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
    if l.find(":") != -1:
        return l
    target_name = l.rpartition("/")[-1]
    return l + ":" + target_name

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

    If an input file does not have a containing directory with the given
    extension, the build will fail.

    Args:
      files: An iterable of File objects.
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
    paths_not_matched = {}

    ext_info = [(".%s" % e, len(e) + 1) for e in extensions]

    for f in files:
        path = f.path

        not_matched = True
        for search_string, search_string_len in ext_info:
            # Make sure the matched string either has a '/' after it, or occurs at
            # the end of the string (this lets us match directories without requiring
            # a trailing slash but prevents matching something like '.xcdatamodeld'
            # when passing 'xcdatamodel'). The ordering of these checks is also
            # important, to ensure that we can handle cases that occur when working
            # with common Apple file structures, like passing 'xcdatamodel' and
            # correctly parsing paths matching 'foo.xcdatamodeld/bar.xcdatamodel/...'.
            after_index = -1
            index_with_slash = path.find(search_string + "/")
            if index_with_slash != -1:
                after_index = index_with_slash + search_string_len
            else:
                index_without_slash = path.find(search_string)
                after_index = index_without_slash + search_string_len

                # If the search string wasn't at the end of the string, it must have a
                # non-slash character after it (because we already checked the slash case
                # above), so eliminate it.
                if after_index != len(path):
                    after_index = -1

            if after_index != -1:
                not_matched = False
                container = path[:after_index]
                if container in grouped_files:
                    grouped_files[container].append(f)
                else:
                    grouped_files[container] = [f]

                # No need to check other extensions
                break

        if not_matched:
            paths_not_matched[path] = True

    if len(paths_not_matched):
        formatted_files = "[\n  %s\n]" % ",\n  ".join(paths_not_matched.keys())
        fail("Expected only files inside directories named with the extensions " +
             "%r, but found: %s" % (extensions, formatted_files), attr)

    return {k: depset(v) for k, v in grouped_files.items()}

def is_xcode_at_least_version(xcode_config, desired_version):
    """Returns True if we are building with at least the given Xcode version.

    Args:
        xcode_config: the `apple_common.XcodeVersionConfig` provider.
        desired_version: The minimum desired Xcode version, as a dotted version string.

    Returns:
        True if the current target is being built with a version of Xcode at least as high as the
        given version.
    """
    current_version = xcode_config.xcode_version()
    if not current_version:
        fail("Could not determine Xcode version at all. This likely means Xcode isn't " +
             "available; if you think this is a mistake, please file an issue.")

    desired_version_value = apple_common.dotted_version(desired_version)
    return current_version >= desired_version_value

def join_commands(cmds):
    """Joins a list of shell commands with ' && '.

    Args:
      cmds: The list of commands to join.
    Returns:
      A string with the given commands joined with ' && ', suitable for use in a
      shell script action.
    """
    return " && ".join(cmds)

def label_scoped_path(label, path):
    """Return the path scoped to the label of a build target.

    Args:
      label: The label of a build target.
      path: The path that should be scoped to the label.
    Returns:
      The path after being scoped to the label.
    """
    return label.name + "/" + path.lstrip("/")

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

def xcrun_env(ctx):
    """Returns the environment dictionary necessary to use xcrunwrapper."""
    xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]
    platform = ctx.fragments.apple.single_arch_platform
    action_env = apple_common.target_apple_env(xcode_config, platform)
    action_env.update(apple_common.apple_host_system_env(xcode_config))
    return action_env

def xcrun_action(ctx, **kw):
    """Creates an apple action that executes xcrunwrapper.

    args:
      ctx: The context of the rule that owns this action.

    This method takes the same keyword arguments as ctx.action, however you don't
    need to specify the executable.
    """
    kw["env"] = dict(kw.get("env", {}))
    kw["env"].update(xcrun_env(ctx))

    apple_action(ctx, executable = ctx.executable._xcrunwrapper, **kw)
