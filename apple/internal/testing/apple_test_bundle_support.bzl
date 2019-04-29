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

"""Helper methods for implementing the test bundles."""

load(
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/internal:linking_support.bzl",
    "linking_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:outputs.bzl",
    "outputs",
)
load(
    "@build_bazel_rules_apple//apple/internal:partials.bzl",
    "partials",
)
load(
    "@build_bazel_rules_apple//apple/internal:processor.bzl",
    "processor",
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

def _apple_test_bundle_impl(ctx, extra_providers = []):
    """Implementation for bundling XCTest bundles."""
    test_host_bundle_id = _test_host_bundle_id(ctx.attr.test_host)
    if ctx.attr.bundle_id:
        bundle_id = ctx.attr.bundle_id
    else:
        bundle_id = _computed_test_bundle_id(test_host_bundle_id)

    if bundle_id == test_host_bundle_id:
        fail("The test bundle's identifier of '" + bundle_id + "' can't be the " +
             "same as the test host's bundle identifier. Please change one of " +
             "them.")

    binary_descriptor = linking_support.register_linking_action(ctx)
    binary_artifact = binary_descriptor.artifact
    debug_outputs_provider = binary_descriptor.debug_outputs_provider

    test_host_list = []
    product_type = ctx.attr._product_type
    if ctx.attr.test_host and product_type == apple_product_type.unit_test_bundle:
        test_host_list.append(ctx.attr.test_host)

    processor_partials = [
        partials.apple_bundle_info_partial(bundle_id = bundle_id),
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.clang_rt_dylibs_partial(binary_artifact = binary_artifact),
        partials.debug_symbols_partial(
            debug_dependencies = test_host_list,
            debug_outputs_provider = debug_outputs_provider,
        ),
        partials.framework_import_partial(
            targets = ctx.attr.deps,
            targets_to_avoid = test_host_list,
        ),
        partials.resources_partial(
            bundle_id = bundle_id,
            plist_attrs = ["infoplists"],
            targets_to_avoid = test_host_list,
            version_keys_required = False,
        ),
        partials.swift_dylibs_partial(
            binary_artifact = binary_artifact,
            bundle_dylibs = True,
        ),
    ]

    processor_result = processor.process(ctx, processor_partials)

    # TODO(kaipi): Remove this filtering when apple_*_test is merged with the bundle and binary
    # rules. The processor outputs has all the extra outputs like dSYM files that we want to
    # propagate, but it also includes the archive artifact. Because this target is an intermediate
    # and hidden target, we don't want to expose this artifact directly as an output, as the
    # apple_*_test rules will copy and rename this archive with the correct name.
    filtered_outputs = [
        x
        for x in processor_result.output_files.to_list()
        if x != outputs.archive(ctx)
    ]

    providers = processor_result.providers
    output_files = processor_result.output_files

    return providers, output_files

apple_test_bundle_support = struct(
    apple_test_bundle_impl = _apple_test_bundle_impl,
)
