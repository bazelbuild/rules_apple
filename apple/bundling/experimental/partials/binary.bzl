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
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@build_bazel_rules_apple//apple/bundling:bundling_support.bzl",
    "bundling_support",
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

def _binary_partial_impl(ctx, provider_key):
    """Implementation for the binary processing partial."""
    binary_provider = ctx.attr.deps[0][provider_key]
    binary_file = binary_provider.binary

    # Create intermediate file with proper name for the binary.
    intermediate_file = intermediates.file(
        ctx.actions,
        ctx.label.name,
        bundling_support.bundle_name(ctx),
    )
    file_actions.symlink(ctx, binary_file, intermediate_file)

    return struct(
        bundle_files = [
            (processor.location.binary, None, depset([intermediate_file])),
        ],
        providers = [binary_provider],
    )

def binary_partial(provider_key):
    """Constructor for the binary processing partial.

    This partial propagates the binary file to be bundled, as well as the binary
    provider coming from the underlying apple_binary target. Because apple_binary
    provides a different provider depending on the type of binary being created,
    this partial requires the provider key under which to find the provider to
    propagate as well as the binary artifact to bundle.

    Args:
      provider_key: The provider key under which to find the binary provider
        containing the binary artifact.

    Returns:
      A partial that returns the bundle location of the binary and the binary
      provider.
    """
    return partial.make(
        _binary_partial_impl,
        provider_key = provider_key,
    )
