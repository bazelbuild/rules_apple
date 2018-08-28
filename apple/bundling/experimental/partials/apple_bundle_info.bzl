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

"""Partial implementation for the AppleBundleInfo provider."""

load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
)
load(
    "@build_bazel_rules_apple//apple/bundling:bundling_support.bzl",
    "bundling_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:product_support.bzl",
    "product_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:swift_support.bzl",
    "swift_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:outputs.bzl",
    "outputs",
)

def _apple_bundle_info_partial_impl(ctx, bundle_id):
    """Implementation for the AppleBundleInfo processing partial."""

    infoplist = None
    if bundle_id:
        # If there's no bundle ID, don't add the Info.plist file into AppleBundleInfo.
        infoplist = outputs.infoplist(ctx)

    # TODO(kaipi): Fill in missing file fields.
    return struct(
        providers = [
            AppleBundleInfo(
                archive = outputs.archive(ctx),
                archive_root = None,
                bundle_dir = None,
                bundle_id = bundle_id,
                bundle_name = bundling_support.bundle_name(ctx),
                bundle_extension = bundling_support.bundle_extension(ctx),
                entitlements = getattr(ctx.attr, "entitlements", None),
                infoplist = infoplist,
                minimum_os_version = platform_support.minimum_os(ctx),
                product_type = product_support.product_type(ctx),
                propagated_framework_files = depset([]),
                uses_swift = swift_support.uses_swift(ctx.attr.deps),
            ),
        ],
    )

def apple_bundle_info_partial(bundle_id = None):
    """Constructor for the AppleBundleInfo processing partial.

    This partial propagates the AppleBundleInfo provider for this target.

    Args:
      bundle_id: The bundle ID to configure for this target.

    Returns:
      A partial that returns the AppleBundleInfo provider.
    """
    return partial.make(
        _apple_bundle_info_partial_impl,
        bundle_id = bundle_id,
    )
