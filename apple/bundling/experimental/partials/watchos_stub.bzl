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

"""Partial implementation for placing the watchOS stub file in the archive."""

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

def _watchos_stub_partial_impl(ctx, binary_artifact):
    """Implementation for the watchOS stub processing partial."""

    # Create intermediate file with proper name for the binary.
    intermediate_file = intermediates.file(
        ctx.actions,
        ctx.label.name,
        "WK",
    )
    file_actions.symlink(ctx, binary_artifact, intermediate_file)

    return struct(
        bundle_files = [
            (processor.location.bundle, "_WatchKitStub", depset([intermediate_file])),
        ],
    )

def watchos_stub_partial(binary_artifact):
    """Constructor for the watchOS stub processing partial.

    This partial copies the WatchKit stub into the expected location inside the watchOS bundle.
    This partial only applies to the watchos_application rule.

    Args:
      binary_artifact: The stub binary to copy.

    Returns:
      A partial that returns the bundle location of the stub binary.
    """
    return partial.make(
        _watchos_stub_partial_impl,
        binary_artifact = binary_artifact,
    )
