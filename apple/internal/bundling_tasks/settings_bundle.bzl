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

"""Bundling Task implementation for processing the settings bundle for iOS apps."""

load(
    "@build_bazel_rules_apple//apple/internal:location_enum.bzl",
    "location_enum",
)
load(
    "@build_bazel_rules_apple//apple/internal:resources.bzl",
    "resources",
)
load(
    "@build_bazel_rules_apple//apple/internal/utils:bundle_paths.bzl",
    "bundle_paths",
)

visibility("@build_bazel_rules_apple//apple/...")

def _settings_bundle_bundling_task_impl(
        *,
        settings_bundle):
    """Implementation for the settings bundle processing bundling task."""

    if not settings_bundle:
        return struct()

    fields = resources.populated_resource_fields(settings_bundle)
    bundle_files = []
    for field in fields:
        for parent_dir, _, files in getattr(settings_bundle, field):
            bundle_name = bundle_paths.farthest_parent(parent_dir, "bundle")
            parent_dir = parent_dir.replace(bundle_name, "Settings.bundle")
            bundle_files.append((location_enum.resource, parent_dir, files))

    return struct(bundle_files = bundle_files)

def settings_bundle_bundling_task(
        *,
        settings_bundle = None):
    """Constructor for the settings bundles processing bundling task.

    This bundling task processes the settings bundle for Apple applications.

    Args:
        settings_bundle: An `AppleResourceInfo` provider from the resource bundle target that
            contains the files that make up the application's settings bundle, or `None`.

    Returns:
        A bundling task that returns the bundle location of the settings bundle, if any were
        configured.
    """
    return lambda *args, **kwargs: _settings_bundle_bundling_task_impl(
        settings_bundle = settings_bundle,
        *args,
        **kwargs
    )
