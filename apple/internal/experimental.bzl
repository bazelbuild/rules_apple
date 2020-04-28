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

"""Temporary file to centralize configuration of the experimental bundling logic."""

load(
    "@build_bazel_rules_apple//apple/internal/utils:defines.bzl",
    "defines",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

def is_experimental_tree_artifact_enabled(*, config_vars):
    """Returns whether tree artifact outputs experiment is enabled."""

    # TODO(b/161370390): Remove ctx from all invocations of defines.bool_value.
    return defines.bool_value(
        ctx = None,
        config_vars = config_vars,
        define_name = "apple.experimental.tree_artifact_outputs",
        default = False,
    )

def is_untracked_bundletool_output_enabled(*, config_vars):
    """Returns whether bundletool output is places in an untracked location."""
    if not is_experimental_tree_artifact_enabled(config_vars = config_vars):
        return False

    # TODO(b/161370390): Remove ctx from all invocations of defines.bool_value.
    return defines.bool_value(
        ctx = None,
        config_vars = config_vars,
        define_name = "apple.untracked_bundletool_output",
        default = False,
    )

def bundletool_output_file_path(*, config_vars, original_path):
    """Returns a potentially modified bundletool output file path."""
    if is_untracked_bundletool_output_enabled(config_vars = config_vars):
        # Write bundle tool output to a different location
        # This speeds up incremental compilation since Bazel doesn't have to
        # collect information on all of the output files
        dirname = paths.dirname(original_path)
        basename = paths.basename(original_path)
        return "{}/bundletool/{}".format(dirname, basename)
    else:
        return original_path
