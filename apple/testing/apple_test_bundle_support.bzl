# Copyright 2017 The Bazel Authors. All rights reserved.
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

"""Helper methods for implementing the test bundles."""

load(
    "@build_bazel_rules_apple//apple/bundling:binary_support.bzl",
    "binary_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:bundler.bzl",
    "bundler",
)
load(
    "@build_bazel_rules_apple//apple/bundling:product_support.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
)

# Default test bundle ID for tests that don't have a test host or were not given
# a bundle ID.
_DEFAULT_TEST_BUNDLE_ID = "com.bazelbuild.rulesapple.Tests"

def _computed_test_bundle_id(test_host_bundle_id):
    """Compute a test bundle ID from the test host, or a default if not given."""
    if test_host_bundle_id:
        bundle_id = test_host_bundle_id + "Tests"
    else:
        bundle_id = _DEFAULT_TEST_BUNDLE_ID

    return bundle_id

def _test_host_bundle_id(test_host):
    """Return the bundle ID for the given test host, or None if none was given."""
    if not test_host:
        return None
    test_host_bundle_info = test_host[AppleBundleInfo]
    return test_host_bundle_info.bundle_id

def _apple_test_bundle_impl(
        ctx,
        mnemonic,
        progress_description,
        extra_providers):
    """Implementation for the test bundle rules."""
    test_host_bundle_id = _test_host_bundle_id(ctx.attr.test_host)
    if ctx.attr.bundle_id:
        bundle_id = ctx.attr.bundle_id
    else:
        bundle_id = _computed_test_bundle_id(test_host_bundle_id)

    if bundle_id == test_host_bundle_id:
        fail("The test bundle's identifier of '" + bundle_id + "' can't be the " +
             "same as the test host's bundle identifier. Please change one of " +
             "them.")

    bundler_extra_args = {}
    if ctx.attr.test_host:
        # We gather the framework files which have already been bundled inside the
        # application bundle, so that the bundler can deduplicate framework files
        # that do not need to be present in both bundles, reducing overall size.
        test_host_apple_bundle = ctx.attr.test_host[AppleBundleInfo]
        bundler_extra_args["avoid_propagated_framework_files"] = (
            test_host_apple_bundle.propagated_framework_files
        )

    # Only set the test host as a dependency if it's a unit test, as in UI tests,
    # the test bundle doesn't run from within the test host.
    if ctx.attr.product_type == apple_product_type.unit_test_bundle:
        bundler_extra_args["resource_dep_bundle_attributes"] = ["test_host"]

    binary_artifact = binary_support.get_binary_provider(
        ctx.attr.deps,
        apple_common.AppleLoadableBundleBinary,
    ).binary
    deps_objc_provider = binary_support.get_binary_provider(
        ctx.attr.deps,
        apple_common.AppleLoadableBundleBinary,
    ).objc
    bundler_providers, legacy_providers = bundler.run(
        ctx,
        mnemonic,
        progress_description,
        bundle_id,
        binary_artifact = binary_artifact,
        deps_objc_providers = [deps_objc_provider],
        version_keys_required = False,
        **bundler_extra_args
    )
    return struct(
        instrumented_files = struct(dependency_attributes = ["binary", "test_host"]),
        providers = extra_providers + bundler_providers,
        **legacy_providers
    )

# Define the loadable module that lists the exported symbols in this file.
apple_test_bundle_support = struct(
    apple_test_bundle_impl = _apple_test_bundle_impl,
)
