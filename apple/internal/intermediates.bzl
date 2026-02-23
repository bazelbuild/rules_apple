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

def _intermediates_path_string(*, target_name, output_discriminator, no_intermediates = False):
    """Returns a preferred path string given a target name and an optional output discriminator."""
    return "{target_name}{intermediates}{output_discriminator}".format(
        target_name = target_name,
        intermediates = "-intermediates" if not no_intermediates else "",
        output_discriminator = "-%s" % output_discriminator if output_discriminator else "",
    )

def _directory(*, actions, target_name, output_discriminator, dir_name, no_intermediates = False):
    """Declares an intermediate directory with the given name.

    Args:
      actions: The actions object as returned by ctx.actions.
      target_name: The owning target name used to differentiate between different target
          intermediate files.
      output_discriminator: A string to differentiate between different target intermediate files
          or `None`.
      dir_name: Name of the directory to declare.
      no_intermediates: Whether to omit the "-intermediates" component of the path.

    Returns:
      A new File object that represents an intermediate directory.
    """
    intermediates_path = _intermediates_path_string(
        target_name = target_name,
        output_discriminator = output_discriminator,
        no_intermediates = no_intermediates,
    )
    return actions.declare_directory(
        paths.join(intermediates_path, dir_name),
    )

def _file(*, actions, target_name, output_discriminator, file_name, no_intermediates = False):
    """Declares an intermediate file with the given name.

    Args:
      actions: The actions object as returned by ctx.actions.
      target_name: The owning target name used to differentiate between different target
          intermediate files.
      output_discriminator: A string to differentiate between different target intermediate files
          or `None`.
      file_name: Name of the file to declare.
      no_intermediates: Whether to omit the "-intermediates" component of the path.

    Returns:
      A new File object that represents an intermediate file.
    """
    intermediates_path = _intermediates_path_string(
        target_name = target_name,
        output_discriminator = output_discriminator,
        no_intermediates = no_intermediates,
    )
    return actions.declare_file(
        paths.join(intermediates_path, file_name),
    )

intermediates = struct(
    directory = _directory,
    file = _file,
)
