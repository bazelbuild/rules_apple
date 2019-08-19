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
    "@build_bazel_rules_apple//apple/internal:file_support.bzl",
    "file_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:experimental.bzl",
    "is_experimental_tree_artifact_enabled",
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
    "@build_bazel_rules_apple//apple/internal:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:processor.bzl",
    "processor",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
    "AppleExtraOutputsInfo",
    "AppleTestInfo",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "SwiftInfo",
)
load(
    "@bazel_skylib//lib:types.bzl",
    "types",
)

# Default test bundle ID for tests that don't have a test host or were not given
# a bundle ID.
_DEFAULT_TEST_BUNDLE_ID = "com.bazelbuild.rulesapple.Tests"

def _collect_files(rule_attr, attr_name):
    """Collects files from attr_name (if present) into a depset."""

    attr_val = getattr(rule_attr, attr_name, None)
    if not attr_val:
        return depset()

    attr_val_as_list = attr_val if types.is_list(attr_val) else [attr_val]
    return depset(transitive = [f.files for f in attr_val_as_list])

def _apple_test_info_aspect_impl(target, ctx):
    """See `test_info_aspect` for full documentation."""
    includes = []
    module_maps = []
    swift_modules = []

    # Not all deps (i.e. source files) will have an AppleTestInfo provider. If the
    # dep doesn't, just filter it out.
    test_infos = [
        x[AppleTestInfo]
        for x in getattr(ctx.rule.attr, "deps", [])
        if AppleTestInfo in x
    ]

    # Collect transitive information from deps.
    for test_info in test_infos:
        includes.append(test_info.includes)
        module_maps.append(test_info.module_maps)
        swift_modules.append(test_info.swift_modules)

    if apple_common.Objc in target:
        objc_provider = target[apple_common.Objc]
        includes.append(objc_provider.include)

        # Module maps should only be used by Swift targets.
        if SwiftInfo in target:
            module_maps.append(objc_provider.module_map)

    if (SwiftInfo in target and
        hasattr(target[SwiftInfo], "transitive_swiftmodules")):
        swift_modules.append(target[SwiftInfo].transitive_swiftmodules)

    # Collect sources from the current target and add any relevant transitive
    # information. Note that we do not propagate sources transitively as we
    # intentionally only show test sources from the test's first-level of
    # dependencies instead of all transitive dependencies.
    non_arc_sources = _collect_files(ctx.rule.attr, "non_arc_srcs")
    sources = _collect_files(ctx.rule.attr, "srcs")

    return [AppleTestInfo(
        includes = depset(transitive = includes),
        module_maps = depset(transitive = module_maps),
        non_arc_sources = non_arc_sources,
        sources = sources,
        swift_modules = depset(transitive = swift_modules),
    )]

apple_test_info_aspect = aspect(
    attr_aspects = [
        "deps",
    ],
    doc = """
This aspect walks the dependency graph through the `deps` attribute and collects sources, transitive
includes, transitive module maps, and transitive Swift modules.

This aspect propagates an `AppleTestInfo` provider.
""",
    implementation = _apple_test_info_aspect_impl,
)

