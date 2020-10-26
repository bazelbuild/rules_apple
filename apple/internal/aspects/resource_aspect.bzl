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
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)

def _platform_prerequisites_for_aspect(target, aspect_ctx):
    """Return the set of platform prerequisites that can be determined from this aspect."""
    deps_and_target = getattr(aspect_ctx.rule.attr, "deps", []) + [target]
    uses_swift = swift_support.uses_swift(deps_and_target)

    # TODO(b/161370390): Support device_families when rule_descriptor can be accessed from an
    # aspect, or the list of allowed device families can be determined independently of the
    # rule_descriptor.
    return platform_support.platform_prerequisites(
        apple_fragment = aspect_ctx.fragments.apple,
        config_vars = aspect_ctx.var,
        device_families = None,
        explicit_minimum_os = None,
        objc_fragment = None,
        platform_type_string = str(aspect_ctx.fragments.apple.single_arch_platform.platform_type),
        uses_swift = uses_swift,
        xcode_path_wrapper = aspect_ctx.executable._xcode_path_wrapper,
        xcode_version_config = aspect_ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
    )

def _apple_resource_aspect_impl(target, ctx):
    """Implementation of the resource propation aspect."""

    # If the target already propagates a AppleResourceInfo, do nothing.
    if AppleResourceInfo in target:
        return []

    providers = []
    bucketize_args = {
        "actions": ctx.actions,
        "bundle_id": None,
        "product_type": None,
        "rule_executables": ctx.executable,
        "rule_label": ctx.label,
    }
    collect_args = {}
    collect_structured_args = {}

    # Owner to attach to the resources as they're being bucketed.
    owner = None

    if ctx.rule.kind == "objc_library":
        collect_args["res_attrs"] = ["data"]

        # Only set objc_library targets as owners if they have srcs, non_arc_srcs or deps. This
        # treats objc_library targets without sources as resource aggregators.
        if ctx.rule.attr.srcs or ctx.rule.attr.non_arc_srcs or ctx.rule.attr.deps:
            owner = str(ctx.label)

    elif ctx.rule.kind == "swift_library":
        bucketize_args["swift_module"] = target[SwiftInfo].module_name
        collect_args["res_attrs"] = ["data"]
        owner = str(ctx.label)

    elif ctx.rule.kind == "apple_resource_group":
        collect_args["res_attrs"] = ["resources"]
        collect_structured_args["res_attrs"] = ["structured_resources"]

    # Collect all resource files related to this target.
    resource_files = resources.collect(ctx.rule.attr, **collect_args)
    if resource_files:
        providers.append(
            resources.bucketize_with_processing(
                owner = owner,
                platform_prerequisites = _platform_prerequisites_for_aspect(target, ctx),
                resources = resource_files,
                **bucketize_args
            ),
        )

    if collect_structured_args:
        # `structured_resources` requires an explicit parent directory, requiring them to be
        # processed differently from `resources` and resources inherited from other fields.
        #
        # `structured_resources` also does not support propagating resource providers from
        # apple_resource_group or apple_bundle_import targets, unlike `resources`. If a target is
        # referenced by `structured_resources` that already propagates a resource provider, it will
        # be ignored.
        structured_files = resources.collect(ctx.rule.attr, **collect_structured_args)
        if structured_files:
            # Avoid processing PNG files that are referenced through the structured_resources
            # attribute. This is mostly for legacy reasons and should get cleaned up in the future.
            structured_resources_provider = resources.bucketize_with_processing(
                allowed_buckets = ["strings", "plists"],
                owner = owner,
                parent_dir_param = partial.make(
                    resources.structured_resources_parent_dir,
                ),
                platform_prerequisites = _platform_prerequisites_for_aspect(target, ctx),
                resources = structured_files,
                **bucketize_args
            )
            providers.append(structured_resources_provider)

    # Get the providers from dependencies, referenced by deps and locations for resources.
    provider_deps = ["deps"] + collect_args.get("res_attrs", [])
    for attr in provider_deps:
        if hasattr(ctx.rule.attr, attr):
            providers.extend([
                x[AppleResourceInfo]
                for x in getattr(ctx.rule.attr, attr)
                if AppleResourceInfo in x
            ])

    if providers:
        # If any providers were collected, merge them.
        return [resources.merge_providers(providers, default_owner = owner)]
    return []

apple_resource_aspect = aspect(
    implementation = _apple_resource_aspect_impl,
    attr_aspects = ["data", "deps", "resources", "structured_resources"],
    attrs = apple_support.action_required_attrs(),
    fragments = ["apple"],
    doc = """Aspect that collects and propagates resource information to be bundled by a top-level
bundling rule.""",
)
