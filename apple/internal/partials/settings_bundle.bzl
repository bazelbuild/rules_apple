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

"""Partial implementation for processing the settings bundle for iOS apps."""

load(
    "@build_bazel_rules_apple//apple/internal/partials/support:resources_support.bzl",
    "resources_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:processor.bzl",
    "processor",
)
load(
    "@build_bazel_rules_apple//apple/internal:resources.bzl",
    "resources",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleResourceInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:bundle_paths.bzl",
    "bundle_paths",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)

def _settings_bundle_partial_impl(ctx):
    """Implementation for the settings bundle processing partial."""

    if not ctx.attr.settings_bundle:
        return struct()

    provider = ctx.attr.settings_bundle[AppleResourceInfo]
    fields = resources.populated_resource_fields(provider)
    bundle_files = []
    for field in fields:
        for parent_dir, _, files in getattr(provider, field):
            bundle_name = bundle_paths.farthest_parent(parent_dir, "bundle")
            parent_dir = parent_dir.replace(bundle_name, "Settings.bundle")

            if field in ["plists", "strings"]:
                compiled_files = resources_support.plists_and_strings(
                    ctx,
                    parent_dir,
                    files,
                    force_binary = True,
                )
                bundle_files.extend(compiled_files.files)
            else:
                bundle_files.append((processor.location.resource, parent_dir, files))

    return struct(bundle_files = bundle_files)

def settings_bundle_partial():
    """Constructor for the settings bundles processing partial.

    This partial processes the settings bundle for iOS applications.

    Returns:
        A partial that returns the bundle location of the settings bundle, if any were configured.
    """
    return partial.make(
        _settings_bundle_partial_impl,
    )
