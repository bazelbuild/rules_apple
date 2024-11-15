# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Implementation of tvOS test rules."""

load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/internal:bundling_support.bzl",
    "bundle_id_suffix_default",
)
load(
    "@build_bazel_rules_apple//apple/internal:providers.bzl",
    "AppleBundleInfo",
    "TvosApplicationBundleInfo",
    "TvosFrameworkBundleInfo",
    "new_tvosxctestbundleinfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_attrs.bzl",
    "rule_attrs",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_factory.bzl",
    "rule_factory",
)
load(
    "@build_bazel_rules_apple//apple/internal:transition_support.bzl",
    "transition_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/aspects:framework_provider_aspect.bzl",
    "framework_provider_aspect",
)
load(
    "@build_bazel_rules_apple//apple/internal/aspects:resource_aspect.bzl",
    "apple_resource_aspect",
)
load(
    "@build_bazel_rules_apple//apple/internal/testing:apple_test_bundle_support.bzl",
    "apple_test_bundle_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/testing:apple_test_rule_support.bzl",
    "apple_test_rule_support",
)

visibility("@build_bazel_rules_apple//apple/...")

_TVOS_TEST_HOST_PROVIDERS = [[AppleBundleInfo, TvosApplicationBundleInfo]]

def _tvos_ui_test_bundle_impl(ctx):
    """Implementation of tvos_ui_test."""
    return apple_test_bundle_support.apple_test_bundle_impl(
        ctx = ctx,
        product_type = apple_product_type.ui_test_bundle,
    ) + [
        new_tvosxctestbundleinfo(),
    ]

def _tvos_unit_test_bundle_impl(ctx):
    """Implementation of tvos_unit_test."""
    return apple_test_bundle_support.apple_test_bundle_impl(
        ctx = ctx,
        product_type = apple_product_type.unit_test_bundle,
    ) + [
        new_tvosxctestbundleinfo(),
    ]

def _tvos_ui_test_impl(ctx):
    """Implementation of tvos_ui_test."""
    return apple_test_rule_support.apple_test_rule_impl(
        ctx = ctx,
        requires_dossiers = False,
        test_type = "xcuitest",
    ) + [
        new_tvosxctestbundleinfo(),
    ]

def _tvos_unit_test_impl(ctx):
    """Implementation of tvos_unit_test."""
    return apple_test_rule_support.apple_test_rule_impl(
        ctx = ctx,
        requires_dossiers = False,
        test_type = "xctest",
    ) + [
        new_tvosxctestbundleinfo(),
    ]

# Declare it with an underscore to hint that this is an implementation detail in bazel query-s.
_tvos_internal_ui_test_bundle = rule_factory.create_apple_rule(
    cfg = transition_support.apple_rule_transition,
    doc = "Builds and bundles an tvOS UI Test Bundle. Internal target not to be depended upon.",
    implementation = _tvos_ui_test_bundle_impl,
    predeclared_outputs = {"archive": "%{name}.zip"},
    attrs = [
        apple_support.platform_constraint_attrs(),
        rule_attrs.binary_linking_attrs(
            base_cfg = transition_support.apple_rule_transition,
            deps_cfg = transition_support.apple_platform_split_transition,
            extra_deps_aspects = [
                apple_resource_aspect,
                framework_provider_aspect,
            ],
            is_test_supporting_rule = True,
            requires_legacy_cc_toolchain = True,
        ),
        rule_attrs.cc_toolchain_forwarder_attrs(
            deps_cfg = transition_support.apple_platform_split_transition,
        ),
        rule_attrs.common_bundle_attrs(),
        rule_attrs.common_tool_attrs(),
        rule_attrs.device_family_attrs(
            allowed_families = rule_attrs.defaults.allowed_families.tvos,
            is_mandatory = False,
        ),
        rule_attrs.infoplist_attrs(
            default_infoplist = rule_attrs.defaults.test_bundle_infoplist,
        ),
        rule_attrs.platform_attrs(
            add_environment_plist = True,
            platform_type = "tvos",
        ),
        rule_attrs.signing_attrs(
            default_bundle_id_suffix = bundle_id_suffix_default.bundle_name,
            supports_capabilities = False,
        ),
        rule_attrs.test_bundle_attrs(),
        rule_attrs.test_host_attrs(
            aspects = rule_attrs.aspects.test_host_aspects,
            is_mandatory = True,
            providers = _TVOS_TEST_HOST_PROVIDERS,
        ),
        {
            "frameworks": attr.label_list(
                providers = [[AppleBundleInfo, TvosFrameworkBundleInfo]],
                doc = """
A list of framework targets (see
[`tvos_framework`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-tvos.md#tvos_framework))
that this target depends on.
""",
            ),
        },
    ],
)

# Alias to import it.
tvos_internal_ui_test_bundle = _tvos_internal_ui_test_bundle

tvos_ui_test = rule_factory.create_apple_test_rule(
    doc = "tvOS UI Test rule.",
    implementation = _tvos_ui_test_impl,
    platform_type = "tvos",
)

# Declare it with an underscore so it shows up that way in queries.
_tvos_internal_unit_test_bundle = rule_factory.create_apple_rule(
    cfg = transition_support.apple_rule_transition,
    doc = "Builds and bundles an tvOS Unit Test Bundle. Internal target not to be depended upon.",
    implementation = _tvos_unit_test_bundle_impl,
    predeclared_outputs = {"archive": "%{name}.zip"},
    attrs = [
        apple_support.platform_constraint_attrs(),
        rule_attrs.binary_linking_attrs(
            base_cfg = transition_support.apple_rule_transition,
            deps_cfg = transition_support.apple_platform_split_transition,
            extra_deps_aspects = [
                apple_resource_aspect,
                framework_provider_aspect,
            ],
            is_test_supporting_rule = True,
            requires_legacy_cc_toolchain = True,
        ),
        rule_attrs.cc_toolchain_forwarder_attrs(
            deps_cfg = transition_support.apple_platform_split_transition,
        ),
        rule_attrs.common_bundle_attrs(),
        rule_attrs.common_tool_attrs(),
        rule_attrs.device_family_attrs(
            allowed_families = rule_attrs.defaults.allowed_families.tvos,
            is_mandatory = False,
        ),
        rule_attrs.infoplist_attrs(
            default_infoplist = rule_attrs.defaults.test_bundle_infoplist,
        ),
        rule_attrs.platform_attrs(
            add_environment_plist = True,
            platform_type = "tvos",
        ),
        rule_attrs.signing_attrs(
            default_bundle_id_suffix = bundle_id_suffix_default.bundle_name,
            supports_capabilities = False,
        ),
        rule_attrs.test_bundle_attrs(),
        rule_attrs.test_host_attrs(
            aspects = rule_attrs.aspects.test_host_aspects,
            providers = _TVOS_TEST_HOST_PROVIDERS,
        ),
        {
            "frameworks": attr.label_list(
                providers = [[AppleBundleInfo, TvosFrameworkBundleInfo]],
                doc = """
A list of framework targets (see
[`tvos_framework`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-tvos.md#tvos_framework))
that this target depends on.
""",
            ),
        },
    ],
)

# Alias to import it.
tvos_internal_unit_test_bundle = _tvos_internal_unit_test_bundle

tvos_unit_test = rule_factory.create_apple_test_rule(
    doc = "tvOS Unit Test rule.",
    implementation = _tvos_unit_test_impl,
    platform_type = "tvos",
)
