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

"""File references to important output files from the rule.

These file references can be used across the bundling logic, but there must be only 1 action
registered to generate these files.
"""

load(
    "@build_bazel_rules_apple//apple/internal:experimental.bzl",
    "is_experimental_tree_artifact_enabled",
)
load(
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

def _archive(
        *,
        actions,
        bundle_extension,
        bundle_name,
        platform_prerequisites,
        predeclared_outputs):
    """Returns a file reference for this target's archive."""
    bundle_name_with_extension = bundle_name + bundle_extension

    tree_artifact_enabled = is_experimental_tree_artifact_enabled(
        config_vars = platform_prerequisites.config_vars,
    )
    if tree_artifact_enabled:
        return actions.declare_directory(bundle_name_with_extension)
    return predeclared_outputs.archive

def _archive_for_embedding(
        *,
        actions,
        bundle_name,
        bundle_extension,
        label_name,
        platform_prerequisites,
        predeclared_outputs,
        rule_descriptor):
    """Returns a files reference for this target's archive, when embedded in another target."""
    has_different_embedding_archive = _has_different_embedding_archive(
        platform_prerequisites = platform_prerequisites,
        rule_descriptor = rule_descriptor,
    )

    if has_different_embedding_archive:
        return actions.declare_file("%s.embedding.zip" % label_name)
    else:
        return _archive(
            actions = actions,
            bundle_extension = bundle_extension,
            bundle_name = bundle_name,
            platform_prerequisites = platform_prerequisites,
            predeclared_outputs = predeclared_outputs,
        )

def _binary(*, actions, bundle_name, label_name):
    """Returns a file reference for the binary that will be packaged into this target's archive. """
    return intermediates.file(actions, label_name, bundle_name)

def _executable(*, actions, label_name):
    """Returns a file reference for the executable that would be invoked with `bazel run`."""
    return actions.declare_file(label_name)

def _infoplist(*, actions, label_name):
    """Returns a file reference for this target's Info.plist file."""
    return intermediates.file(actions, label_name, "Info.plist")

def _has_different_embedding_archive(*, platform_prerequisites, rule_descriptor):
    """Returns True if this target exposes a different archive when embedded in another target."""
    tree_artifact_enabled = is_experimental_tree_artifact_enabled(
        config_vars = platform_prerequisites.config_vars,
    )
    if tree_artifact_enabled:
        return False
    return rule_descriptor.bundle_locations.archive_relative != "" and rule_descriptor.expose_non_archive_relative_output

def _root_path_from_archive(*, archive):
    """Given an archive, returns a path to a directory reference for this target's archive root."""
    return paths.replace_extension(archive.path, "_archive-root")

outputs = struct(
    archive = _archive,
    archive_for_embedding = _archive_for_embedding,
    binary = _binary,
    executable = _executable,
    infoplist = _infoplist,
    root_path_from_archive = _root_path_from_archive,
    has_different_embedding_archive = _has_different_embedding_archive,
)
