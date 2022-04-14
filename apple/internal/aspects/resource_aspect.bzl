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
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:apple_toolchains.bzl",
    "AppleMacToolsToolchainInfo",
    "apple_toolchain_utils",
)
load(
    "@build_bazel_rules_apple//apple/internal:platform_support.bzl",
    "platform_support",
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
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleResourceInfo",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "SwiftInfo",
)
load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)
load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)

def _platform_prerequisites_for_aspect(target, aspect_ctx):
    """Return the set of platform prerequisites that can be determined from this aspect."""
    deps_and_target = getattr(aspect_ctx.rule.attr, "deps", []) + [target]
    uses_swift = swift_support.uses_swift(deps_and_target)

    # TODO(b/176548199): Support device_families when rule_descriptor can be accessed from an
    # aspect, or the list of allowed device families can be determined independently of the
    # rule_descriptor.
    return platform_support.platform_prerequisites(
        apple_fragment = aspect_ctx.fragments.apple,
        config_vars = aspect_ctx.var,
        device_families = None,
        disabled_features = aspect_ctx.disabled_features,
        explicit_minimum_deployment_os = None,
        explicit_minimum_os = None,
        features = aspect_ctx.features,
        objc_fragment = None,
        platform_type_string = str(aspect_ctx.fragments.apple.single_arch_platform.platform_type),
        uses_swift = uses_swift,
        xcode_version_config = aspect_ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
    )

def _apple_resource_aspect_impl(target, ctx):
    """Implementation of the resource propation aspect."""

    # If the target already propagates a AppleResourceInfo, do nothing.
    if AppleResourceInfo in target:
        return []

    providers = []
    bucketize_args = {}

    # TODO(b/174858377) Follow up to see if we need to define output_discriminator for process_args
    # if an input from the aspect context indicates that the Apple resource aspect is being sent
    # down a split transition that builds for multiple platforms. This should match an existing
    # output_discriminator used for resource processing in the top level rule. It might not be
    # necessary to do this on account of how deduping resources works in the resources partial.
    process_args = {
        "actions": ctx.actions,
        "apple_mac_toolchain_info": ctx.attr._mac_toolchain[AppleMacToolsToolchainInfo],
        "bundle_id": None,
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

    if ctx.rule.kind == "objc_library":
        collect_args["res_attrs"] = ["data"]

        # Only set objc_library targets as owners if they have srcs, non_arc_srcs or deps. This
        # treats objc_library targets without sources as resource aggregators.
        if ctx.rule.attr.srcs or ctx.rule.attr.non_arc_srcs or ctx.rule.attr.deps:
            owner = str(ctx.label)

    elif ctx.rule.kind == "swift_library":
        module_names = [x.name for x in target[SwiftInfo].direct_modules if x.swift]
        bucketize_args["swift_module"] = module_names[0] if module_names else None
        collect_args["res_attrs"] = ["data"]
        owner = str(ctx.label)

    elif ctx.rule.kind == "apple_resource_group":
        collect_args["res_attrs"] = ["resources"]
        collect_structured_args["res_attrs"] = ["structured_resources"]

    elif ctx.rule.kind == "apple_resource_bundle":
        collect_infoplists_args["res_attrs"] = ["infoplists"]
        collect_args["res_attrs"] = ["resources"]
        collect_structured_args["res_attrs"] = ["structured_resources"]
        process_args["bundle_id"] = ctx.rule.attr.bundle_id or None
        bundle_name = "{}.bundle".format(ctx.rule.attr.bundle_name or ctx.label.name)

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
            providers.append(
                resources.process_bucketized_data(
                    bucketized_owners = bucketized_owners,
                    buckets = buckets,
                    platform_prerequisites = _platform_prerequisites_for_aspect(target, ctx),
                    processing_owner = owner,
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
                resources = resource_files,
                owner = owner,
                parent_dir_param = bundle_name,
                **bucketize_args
            )
            providers.append(
                resources.process_bucketized_data(
                    bucketized_owners = bucketized_owners,
                    buckets = buckets,
                    platform_prerequisites = _platform_prerequisites_for_aspect(target, ctx),
                    processing_owner = owner,
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
            providers.append(
                resources.process_bucketized_data(
                    bucketized_owners = bucketized_owners,
                    buckets = buckets,
                    platform_prerequisites = _platform_prerequisites_for_aspect(target, ctx),
                    processing_owner = owner,
                    unowned_resources = unowned_resources,
                    **process_args
                ),
            )

    # Get the providers from dependencies, referenced by deps and locations for resources.
    inherited_providers = []
    provider_deps = ["deps"] + collect_args.get("res_attrs", [])
    for attr in provider_deps:
        if hasattr(ctx.rule.attr, attr):
            inherited_providers.extend([
                x[AppleResourceInfo]
                for x in getattr(ctx.rule.attr, attr)
                if AppleResourceInfo in x
            ])
    if inherited_providers and bundle_name:
        # Nest the inherited resource providers within the bundle, if one is needed for this rule.
        merged_inherited_provider = resources.merge_providers(
            default_owner = owner,
            providers = inherited_providers,
        )
        providers.append(resources.nest_in_bundle(
            provider_to_nest = merged_inherited_provider,
            nesting_bundle_dir = bundle_name,
        ))
    elif inherited_providers:
        providers.extend(inherited_providers)

    if providers:
        # If any providers were collected, merge them.
        return [resources.merge_providers(
            default_owner = owner,
            providers = providers,
        )]
    return []

apple_resource_aspect = aspect(
    implementation = _apple_resource_aspect_impl,
    attr_aspects = ["data", "deps", "resources", "structured_resources"],
    attrs = dicts.add(
        apple_support.action_required_attrs(),
        apple_toolchain_utils.shared_attrs(),
    ),
    fragments = ["apple"],
    doc = """Aspect that collects and propagates resource information to be bundled by a top-level
bundling rule.""",
)
