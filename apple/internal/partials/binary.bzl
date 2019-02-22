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

"""Partial implementation for binary processing for bundles."""

load(
    "@build_bazel_rules_apple//apple/internal:file_support.bzl",
    "file_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:outputs.bzl",
    "outputs",
)
load(
    "@build_bazel_rules_apple//apple/internal:processor.bzl",
    "processor",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)

def _binary_partial_impl(ctx, binary_artifact):
    """Implementation for the binary processing partial."""

    # Create intermediate file with proper name for the binary.
    output_binary = outputs.binary(ctx)
    file_support.symlink(ctx, binary_artifact, output_binary)

    return struct(
        bundle_files = [
            (processor.location.binary, None, depset([output_binary])),
        ],
    )

def binary_partial(binary_artifact):
    """Constructor for the binary processing partial.

    This partial propagates the bundle location for the main binary artifact for the target.

    Args:
      binary_artifact: The main binary artifact for this target.

    Returns:
      A partial that returns the bundle location of the binary artifact.
    """
    return partial.make(
        _binary_partial_impl,
        binary_artifact = binary_artifact,
    )
