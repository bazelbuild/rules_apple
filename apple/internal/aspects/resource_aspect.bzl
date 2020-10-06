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

def _apple_resource_aspect_impl(target, ctx):
    """Implementation of the resource propation aspect."""

    # If the target already propagates a AppleResourceInfo, do nothing.
    if AppleResourceInfo in target:
        return []

    providers = []

    bucketize_args = {}
    collect_args = {}

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

    # Collect all resource files related to this target.
    files = resources.collect(ctx.rule.attr, **collect_args)
    if files:
        deps = getattr(ctx.attr, "deps", None)
        uses_swift = swift_support.uses_swift(deps) if deps else False

        # TODO(b/161370390): Support device_families when rule_descriptor can be accessed from an
        # aspect, or the list of allowed device families can be determined independently of the
        # rule_descriptor.
        platform_prerequisites = platform_support.platform_prerequisites(
            apple_fragment = ctx.fragments.apple,
            config_vars = ctx.var,
            device_families = None,
            explicit_minimum_os = getattr(ctx.attr, "minimum_os_version", None),
            objc_fragment = None,
            platform_type_string = str(ctx.fragments.apple.single_arch_platform.platform_type),
            uses_swift = uses_swift,
            xcode_path_wrapper = ctx.executable._xcode_path_wrapper,
            xcode_version_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
        )
        providers.append(
            resources.bucketize_with_processing(
                actions = ctx.actions,
                bundle_id = getattr(ctx.attr, "bundle_id", None),
                owner = owner,
                platform_prerequisites = platform_prerequisites,
                product_type = getattr(ctx.attr, "_product_type", None),
                resources = files,
                rule_executables = ctx.rule.executable,
                rule_label = ctx.label,
                **bucketize_args
            ),
        )

    # Get the providers from dependencies.
    for attr in ["deps", "data"]:
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
    attr_aspects = ["bundles", "data", "deps"],
    attrs = apple_support.action_required_attrs(),
    fragments = ["apple"],
    doc = """Aspect that collects and propagates resource information to be bundled by a top-level
bundling rule.""",
)
