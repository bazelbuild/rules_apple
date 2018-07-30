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

"""Partial implementation for embedding provisioning profiles."""

load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@build_bazel_rules_apple//apple/bundling:file_actions.bzl",
    "file_actions",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:processor.bzl",
    "processor",
)

def _provisioning_profile_partial_impl(ctx, profile_artifact, extension):
    """Implementation for the provisioning profile partial."""
    # Create intermediate file with proper name for the binary.
    intermediate_file = intermediates.file(
        ctx.actions,
        ctx.label.name,
        "embedded.%s" % extension,
    )
    file_actions.symlink(ctx, profile_artifact, intermediate_file)

    return struct(
        bundle_files = [
            (processor.location.resource, None, depset([intermediate_file])),
        ],
    )

def provisioning_profile_partial(profile_artifact, extension = "mobileprovision"):
    """Constructor for the provisioning profile partial.

    This partial propagates the bundle location for the embedded provisioning profile artifact for
    the target.

    Args:
      profile_artifact: The provisioning profile to embed for this target.
      extension: The embedded provisioning profile extension.

    Returns:
      A partial that returns the bundle location of the provisioning profile artifact.
    """
    return partial.make(
        _provisioning_profile_partial_impl,
        profile_artifact = profile_artifact,
        extension = extension,
    )
