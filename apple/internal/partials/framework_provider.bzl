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
    "@build_bazel_rules_apple//apple/internal:bundling_support.bzl",
    "bundling_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:file_support.bzl",
    "file_support",
)
load(
    "@build_bazel_apple_support//lib:framework_migration.bzl",
    "framework_migration",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

def _framework_provider_partial_impl(ctx, binary_provider):
    """Implementation for the framework provider partial."""
    binary_file = binary_provider.binary

    bundle_name = bundling_support.bundle_name(ctx)

    # Create a directory structure that the linker can use to reference this
    # framework. It follows the pattern of
    # any_path/MyFramework.framework/MyFramework. The absolute path and files are
    # propagated using the AppleDynamicFrameworkInfo provider.
    framework_dir = paths.join("frameworks", "%s.framework" % bundle_name)
    framework_file = ctx.actions.declare_file(
        paths.join(framework_dir, bundle_name),
    )
    file_support.symlink(ctx, binary_file, framework_file)

    absolute_framework_dir = paths.join(
        ctx.bin_dir.path,
        ctx.label.package,
        framework_dir,
    )

    # TODO(cparsons): These will no longer be necessary once apple_binary
    # uses the values in the dynamic framework provider.
    if framework_migration.is_post_framework_migration():
        legacy_objc_provider = apple_common.new_objc_provider(
            dynamic_framework_file = depset([framework_file]),
            providers = [binary_provider.objc],
        )
    else:
        legacy_objc_provider = apple_common.new_objc_provider(
            dynamic_framework_dir = depset([absolute_framework_dir]),
            dynamic_framework_file = depset([framework_file]),
            providers = [binary_provider.objc],
        )

    framework_provider = apple_common.new_dynamic_framework_provider(
        binary = binary_file,
        framework_dirs = depset([absolute_framework_dir]),
        framework_files = depset([framework_file]),
        objc = legacy_objc_provider,
    )

    return struct(
        providers = [framework_provider],
    )

def framework_provider_partial(binary_provider):
    """Constructor for the framework provider partial.

    This partial propagates the AppleDynamicFrameworkInfo provider required by
    the linking step. It contains the necessary files and configuration so that
    the framework can be linked against. This is only required for dynamic
    framework bundles.

    Args:
      binary_provider: The AppleDylibBinary provider containing this target's binary.

    Returns:
      A partial that returns the AppleDynamicFrameworkInfo provider used to link
      this framework into the final binary.
    """
    return partial.make(
        _framework_provider_partial_impl,
        binary_provider = binary_provider,
    )
