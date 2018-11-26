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

"""Partial implementation for bundling header and modulemaps for static frameworks."""

load(
    "@build_bazel_rules_apple//apple/bundling:bundling_support.bzl",
    "bundling_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:framework_support.bzl",
    "framework_support",
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

def _static_framework_header_modulemap_partial_impl(ctx, hdrs, binary_objc_provider):
    """Implementation for the static framework headers and modulemaps partial."""
    bundle_name = bundling_support.bundle_name(ctx)

    bundle_files = []

    umbrella_header_name = None
    if hdrs:
        umbrella_header_name = "{}.h".format(bundle_name)
        umbrella_header_file = intermediates.file(ctx.actions, ctx.label.name, umbrella_header_name)
        framework_support.create_umbrella_header(
            ctx.actions,
            umbrella_header_file,
            sorted(hdrs),
        )

        bundle_files.append(
            (processor.location.bundle, "Headers", depset(hdrs + [umbrella_header_file])),
        )
    else:
        umbrella_header_name = None

    sdk_dylibs = getattr(binary_objc_provider, "sdk_dylib", None)
    sdk_frameworks = getattr(binary_objc_provider, "sdk_framework", None)

    # Create a module map if there is a need for one (that is, if there are
    # headers or if there are dylibs/frameworks that the target depends on).
    if any([sdk_dylibs, sdk_dylibs, umbrella_header_name]):
        modulemap_file = intermediates.file(ctx.actions, ctx.label.name, "module.modulemap")
        framework_support.create_modulemap(
            ctx.actions,
            modulemap_file,
            bundle_name,
            umbrella_header_name,
            sorted(sdk_dylibs and sdk_dylibs.to_list()),
            sorted(sdk_frameworks and sdk_frameworks.to_list()),
        )
        bundle_files.append((processor.location.bundle, "Modules", depset([modulemap_file])))

    return struct(
        bundle_files = bundle_files,
    )

def static_framework_header_modulemap_partial(hdrs, binary_objc_provider):
    """Constructor for the static framework headers and modulemaps partial.

    This partial bundles the headers and modulemaps for static frameworks.

    Args:
      hdrs: The list of headers to bundle.
      binary_objc_provider: The ObjC provider for the binary target.

    Returns:
      A partial that returns the bundle location of the static framework header and modulemap
      artifacts.
    """
    return partial.make(
        _static_framework_header_modulemap_partial_impl,
        hdrs = hdrs,
        binary_objc_provider = binary_objc_provider,
    )
