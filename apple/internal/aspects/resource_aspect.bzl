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

"""Implementation of the resource propagation aspect."""

load(
    "@bazel_skylib//lib:collections.bzl",
    "collections",
)
load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
    "AppleDsymBundleInfo",
    "AppleFrameworkBundleInfo",
    "AppleResourceInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:apple_toolchains.bzl",
    "apple_toolchain_utils",
)
load(
    "@build_bazel_rules_apple//apple/internal:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "new_appledsymbundleinfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:resources.bzl",
    "resources",
)
load(
    "@build_bazel_rules_apple//apple/internal:swift_support.bzl",
    "swift_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/providers:apple_debug_info.bzl",
    "AppleDebugInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/providers:apple_resource_hint_info.bzl",
    "AppleResourceHintInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/providers:apple_resource_swift_srcs_info.bzl",
    "AppleResourceSwiftSrcsInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/providers:apple_resource_validation_info.bzl",
    "AppleResourceValidationInfo",
)
load(
    "@build_bazel_rules_swift//swift:module_name.bzl",
    "derive_swift_module_name",
)
load(
    "@build_bazel_rules_swift//swift:providers.bzl",
    "SwiftInfo",
)

visibility("//apple/internal/...")

def _find_apple_resource_hint_info(aspect_ctx):
    """Finds a `AppleResourceHintInfo` provider associated with the target."""
    resource_hint_target = None

    # We don't break this loop early when we find a matching hint, because we
    # want to give an error message if there are two aspect hints that provide
    # `AppleResourceHintInfo` (or if both the rule and an aspect hint do).
    for hint in aspect_ctx.rule.attr.aspect_hints:
        if AppleResourceHintInfo in hint:
            if resource_hint_target:
                fail(("Conflicting Apple resource hint info from aspect hints " +
                      "'{hint1}' and '{hint2}'. Only one is " +
                      "allowed.").format(
                    hint1 = str(resource_hint_target.label),
                    hint2 = str(hint.label),
                ))
            resource_hint_target = hint

    if resource_hint_target:
        return resource_hint_target[AppleResourceHintInfo]
    return None

def _platform_prerequisites_for_aspect(target, aspect_ctx):
    """Return the set of platform prerequisites that can be determined from this aspect."""
    apple_fragment = aspect_ctx.fragments.apple
    apple_xplat_toolchain_info = apple_toolchain_utils.get_xplat_toolchain(aspect_ctx)
    cpp_fragment = aspect_ctx.fragments.cpp
    deps_and_target = getattr(aspect_ctx.rule.attr, "deps", []) + [target]
    uses_swift = swift_support.uses_swift(deps_and_target)

    # TODO(b/176548199): Support device_families when rule_descriptor can be accessed from an
    # aspect, or the list of allowed device families can be determined independently of the
    # rule_descriptor.
    return platform_support.platform_prerequisites(
        apple_fragment = apple_fragment,
        apple_platform_info = platform_support.apple_platform_info_from_rule_ctx(aspect_ctx),
        build_settings = apple_xplat_toolchain_info.build_settings,
        config_vars = aspect_ctx.var,
        device_families = None,
        explicit_minimum_os = cpp_fragment.minimum_os_version(),
        objc_fragment = None,
        uses_swift = uses_swift,
        xcode_version_config = aspect_ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
    )

