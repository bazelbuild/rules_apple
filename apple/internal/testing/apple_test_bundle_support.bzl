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
    "@build_bazel_rules_apple//apple/internal:binary_support.bzl",
    "binary_support",
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
    "AppleExtraOutputsInfo",
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
    """Experimental implementation of Apple test bundles."""
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

    return processor_result.providers + extra_providers + [
        coverage_common.instrumented_files_info(
            ctx,
            dependency_attributes = ["deps", "test_host"],
        ),
        # TODO(kaipi): Remove this provider when apple_*_test is merged with the bundle and binary
        # rules.
        AppleExtraOutputsInfo(files = depset(filtered_outputs)),
    ]

def _assemble_test_targets(
        name,
        bundling_rule,
        platform_type,
        test_rule,
        bundle_loader = None,
        platform_default_runner = None,
        uses_provisioning_profile = False,
        **kwargs):
    """Macro that routes the external macro arguments into the correct targets.

    This macro creates 3 targets:

    * name + ".apple_binary": Represents the binary that contains the test code. It
        captures the deps and test_host arguments.
    * name + "_test_bundle": Represents the xctest bundle that contains the binary
        along with the test resources. It captures the bundle_id and infoplists
        arguments.
    * name: The actual test target that can be invoked with `bazel test`. This
        target takes all the remaining arguments passed.

    Args:
        name: The name for the top level test target.
        bundling_rule: The rule to use when bundling the test bundle.
        platform_type: The platform type for the targets being created.
        test_rule: The rule to use for the top level test target.
        bundle_loader: If specified, the apple_binary target to specify as the bundle loader for the
            test binary.
        platform_default_runner: The default runner for the platform, in case none is provider by
            the user.
        uses_provisioning_profile: Whether the test rule requires a provisioning profile for running
            tests on devices. Used for UI tests.
        **kwargs: Extra test attributes to proxy through.
    """
    test_bundle_name = name + "_test_bundle"

    # Catch the linkopts to set them into the bundle target.
    linkopts = kwargs.pop("linkopts", [])

    # Discard binary_tags for now, as there is no apple_binary target any more to apply them to.
    # TODO(kaipi): Cleanup binary_tags for tests and remove this.
    kwargs.pop("binary_tags", [])

    # Extract bundle specific arguments so that they are not forwarded to the test rule target.
    bundle_id = kwargs.pop("bundle_id", None)
    deps = kwargs.pop("deps", None)
    minimum_os_version = kwargs.pop("minimum_os_version", None)
    test_host = kwargs.pop("test_host", None)
    infoplists = kwargs.pop(
        "infoplists",
        ["@build_bazel_rules_apple//apple/testing:DefaultTestBundlePlist"],
    )

    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = platform_type,
        bundle_id = bundle_id,
        include_entitlements = False,
        testonly = True,
        deps = deps,
        tags = kwargs.get("tags"),
    )

    if uses_provisioning_profile:
        bundling_args["provisioning_profile"] = kwargs.pop("provisioning_profile", None)

    bundling_rule(
        name = test_bundle_name,
        bundle_loader = bundle_loader,
        bundle_name = name,
        infoplists = infoplists,
        linkopts = linkopts,
        minimum_os_version = minimum_os_version,
        test_host = test_host,
        **bundling_args
    )

    runner = kwargs.pop("runner", platform_default_runner)

    test_rule(
        name = name,
        platform_type = platform_type,
        runner = runner,
        test_bundle = test_bundle_name,
        test_host = test_host,
        **kwargs
    )

apple_test_bundle_support = struct(
    apple_test_bundle_impl = _apple_test_bundle_impl,
    assemble_test_targets = _assemble_test_targets,
)
