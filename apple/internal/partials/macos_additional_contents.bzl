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

"""Partial implementation for processing additional contents for macOS apps."""

load(
    "@build_bazel_rules_apple//apple/internal:processor.bzl",
    "processor",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBinaryInfo",
    "AppleBundleInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:bundle_paths.bzl",
    "bundle_paths",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

def _macos_additional_contents_partial_impl(ctx):
    """Implementation for the settings bundle processing partial."""

    if not ctx.attr.additional_contents:
        return struct()

    bundle_files = []
    bundle_zips = []
    for target, subdirectory in ctx.attr.additional_contents.items():
        if AppleBundleInfo in target:
            bundle_zips.append(
                (
                    processor.location.content,
                    subdirectory,
                    depset([target[AppleBundleInfo].archive]),
                ),
            )
        elif AppleBinaryInfo in target:
            bundle_files.append(
                (
                    processor.location.content,
                    subdirectory,
                    depset([target[AppleBinaryInfo].binary]),
                ),
            )
        else:
            for file in target.files.to_list():
                package_relative = bundle_paths.owner_relative_path(file)
                nested_path = paths.dirname(package_relative).rstrip("/")
                bundle_files.append(
                    (
                        processor.location.content,
                        paths.join(subdirectory, nested_path),
                        depset([file]),
                    ),
                )

    return struct(
        bundle_files = bundle_files,
        bundle_zips = bundle_zips,
    )

def macos_additional_contents_partial():
    """Constructor for the macOS additional contents processing partial.

    This partial processes additional contents for macOS applications.

    Returns:
        A partial that returns the bundle location of the additional contents bundle, if any were
        configured.
    """
    return partial.make(
        _macos_additional_contents_partial_impl,
    )
