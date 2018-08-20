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

"""Partial implementation for framework import file processing."""

load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@build_bazel_rules_apple//common:path_utils.bzl",
    "path_utils",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:framework_import_aspect.bzl",
    "AppleFrameworkImportInfo",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:processor.bzl",
    "processor",
)

def _framework_import_partial_impl(ctx, targets):
    """Implementation for the framework import file processing partial."""
    _ignored = [ctx]

    transitive_sets = [
        x[AppleFrameworkImportInfo].framework_imports
        for x in targets
        if AppleFrameworkImportInfo in x
    ]

    all_files = depset(transitive = transitive_sets).to_list()

    bundle_files = []
    for file in all_files:
        framework_path = path_utils.farthest_directory_matching(file.short_path, "framework")
        framework_relative_path = paths.relativize(file.short_path, framework_path)

        parent_dir = paths.basename(framework_path)
        framework_relative_dir = paths.dirname(framework_relative_path).strip("/")
        if framework_relative_dir:
            parent_dir = paths.join(parent_dir, framework_relative_dir)

        bundle_files.append(
            (processor.location.framework, parent_dir, depset([file])),
        )

    return struct(bundle_files = bundle_files)

def framework_import_partial(targets):
    """Constructor for the framework import file processing partial.

    This partial propagates framework import file bundle locations. The files are collected through
    the framework_import_aspect aspect.

    Args:
        targets: The list of targets through which to collect the framework import files.

    Returns:
        A partial that returns the bundle location of the framework import files.
    """
    return partial.make(
        _framework_import_partial_impl,
        targets = targets,
    )
