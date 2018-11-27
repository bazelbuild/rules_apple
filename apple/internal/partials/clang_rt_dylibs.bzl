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

"""Partial implementation for Clang runtime libraries processing."""

load(
    "@build_bazel_rules_apple//apple/bundling:clang_support.bzl",
    "clang_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:intermediates.bzl",
    "intermediates",
)
load(
    "@build_bazel_rules_apple//apple/internal:processor.bzl",
    "processor",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)

def _clang_rt_dylibs_partial_impl(ctx, binary_artifact):
    """Implementation for the Clang runtime dylibs processing partial."""
    bundle_zips = []
    if clang_support.should_package_clang_runtime(ctx):
        clang_rt_zip = intermediates.file(
            ctx.actions,
            ctx.label.name,
            "clang_rt.zip",
        )
        clang_support.register_runtime_lib_actions(
            ctx,
            binary_artifact,
            clang_rt_zip,
        )

        bundle_zips.append(
            (processor.location.framework, None, depset([clang_rt_zip])),
        )

    return struct(
        bundle_zips = bundle_zips,
    )

def clang_rt_dylibs_partial(binary_artifact):
    """Constructor for the Clang runtime dylibs processing partial.

    Args:
      binary_artifact: The main binary artifact for this target.

    Returns:
      A partial that returns the bundle location of the Clang runtime dylibs, if there were any to
      bundle.
    """
    return partial.make(
        _clang_rt_dylibs_partial_impl,
        binary_artifact = binary_artifact,
    )