def _apple_resource_aspect_impl(target, ctx):
    """Implementation of the resource propation aspect."""

    # If the target already propagates a AppleResourceInfo, do nothing.
    if AppleResourceInfo in target:
        return []

    apple_resource_infos = []
    bucketize_args = {}

    process_args = {
        "actions": ctx.actions,
        "apple_mac_toolchain_info": apple_toolchain_utils.get_mac_toolchain(ctx),
        "bundle_id": None,
        "mac_exec_group": apple_toolchain_utils.get_mac_exec_group(ctx),
        "product_type": None,
        "rule_label": ctx.label,
    }
    collect_infoplists_args = {}
    collect_args = {}
    collect_structured_args = {}

    # Owner to attach to the resources as they're being bucketed.
    owner = None

    # The name of the bundle directory to place resources within, if required.
    bundle_name = None

    # The local apple_resource_hint affecting processing.
    apple_resource_hint_info = _find_apple_resource_hint_info(ctx)

    # Any Swift source code files that should be relayed to processing, if required.
    swift_files = depset()

    # Signal if we need to create providers to send Swift source code data down, if required.
    needs_transitive_swift_srcs = False

    if ctx.rule.kind == "objc_library":
        collect_args["res_attrs"] = ["data"]

        # Only set objc_library targets as owners if they have srcs, non_arc_srcs or deps. This
        # treats objc_library targets without sources as resource aggregators.
        if ctx.rule.attr.srcs or ctx.rule.attr.non_arc_srcs or ctx.rule.attr.deps:
            owner = str(ctx.label)

    elif ctx.rule.kind == "swift_library":
        module_names = collections.uniq(
            [x.name for x in target[SwiftInfo].direct_modules if x.swift],
        )
        if not module_names:
            module_names = [derive_swift_module_name(ctx.label)]
        bucketize_args["swift_module"] = module_names[0] if module_names else None
        collect_args["res_attrs"] = ["data"]
        owner = str(ctx.label)
        if apple_resource_hint_info and apple_resource_hint_info.needs_swift_srcs:
            swift_files = depset(transitive = [x.files for x in ctx.rule.attr.srcs])
        if apple_resource_hint_info and apple_resource_hint_info.needs_transitive_swift_srcs:
            needs_transitive_swift_srcs = True

    elif ctx.rule.kind == "apple_resource_group":
        collect_args["res_attrs"] = ["resources"]
        collect_structured_args["res_attrs"] = ["structured_resources"]

    elif ctx.rule.kind == "apple_resource_bundle":
        collect_infoplists_args["res_attrs"] = ["infoplists"]
        collect_args["res_attrs"] = ["resources"]
        collect_structured_args["res_attrs"] = ["structured_resources"]
        bundle_name = "{}.bundle".format(ctx.rule.attr.bundle_name or ctx.label.name)

    # Assign the provider deps once we have the resource attributes sorted out.
    provider_deps = ["deps", "private_deps"] + collect_args.get("res_attrs", [])

    # Any transitive Swift sources that should be relayed to processing, if required.
    transitive_swift_srcs = []

    # Do any work with "provider_deps" up front, ahead of resource processing, when required.
    if needs_transitive_swift_srcs:
        for attr in provider_deps:
            for target in getattr(ctx.rule.attr, attr, []):
                if AppleResourceSwiftSrcsInfo in target:
                    transitive_swift_srcs.append(target[AppleResourceSwiftSrcsInfo])

    # Collect all resource files related to this target.
    if collect_infoplists_args:
        infoplists = resources.collect(
            attr = ctx.rule.attr,
            **collect_infoplists_args
        )
        if infoplists:
            bucketized_owners, unowned_resources, buckets = resources.bucketize_typed_data(
                bucket_type = "infoplists",
                owner = owner,
                parent_dir_param = bundle_name,
                resources = infoplists,
                **bucketize_args
            )
            apple_resource_infos.append(
                resources.process_bucketized_data(
                    bucketized_owners = bucketized_owners,
                    buckets = buckets,
                    platform_prerequisites = _platform_prerequisites_for_aspect(target, ctx),
                    processing_owner = owner,
                    swift_files = swift_files,
                    transitive_swift_srcs = transitive_swift_srcs,
                    unowned_resources = unowned_resources,
                    **process_args
                ),
            )

    if collect_args:
        resource_files = resources.collect(
            attr = ctx.rule.attr,
            **collect_args
        )
        if resource_files:
            bucketized_owners, unowned_resources, buckets = resources.bucketize_data(
                owner = owner,
                parent_dir_param = bundle_name,
                resources = resource_files,
                **bucketize_args
            )
            apple_resource_infos.append(
                resources.process_bucketized_data(
                    bucketized_owners = bucketized_owners,
                    buckets = buckets,
                    platform_prerequisites = _platform_prerequisites_for_aspect(target, ctx),
                    processing_owner = owner,
                    swift_files = swift_files,
                    transitive_swift_srcs = transitive_swift_srcs,
                    unowned_resources = unowned_resources,
                    **process_args
                ),
            )

    if collect_structured_args:
        # `structured_resources` requires an explicit parent directory, requiring them to be
        # processed differently from `resources` and resources inherited from other fields.
        #
        # `structured_resources` also does not support propagating resource providers from
        # apple_resource_group or apple_bundle_import targets, unlike `resources`. If a target is
        # referenced by `structured_resources` that already propagates a resource provider, this
        # will raise an error in the analysis phase.
        for attr in collect_structured_args.get("res_attrs", []):
            for found_attr in getattr(ctx.rule.attr, attr):
                if AppleResourceInfo in found_attr:
                    fail("Error: Found ignored resource providers for target %s. " % ctx.label +
                         "Check that there are no processed resource targets being referenced " +
                         "by structured_resources.")

        structured_files = resources.collect(
            attr = ctx.rule.attr,
            **collect_structured_args
        )
        if structured_files:
            if bundle_name:
                structured_parent_dir_param = partial.make(
                    resources.structured_resources_parent_dir,
                    parent_dir = bundle_name,
                )
            else:
                structured_parent_dir_param = partial.make(
                    resources.structured_resources_parent_dir,
                )

            # Avoid processing PNG files that are referenced through the structured_resources
            # attribute. This is mostly for legacy reasons and should get cleaned up in the future.
            bucketized_owners, unowned_resources, buckets = resources.bucketize_data(
                allowed_buckets = ["strings", "plists"],
                owner = owner,
                parent_dir_param = structured_parent_dir_param,
                resources = structured_files,
                **bucketize_args
            )
            apple_resource_infos.append(
                resources.process_bucketized_data(
                    bucketized_owners = bucketized_owners,
                    buckets = buckets,
                    platform_prerequisites = _platform_prerequisites_for_aspect(target, ctx),
                    processing_owner = owner,
                    swift_files = swift_files,
                    transitive_swift_srcs = transitive_swift_srcs,
                    unowned_resources = unowned_resources,
                    **process_args
                ),
            )

    # Get the providers from dependencies, referenced by deps and locations for resources.
    apple_resource_validation_infos = []
    apple_debug_infos = []
    apple_dsym_bundle_infos = []
    inherited_apple_resource_infos = []
    for attr in provider_deps:
        if hasattr(ctx.rule.attr, attr):
            targets = getattr(ctx.rule.attr, attr)
            for target in targets:
                if AppleFrameworkBundleInfo in target and AppleBundleInfo in target:
                    # Create a reference to the AppleBundleInfo for any rules that output a
                    # framework bundle for validation in the top level bundling rule.
                    #
                    # Further, we want to track the source of this AppleBundleInfo for logging via
                    # the rule label. Otherwise we won't be able to get at the target/label later.
                    target_apple_bundle_info = struct(
                        apple_bundle_info = target[AppleBundleInfo],
                        target_label = str(target.label),
                    )

                    apple_resource_validation_infos.append(
                        AppleResourceValidationInfo(
                            direct_target_bundle_infos = [target_apple_bundle_info],
                            transitive_target_bundle_infos = depset([target_apple_bundle_info]),
                        ),
                    )

                if AppleFrameworkBundleInfo not in target and AppleResourceInfo in target:
                    # Propagate the AppleResourceInfo for non-AppleFrameworkBundleInfo targets, to
                    # avoid propagating resources that should not be extended beyond the framework.
                    inherited_apple_resource_infos.append(target[AppleResourceInfo])

                # Propagate AppleDebugInfo providers from deps/resources-referenced dependencies
                # required for the debug_symbols partial. This will often start from frameworks.
                if AppleDebugInfo in target:
                    apple_debug_infos.append(target[AppleDebugInfo])

                if AppleDsymBundleInfo in target:
                    apple_dsym_bundle_infos.append(target[AppleDsymBundleInfo])

                if AppleResourceValidationInfo in target:
                    apple_resource_validation_infos.append(target[AppleResourceValidationInfo])

    if inherited_apple_resource_infos and bundle_name:
        # Nest the inherited resource providers within the bundle, if one is needed for this rule.
        merged_inherited_provider = resources.merge_providers(
            default_owner = owner,
            providers = inherited_apple_resource_infos,
        )
        apple_resource_infos.append(resources.nest_in_bundle(
            provider_to_nest = merged_inherited_provider,
            nesting_bundle_dir = bundle_name,
        ))
    elif inherited_apple_resource_infos:
        apple_resource_infos.extend(inherited_apple_resource_infos)

    providers = []
    if apple_resource_infos:
        # If any providers were collected, merge them.
        providers.append(
            resources.merge_providers(
                default_owner = owner,
                providers = apple_resource_infos,
            ),
        )

    if apple_resource_validation_infos:
        providers.append(
            AppleResourceValidationInfo(
                direct_target_bundle_infos = [],
                transitive_target_bundle_infos = depset(
                    transitive = [
                        x.transitive_target_bundle_infos
                        for x in apple_resource_validation_infos
                    ],
                ),
            ),
        )

    if needs_transitive_swift_srcs:
        # Start by sending up a direct reference to the current set of Swift source information.
        swift_src_info = struct(
            module_name = bucketize_args["swift_module"],
            src_files = swift_files,
        )
        transitive_swift_src_infos = []
        if transitive_swift_srcs:
            # Append any additional Swift source infos if any were found before
            transitive_swift_src_infos = [
                x.transitive_swift_src_infos
                for x in transitive_swift_srcs
            ]
        providers.append(
            AppleResourceSwiftSrcsInfo(
                transitive_swift_src_infos = depset(
                    [swift_src_info],
                    transitive = transitive_swift_src_infos,
                ),
            ),
        )

    if apple_debug_infos:
        providers.append(
            AppleDebugInfo(
                dsyms = depset(transitive = [x.dsyms for x in apple_debug_infos]),
                linkmaps = depset(transitive = [x.linkmaps for x in apple_debug_infos]),
            ),
        )

    if apple_dsym_bundle_infos:
        providers.append(
            new_appledsymbundleinfo(
                direct_dsyms = [],
                transitive_dsyms = depset(
                    transitive = [x.transitive_dsyms for x in apple_dsym_bundle_infos],
                ),
            ),
        )

    return providers

apple_resource_aspect = aspect(
    implementation = _apple_resource_aspect_impl,
    attr_aspects = ["data", "deps", "private_deps", "resources", "structured_resources"],
    attrs = dicts.add(
        apple_support.action_required_attrs(),
        apple_support.platform_constraint_attrs(),
    ),
    exec_groups = apple_toolchain_utils.use_apple_exec_group_toolchain(),
    fragments = ["apple", "cpp"],
    doc = """Aspect that collects and propagates resource information to be bundled by a top-level
bundling rule.""",
)
