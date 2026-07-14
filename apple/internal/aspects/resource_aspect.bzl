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
load("@build_bazel_apple_support//xcode:providers.bzl", "XcodeVersionInfo")
load(
    "@build_bazel_rules_apple//apple/internal:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "AppleBundleImportInfo",
    "AppleBundleInfo",
    "AppleDsymBundleInfo",
    "AppleFrameworkBundleInfo",
    "AppleLinkmapInfo",
    "AppleResourceBundleInfo",
    "AppleResourceGroupInfo",
    "AppleResourceInfo",
    "new_appledsymbundleinfo",
    "new_applelinkmapinfo",
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
    "@build_bazel_rules_apple//apple/internal/providers:app_intents_info.bzl",
    "AppIntentsBundleInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/providers:apple_resource_explicit_files_info.bzl",
    "AppleResourceExplicitFilesInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/providers:apple_resource_validation_info.bzl",
    "AppleResourceValidationInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/toolchains:apple_toolchains.bzl",
    "apple_toolchain_utils",
)
load(
    "@build_bazel_rules_swift//swift:providers.bzl",
    "SwiftInfo",
)

visibility([
    "@build_bazel_rules_apple//apple/...",
])

_RESOURCE_ASPECT_BASE_ATTRS = [
    # keep sorted
    "data",
    "deps",
    "implementation_deps",
    "private_deps",
]

_RESOURCE_ASPECT_ADDITIONAL_RESOURCE_RULE_ATTRS = [
    "resources",
    "structured_resources",
]

# A map of resource rule qualified kinds mapping the rule name to the file label defining the rule.
_SUPPORTED_QUALIFIED_KINDS = {
    "apple_resource_bundle": "@build_bazel_rules_apple//apple/internal/resource_rules:apple_resource_bundle.bzl",
    "apple_resource_group": "@build_bazel_rules_apple//apple/internal/resource_rules:apple_resource_group.bzl",
}

# A map of resource rule qualified kinds mapping the rule name to the set of additional attrs that
# should be propagated by the resource aspect.
_SUPPORTED_QUALIFIED_KINDS_PROPAGATION_ATTRS = {
    "apple_resource_bundle": (
        _RESOURCE_ASPECT_ADDITIONAL_RESOURCE_RULE_ATTRS + _RESOURCE_ASPECT_BASE_ATTRS
    ),
    "apple_resource_group": (
        _RESOURCE_ASPECT_ADDITIONAL_RESOURCE_RULE_ATTRS + _RESOURCE_ASPECT_BASE_ATTRS
    ),
}

def _propagation_attrs(ctx):
    """Returns the set of attributes to propagate for the resource aspect."""

    # The resource rules get their own handling here.
    qualified_kind = ctx.rule.qualified_kind
    expected_label = _SUPPORTED_QUALIFIED_KINDS.get(qualified_kind.rule_name)
    if expected_label and str(qualified_kind.file_label) == expected_label:
        return _SUPPORTED_QUALIFIED_KINDS_PROPAGATION_ATTRS[qualified_kind.rule_name]

    # Always support data and cc_library derived deps-like attributes for resource propagation.
    return _RESOURCE_ASPECT_BASE_ATTRS

