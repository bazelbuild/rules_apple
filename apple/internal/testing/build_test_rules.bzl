# Copyright 2020 The Bazel Authors. All rights reserved.
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

"""Rules for writing build tests for libraries that target Apple platforms."""

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
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
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
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "AppleBinaryInfo",
    "AppleBundleInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_attrs.bzl",
    "rule_attrs",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_support.bzl",
    "rule_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:swift_support.bzl",
    "swift_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:transition_support.bzl",
    "transition_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/aspects:resource_aspect.bzl",
    "apple_resource_aspect",
)
load(
    "@build_bazel_rules_apple//apple/internal/toolchains:apple_toolchains.bzl",
    "apple_toolchain_utils",
)

visibility("@build_bazel_rules_apple//apple/...")

_PASSING_TEST_SCRIPT = """\
#!/bin/bash
exit 0
"""

# These providers mark major Apple targets that already contain transitions so
# there is no reason for a `PLATFORM_build_test` to wrap one of these, instead
# a plan `build_test` should be used.
_BLOCKED_PROVIDERS = [
    AppleBinaryInfo,
    AppleBundleInfo,
]

def _apple_build_test_rule_impl(ctx):
    if ctx.attr.platform_type != ctx.attr._platform_type:
        fail((
            "The 'platform_type' attribute of '{}' is an implementation " +
            "detail and will be removed in the future; do not change it."
        ).format(ctx.attr._platform_type + "_build_test"))

    targets = ctx.attr.targets
    for target in targets:
        for p in _BLOCKED_PROVIDERS:
            if p in target:
                fail((
                    "'{target_label}' builds a bundle and should just be " +
                    " wrapped with a 'build_test' and not '{rule_kind}'."
                ).format(
                    target_label = target.label,
                    rule_kind = ctx.attr._platform_type + "_build_test",
                ))

    # Simulate an application bundle for building resources.
    rule_descriptor = rule_support.rule_descriptor(
        platform_type = ctx.attr.platform_type,
        product_type = apple_product_type.application,
    )

    platform_prerequisites = platform_support.platform_prerequisites(
        apple_fragment = ctx.fragments.apple,
        apple_platform_info = platform_support.apple_platform_info_from_rule_ctx(ctx),
        build_settings = apple_toolchain_utils.get_xplat_toolchain(ctx).build_settings,
        config_vars = ctx.var,
        cpp_fragment = ctx.fragments.cpp,
        explicit_minimum_os = ctx.attr.minimum_os_version,
        objc_fragment = ctx.fragments.objc,
        uses_swift = swift_support.uses_swift(ctx.attr.targets),
        xcode_version_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig],
    )

    resource_artifacts = partial.call(partials.resources_partial(
        actions = ctx.actions,
        apple_mac_toolchain_info = apple_toolchain_utils.get_mac_toolchain(ctx),
        avoid_root_infoplist = True,
        mac_exec_group = apple_toolchain_utils.get_mac_exec_group(ctx),
        bundle_extension = ".app",
        bundle_name = ctx.label.name + "_build_test",
        environment_plist = ctx.file._environment_plist,
        platform_prerequisites = platform_prerequisites,
        resource_deps = ctx.attr.targets,
        resource_locales = None,
        rule_descriptor = rule_descriptor,
        rule_label = ctx.label,
        version = None,
        version_keys_required = False,
    ))

    transitive_files = [target[DefaultInfo].files for target in targets]
    if hasattr(resource_artifacts, "bundle_files"):
        for _, _, files in resource_artifacts.bundle_files:
            transitive_files.append(files)

    # The test's executable is a vacuously passing script. We pass all of the
    # default outputs from the list of targets as the test's runfiles, so as
    # long as they all build successfully, the entire test will pass.
    ctx.actions.write(
        content = _PASSING_TEST_SCRIPT,
        output = ctx.outputs.executable,
        is_executable = True,
    )

    return [DefaultInfo(
        executable = ctx.outputs.executable,
        runfiles = ctx.runfiles(
            transitive_files = depset(transitive = transitive_files),
        ),
    )]

def apple_build_test_rule(doc, platform_type):
    """Creates and returns an Apple build test rule for the given platform.

    Args:
        doc: The documentation string for the rule.
        platform_type: The Apple platform for which the test should build its
            targets (`"ios"`, `"macos"`, `"tvos"`, `"watchos"`, or `"visionos"`).

    Returns:
        The created `rule`.
    """
    return rule(
        attrs = dicts.add(
            apple_support.platform_constraint_attrs(),
            rule_attrs.common_attrs(),
            rule_attrs.platform_attrs(
                platform_type = platform_type,
                add_environment_plist = True,
            ),
            {
                "_platform_type": attr.string(
                    default = platform_type,
                    doc = "The platform type for which the test should build its targets.",
                ),
                "targets": attr.label_list(
                    allow_empty = False,
                    aspects = [apple_resource_aspect],
                    cfg = transition_support.apple_platform_split_transition,
                    doc = "The targets to check for successful build.",
                ),
            },
        ),
        doc = doc,
        fragments = [
            "apple",
            "cpp",
            "objc",
        ],
        exec_groups = apple_toolchain_utils.use_apple_exec_group_toolchain(),
        implementation = _apple_build_test_rule_impl,
        test = True,
        cfg = transition_support.apple_rule_transition,
    )
