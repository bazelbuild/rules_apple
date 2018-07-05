# Copyright 2018 The Bazel Authors. All rights reserved.
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

"""Intermediate file declaration support."""

load("@bazel_skylib//lib:paths.bzl", "paths")

def _directory(actions, target_name, dir_name):
    """Declares an intermediate directory with the given name.

    Args:
      actions: The actions object as returned by ctx.actions.
      target_name: The owning target name to differentiate between different
        target intermediate files.
      dir_name: Name of the directory to declare.

    Returns:
      A new File object that represents an intermediate directory.
    """
    return actions.declare_directory(
        paths.join("%s-intermediates" % target_name, dir_name),
    )

def _file(actions, target_name, file_name):
    """Declares an intermediate file with the given name.

    Args:
      actions: The actions object as returned by ctx.actions.
      target_name: The owning target name to differentiate between different
        target intermediate files.
      file_name: Name of the file to declare.

    Returns:
      A new File object that represents an intermediate file.
    """
    return actions.declare_file(
        paths.join("%s-intermediates" % target_name, file_name),
    )

intermediates = struct(
    directory = _directory,
    file = _file,
)