def _platform_prerequisites_for_aspect(target, aspect_ctx):
    """Return the set of platform prerequisites that can be determined from this aspect."""
    apple_xplat_toolchain_info = apple_toolchain_utils.get_xplat_toolchain(aspect_ctx)
    cpp_fragment = aspect_ctx.fragments.cpp
    deps_and_target = getattr(aspect_ctx.rule.attr, "deps", []) + [target]
    uses_swift = swift_support.uses_swift(deps_and_target)

    return platform_support.platform_prerequisites(
        apple_platform_info = platform_support.apple_platform_info_from_rule_ctx(aspect_ctx),
        build_settings = apple_xplat_toolchain_info.build_settings,
        config_vars = aspect_ctx.var,
        explicit_minimum_os = cpp_fragment.minimum_os_version(),
        objc_fragment = None,
        uses_swift = uses_swift,
        xcode_version_config = aspect_ctx.attr._xcode_config[XcodeVersionInfo],
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
        "apple_xplat_toolchain_info": apple_toolchain_utils.get_xplat_toolchain(ctx),
        "bundle_id": None,
        "mac_exec_group": apple_toolchain_utils.get_mac_exec_group(ctx),
        "product_type": None,
        "rule_label": ctx.label,
        "xplat_exec_group": apple_toolchain_utils.get_xplat_exec_group(ctx),
    }

    collect_infoplists_args = dict()
    collect_args = dict()
    collect_structured_args = dict()
    collect_bundle_imports_args = dict()

    # Owner to attach to the resources as they're being bucketed.
    owner = None

    # The name of the bundle directory to place resources within, if required.
    bundle_name = None

    if ctx.rule.kind == "objc_library":
        collect_args["res_attrs"] = ["data"]

        # Only set objc_library targets as owners if they have srcs, non_arc_srcs, deps, or
        # implementation_deps. This treats objc_library targets without sources as resource
        # aggregators, which are functionally equivalent to "resources" on apple_resource_group
        # targets.
        for attr in ["srcs", "non_arc_srcs", "deps", "implementation_deps"]:
            if getattr(ctx.rule.attr, attr):
                owner = str(ctx.label)
                break

    elif SwiftInfo in target:
        module_names = set(
            [x.name for x in target[SwiftInfo].direct_modules if x.swift],
        )
        bucketize_args["swift_module"] = module_names.pop() if module_names else None
        collect_args["res_attrs"] = ["data"]
        owner = str(ctx.label)

    elif AppleResourceGroupInfo in target:
        collect_args["res_attrs"] = ["resources"]
        collect_structured_args["res_attrs"] = ["structured_resources"]

    elif AppleResourceBundleInfo in target:
        collect_infoplists_args["res_attrs"] = ["infoplists"]
        collect_args["res_attrs"] = ["resources"]
        collect_structured_args["res_attrs"] = ["structured_resources"]
        bundle_name = "{}.bundle".format(ctx.rule.attr.bundle_name or ctx.label.name)

    elif AppleBundleImportInfo in target:
        collect_bundle_imports_args["res_attrs"] = ["bundle_imports"]

    if AppleResourceExplicitFilesInfo in target:
        explicit_files_info = target[AppleResourceExplicitFilesInfo]
        explicit_files = explicit_files_info.files
        if type(explicit_files) == "depset":
            explicit_files = explicit_files.to_list()
        apple_resource_infos.append(
            resources.bucketize_typed(
                bucket_type = "unprocessed",
                expect_files = True,
                resources = explicit_files,
            ),
        )

    # Assign the provider deps once we have the resource attributes sorted out.
    provider_deps = set(_RESOURCE_ASPECT_BASE_ATTRS + collect_args.get("res_attrs", []))

    # Collect all resource files related to this target.
    if collect_infoplists_args:
        infoplists = resources.collect(
            attr = ctx.rule.attr,
            rule_label = ctx.label,
            **collect_infoplists_args
        )
        if infoplists:
            bucketized_owners, unowned_resources, buckets = resources.bucketize_typed_data(
                bucket_type = "infoplists",
                owner = owner,
                parent_dir_param = bundle_name,
                resources = infoplists,
            )
            apple_resource_infos.append(
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
            rule_label = ctx.label,
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
            rule_label = ctx.label,
            **collect_structured_args
        )
        if structured_files:
            if bundle_name:
                structured_parent_dir_param = (
                    lambda *args, **kwargs: resources.structured_resources_parent_dir(
                        parent_dir = bundle_name,
                        *args,
                        **kwargs
                    )
                )
            else:
                structured_parent_dir_param = (
                    lambda *args, **kwargs: resources.structured_resources_parent_dir(
                        *args,
                        **kwargs
                    )
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
                    unowned_resources = unowned_resources,
                    **process_args
                ),
            )

    if collect_bundle_imports_args:
        bundle_imports_files = resources.collect(
            attr = ctx.rule.attr,
            rule_label = ctx.label,
            **collect_bundle_imports_args
        )
        if bundle_imports_files:
            bundle_imports_parent_dir_param = (
                lambda *args, **kwargs: resources.bundle_relative_parent_dir(
                    extension = "bundle",
                    *args,
                    **kwargs
                )
            )

            apple_resource_infos.append(
                resources.bucketize_typed(
                    bucket_type = "unprocessed",
                    parent_dir_param = bundle_imports_parent_dir_param,
                    resources = bundle_imports_files,
                ),
            )

    # Get the providers from dependencies, referenced by deps and locations for resources.
    apple_resource_validation_infos = []
    apple_linkmap_infos = []
    apple_dsym_bundle_infos = []
    inherited_apple_resource_infos = []
    for attr in provider_deps:
        if hasattr(ctx.rule.attr, attr):
            targets = getattr(ctx.rule.attr, attr)
            for target in targets:
                if AppleFrameworkBundleInfo in target:
                    if AppleBundleInfo in target:
                        # Create a reference to the AppleBundleInfo for any rules that output a
                        # framework bundle for validation in the top level bundling rule.
                        #
                        # Further, we want to track the source of this AppleBundleInfo for logging
                        # via the rule label. Otherwise we won't be able to get at the target/label
                        # later.
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

                    if AppIntentsBundleInfo in target:
                        fail("""
An App Intents metadata bundle was found in the following framework that is not directly loaded by \
an app/extension:

- {framework_target}

This was loaded by the following library target:

- {loading_target}

App Intents are not supported within frameworks that aren't directly loaded by an app/extension.
                        """.format(
                            loading_target = str(ctx.label),
                            framework_target = str(target.label),
                        ))

                if AppleFrameworkBundleInfo not in target and AppleResourceInfo in target:
                    # Propagate the AppleResourceInfo for non-AppleFrameworkBundleInfo targets, to
                    # avoid propagating resources that should not be extended beyond the framework.
                    inherited_apple_resource_infos.append(target[AppleResourceInfo])

                # Propagate AppleLinkMapInfo and AppleDsymBundleInfo providers from deps/resources
                # referenced dependencies required for the debug_symbols bundling task. This will
                # often start from frameworks.
                if AppleLinkmapInfo in target:
                    apple_linkmap_infos.append(target[AppleLinkmapInfo])

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

    if apple_linkmap_infos:
        providers.append(
            new_applelinkmapinfo(
                direct_linkmaps = [],
                transitive_linkmaps = depset(
                    transitive = [x.transitive_linkmaps for x in apple_linkmap_infos],
                ),
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
    attr_aspects = _propagation_attrs,
    attrs = apple_support.action_required_attrs() |
            apple_support.platform_constraint_attrs(),
    exec_groups = apple_toolchain_utils.use_apple_exec_group_toolchain(),
    fragments = ["cpp"],
    doc = """
Aspect that collects and propagates transitive `AppleResourceInfo` providers to allow for resources
to be bundled by a top-level Apple bundling rule.

Supported resource-providing rules are:

*   `objc_library`
*   `swift_library`
*   `apple_bundle_import`
*   `apple_resource_group`
*   `apple_resource_bundle`
""",
)
