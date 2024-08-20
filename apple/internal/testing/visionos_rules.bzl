# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""Implementation of visionOS test rules."""

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
    "VisionosApplicationBundleInfo",
    "new_visionosxctestbundleinfo",
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

visibility("//apple/...")

_VISIONOS_TEST_HOST_PROVIDERS = [[AppleBundleInfo, VisionosApplicationBundleInfo]]

def _visionos_unit_test_bundle_impl(ctx):
    """Implementation of visionos_unit_test."""
    return apple_test_bundle_support.apple_test_bundle_impl(
        ctx = ctx,
        product_type = apple_product_type.unit_test_bundle,
    ) + [
        new_visionosxctestbundleinfo(),
    ]

def _visionos_unit_test_impl(ctx):
    """Implementation of visionos_unit_test."""
    return apple_test_rule_support.apple_test_rule_impl(
        ctx = ctx,
        requires_apple_silicon = True,
        requires_dossiers = True,
        test_type = "xctest",
    ) + [
        new_visionosxctestbundleinfo(),
    ]

# Declare it with an underscore so it shows up that way in queries.
_visionos_internal_unit_test_bundle = rule_factory.create_apple_rule(
    cfg = transition_support.apple_platforms_rule_bundle_output_base_transition,
    doc = "Builds and bundles a visionOS Unit Test Bundle. Internal target not to be depended on.",
    implementation = _visionos_unit_test_bundle_impl,
    # TODO(b/288582842): Currently needed to supply a "dummy archive" for the tree artifact
    # processor. See if we can avoid needing to declare this hack for a new rule type.
    predeclared_outputs = {"archive": "%{name}.zip"},
    attrs = [
        apple_support.platform_constraint_attrs(),
        rule_attrs.binary_linking_attrs(
            base_cfg = transition_support.apple_platforms_rule_bundle_output_base_transition,
            deps_cfg = transition_support.apple_platform_split_transition,
            extra_deps_aspects = [
                apple_resource_aspect,
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
            allowed_families = rule_attrs.defaults.allowed_families.visionos,
            is_mandatory = False,
        ),
        rule_attrs.infoplist_attrs(
            default_infoplist = rule_attrs.defaults.test_bundle_infoplist,
        ),
        rule_attrs.platform_attrs(
            add_environment_plist = True,
            platform_type = "visionos",
        ),
        rule_attrs.signing_attrs(
            default_bundle_id_suffix = bundle_id_suffix_default.bundle_name,
            supports_capabilities = False,
        ),
        rule_attrs.test_bundle_attrs(),
        rule_attrs.test_host_attrs(
            aspects = rule_attrs.aspects.test_host_aspects,
            providers = _VISIONOS_TEST_HOST_PROVIDERS,
        ),
    ],
)

# Alias to import it.
visionos_internal_unit_test_bundle = _visionos_internal_unit_test_bundle

visionos_unit_test = rule_factory.create_apple_test_rule(
    cfg = transition_support.apple_rule_force_macos_cpus_arm64_transition,
    doc = "visionOS Unit Test rule.",
    implementation = _visionos_unit_test_impl,
    platform_type = "visionos",
)
