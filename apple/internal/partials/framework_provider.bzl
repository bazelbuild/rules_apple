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

"""Partial implementation for AppleDynamicFrameworkInfo configuration."""

load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

def _framework_provider_partial_impl(
        *,
        actions,
        bin_root_path,
        binary_artifact,
        bundle_name,
        bundle_only,
        objc_provider,
        rule_label):
    """Implementation for the framework provider partial."""

    # Create a directory structure that the linker can use to reference this
    # framework. It follows the pattern of
    # any_path/MyFramework.framework/MyFramework. The absolute path and files are
    # propagated using the AppleDynamicFrameworkInfo provider.
    framework_dir = paths.join("frameworks", "%s.framework" % bundle_name)
    framework_file = actions.declare_file(
        paths.join(framework_dir, bundle_name),
    )
    actions.symlink(
        target_file = binary_artifact,
        output = framework_file,
    )

    absolute_framework_dir = paths.join(
        bin_root_path,
        rule_label.package,
        framework_dir,
    )

    # TODO(cparsons): These will no longer be necessary once apple_binary
    # uses the values in the dynamic framework provider.
    legacy_objc_provider = apple_common.new_objc_provider(
        dynamic_framework_file = depset([] if bundle_only else [framework_file]),
        providers = [objc_provider],
    )

    framework_provider = apple_common.new_dynamic_framework_provider(
        binary = binary_artifact,
        framework_dirs = depset([absolute_framework_dir]),
        framework_files = depset([framework_file]),
        objc = legacy_objc_provider,
    )

    return struct(
        providers = [framework_provider],
    )

def framework_provider_partial(
        *,
        actions,
        bin_root_path,
        binary_artifact,
        bundle_name,
        bundle_only,
        objc_provider,
        rule_label):
    """Constructor for the framework provider partial.

    This partial propagates the AppleDynamicFrameworkInfo provider required by
    the linking step. It contains the necessary files and configuration so that
    the framework can be linked against. This is only required for dynamic
    framework bundles.

    Args:
      actions: The actions provider from `ctx.actions`.
      bin_root_path: The path to the root `-bin` directory.
      binary_artifact: The linked dynamic framework binary.
      bundle_name: The name of the output bundle.
      bundle_only: Only include the bundle but do not link the framework
      objc_provider: The `apple_common.Objc` provider containing information
          about the targets linked into the dynamic framework.
      rule_label: The label of the target being analyzed.

    Returns:
      A partial that returns the AppleDynamicFrameworkInfo provider used to link
      this framework into the final binary.
    """
    return partial.make(
        _framework_provider_partial_impl,
        actions = actions,
        bin_root_path = bin_root_path,
        binary_artifact = binary_artifact,
        bundle_name = bundle_name,
        bundle_only = bundle_only,
        objc_provider = objc_provider,
        rule_label = rule_label,
    )