def _apple_test_info_provider(deps, test_bundle, test_host):
    """Returns an AppleTestInfo provider by collecting the relevant data from dependencies."""
    dep_labels = []
    swift_infos = []

    transitive_includes = []
    transitive_module_maps = []
    transitive_non_arc_sources = []
    transitive_sources = []
    transitive_swift_modules = []

    for dep in deps:
        dep_labels.append(str(dep.label))

        if SwiftInfo in dep:
            swift_infos.append(dep[SwiftInfo])

        test_info = dep[AppleTestInfo]

        transitive_includes.append(test_info.includes)
        transitive_module_maps.append(test_info.module_maps)
        transitive_non_arc_sources.append(test_info.non_arc_sources)
        transitive_sources.append(test_info.sources)
        transitive_swift_modules.append(test_info.swift_modules)

    # Set module_name only for test targets with a single Swift dependency.
    # This is not used if there are multiple Swift dependencies, as it will
    # not be possible to reduce them into a single Swift module and picking
    # an arbitrary one is fragile.
    module_name = None
    if len(swift_infos) == 1:
        module_name = getattr(swift_infos[0], "module_name", None)

    return AppleTestInfo(
        deps = depset(dep_labels),
        includes = depset(transitive = transitive_includes),
        module_maps = depset(transitive = transitive_module_maps),
        module_name = module_name,
        non_arc_sources = depset(transitive = transitive_non_arc_sources),
        sources = depset(transitive = transitive_sources),
        swift_modules = depset(transitive = transitive_swift_modules),
        test_bundle = test_bundle,
        test_host = test_host,
    )

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

    if hasattr(ctx.attr, "additional_contents"):
        debug_dependencies = ctx.attr.additional_contents.keys()
    else:
        debug_dependencies = []

    if hasattr(ctx.attr, "frameworks"):
        targets_to_avoid = list(ctx.attr.frameworks)
    else:
        targets_to_avoid = []
    product_type = ctx.attr._product_type
    if ctx.attr.test_host:
        debug_dependencies.append(ctx.attr.test_host)
        if product_type == apple_product_type.unit_test_bundle:
            targets_to_avoid.append(ctx.attr.test_host)

    processor_partials = [
        partials.apple_bundle_info_partial(bundle_id = bundle_id),
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.clang_rt_dylibs_partial(binary_artifact = binary_artifact),
        partials.debug_symbols_partial(
            debug_dependencies = debug_dependencies,
            debug_outputs_provider = debug_outputs_provider,
        ),
        partials.embedded_bundles_partial(
            bundle_embedded_bundles = True,
            embeddable_targets = getattr(ctx.attr, "frameworks", []),
        ),
        partials.framework_import_partial(
            targets = ctx.attr.deps,
            targets_to_avoid = targets_to_avoid,
        ),
        partials.resources_partial(
            bundle_id = bundle_id,
            plist_attrs = ["infoplists"],
            targets_to_avoid = targets_to_avoid,
            version_keys_required = False,
            top_level_attrs = ["resources"],
        ),
        partials.swift_dylibs_partial(
            binary_artifact = binary_artifact,
            bundle_dylibs = True,
        ),
    ]

    if platform_support.platform_type(ctx) == apple_common.platform_type.macos:
        processor_partials.append(
            partials.macos_additional_contents_partial(),
        )

    processor_result = processor.process(ctx, processor_partials)

    # The processor outputs has all the extra outputs like dSYM files that we want to propagate, but
    # it also includes the archive artifact. This collects all the files that should be output from
    # the rule (except the archive) so that they're propagated and can be returned by the test
    # target.
    filtered_outputs = [
        x
        for x in processor_result.output_files.to_list()
        if x != outputs.archive(ctx)
    ]

    providers = processor_result.providers
    output_files = processor_result.output_files

    # Symlink the test bundle archive to the output attribute. This is used when having a test such
    # as `ios_unit_test(name = "Foo")` to declare a `:Foo.zip` target.
    file_support.symlink(
        ctx,
        ctx.outputs.archive,
        ctx.outputs.test_bundle_output,
    )

    if is_experimental_tree_artifact_enabled(ctx):
        test_runner_bundle_output = outputs.archive(ctx)
    else:
        test_runner_bundle_output = ctx.outputs.test_bundle_output

    # Append the AppleTestBundleInfo provider with pointers to the test and host bundles.
    test_host_archive = None
    if ctx.attr.test_host:
        test_host_archive = ctx.attr.test_host[AppleBundleInfo].archive
    providers.extend([
        _apple_test_info_provider(
            deps = ctx.attr.deps,
            test_bundle = test_runner_bundle_output,
            test_host = test_host_archive,
        ),
        coverage_common.instrumented_files_info(
            ctx,
            dependency_attributes = ["deps", "test_host"],
        ),
        AppleExtraOutputsInfo(files = depset(filtered_outputs)),
        DefaultInfo(files = output_files),
    ])

    return providers

apple_test_bundle_support = struct(
    apple_test_bundle_impl = _apple_test_bundle_impl,
)
