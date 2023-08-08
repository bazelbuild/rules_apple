# Copyright 2021 The Bazel Authors. All rights reserved.
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

"""Partial implementation for bundling header and modulemaps for external-facing frameworks."""

load(
    "@build_bazel_rules_apple//apple/internal:clang_modulemap_support.bzl",
    "clang_modulemap_support",
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

visibility("//apple/...")

def _framework_header_modulemap_partial_impl(
        *,
        actions,
        bundle_name,
        framework_modulemap,
        hdrs,
        label_name,
        output_discriminator,
        sdk_dylibs,
        sdk_frameworks):
    """Implementation for the sdk framework headers and modulemaps partial."""
    bundle_files = []

    header_files, umbrella_header_filename = clang_modulemap_support.process_headers(
        actions = actions,
        label_name = label_name,
        module_name = bundle_name,
        output_discriminator = output_discriminator,
        public_hdrs = hdrs,
    )
    if header_files:
        bundle_files.append(
            (processor.location.bundle, "Headers", depset(header_files)),
        )

    # Create a module map if there is a need for one (that is, if there are headers or if there are
    # dylibs/frameworks that the target depends on).
    if any([sdk_dylibs, sdk_frameworks, umbrella_header_filename]):
        modulemap_file = intermediates.file(
            actions = actions,
            target_name = label_name,
            output_discriminator = output_discriminator,
            file_name = "module.modulemap",
        )
        modulemap_content = clang_modulemap_support.modulemap_header_interface_contents(
            framework_modulemap = framework_modulemap,
            module_name = bundle_name,
            sdk_dylibs = sorted(sdk_dylibs.to_list() if sdk_dylibs else []),
            sdk_frameworks = sorted(sdk_frameworks.to_list() if sdk_frameworks else []),
            umbrella_header_filename = umbrella_header_filename,
        )
        actions.write(
            output = modulemap_file,
            content = modulemap_content,
        )

        bundle_files.append((processor.location.bundle, "Modules", depset([modulemap_file])))

    return struct(
        bundle_files = bundle_files,
    )

def framework_header_modulemap_partial(
        *,
        actions,
        bundle_name,
        framework_modulemap = True,
        hdrs,
        label_name,
        output_discriminator = None,
        sdk_dylibs = [],
        sdk_frameworks = []):
    """Constructor for the framework headers and modulemaps partial.

    This partial bundles the headers and modulemaps for sdk frameworks.

    Args:
      actions: The actions provider from `ctx.actions`.
      bundle_name: The name of the output bundle.
      framework_modulemap: Boolean to indicate if the generated modulemap should be for a
          framework instead of a library or a generic module. Defaults to `True`.
      hdrs: The list of headers to bundle.
      label_name: Name of the target being built.
      output_discriminator: A string to differentiate between different target intermediate files
          or `None`.
      sdk_dylibs: A list of dynamic libraries referenced by this framework.
      sdk_frameworks: A list of frameworks referenced by this framework.

    Returns:
      A partial that returns the bundle location of the sdk framework header and modulemap
      artifacts.
    """
    return partial.make(
        _framework_header_modulemap_partial_impl,
        actions = actions,
        bundle_name = bundle_name,
        framework_modulemap = framework_modulemap,
        hdrs = hdrs,
        label_name = label_name,
        output_discriminator = output_discriminator,
        sdk_dylibs = sdk_dylibs,
        sdk_frameworks = sdk_frameworks,
    )
