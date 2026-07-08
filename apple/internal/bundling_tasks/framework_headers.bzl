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

"""Bundling Task implementation for embedding provisioning profiles."""

load(
    "@build_bazel_rules_apple//apple/internal:location_enum.bzl",
    "location_enum",
)

visibility("@build_bazel_rules_apple//apple/...")

def _framework_headers_bundling_task_impl(*, hdrs):
    """Implementation for the framework headers bundling task."""
    return struct(
        bundle_files = [
            (location_enum.bundle, "Headers", depset(hdrs)),
        ],
    )

def framework_headers_bundling_task(*, hdrs):
    """Constructor for the framework headers bundling task.

    This bundling task bundles the headers for dynamic frameworks.

    Args:
      hdrs: The list of headers to bundle.

    Returns:
      A bundling task that returns the bundle location of the framework header artifacts.
    """
    return lambda *args, **kwargs: _framework_headers_bundling_task_impl(
        hdrs = hdrs,
        *args,
        **kwargs
    )
