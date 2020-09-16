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
    "@build_bazel_rules_apple//apple/internal:bundling_support.bzl",
    "bundling_support",
)
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

def _archive(ctx):
    """Returns a file reference for this target's archive."""
    if is_experimental_tree_artifact_enabled(ctx):
        bundle_name_with_extension = (
            bundling_support.bundle_name(ctx) + bundling_support.bundle_extension(ctx)
        )
        return ctx.actions.declare_directory(bundle_name_with_extension)

    # TODO(kaipi): Look into removing this rule implicit output and just return it using
    # DefaultInfo.
    return ctx.outputs.archive

def _archive_for_embedding(ctx, rule_descriptor):
    """Returns a files reference for this target's archive, when embedded in another target."""
    if _has_different_embedding_archive(ctx, rule_descriptor):
        return ctx.actions.declare_file("%s.embedding.zip" % ctx.label.name)
    else:
        return _archive(ctx)

def _archive_root_path(ctx):
    """Returns the path to a directory reference for this target's archive root."""

    # TODO(b/65366691): Migrate this to an actual tree artifact.
    archive_root_name = paths.replace_extension(_archive(ctx).path, "_archive-root")
    return archive_root_name

def _binary(ctx):
    """Returns a file reference for the binary that will be packaged into this target's archive. """
    return intermediates.file(
        ctx.actions,
        ctx.label.name,
        bundling_support.bundle_name(ctx),
    )

def _executable(ctx):
    """Returns a file reference for the executable that would be invoked with `bazel run`."""
    return ctx.actions.declare_file(ctx.label.name)

def _infoplist(ctx):
    """Returns a file reference for this target's Info.plist file."""
    return intermediates.file(ctx.actions, ctx.label.name, "Info.plist")

def _has_different_embedding_archive(ctx, rule_descriptor):
    """Returns True if this target exposes a different archive when embedded in another target."""
    if is_experimental_tree_artifact_enabled(ctx):
        return False

    return rule_descriptor.bundle_locations.archive_relative != "" and rule_descriptor.expose_non_archive_relative_output

outputs = struct(
    archive = _archive,
    archive_for_embedding = _archive_for_embedding,
    archive_root_path = _archive_root_path,
    binary = _binary,
    executable = _executable,
    infoplist = _infoplist,
    has_different_embedding_archive = _has_different_embedding_archive,
)
