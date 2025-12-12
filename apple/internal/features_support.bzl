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

"""Support macros to assist in detecting build features."""

load(
    "@build_bazel_rules_apple//apple/internal/utils:package_specs.bzl",
    "label_matches_package_specs",
)
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

def _validate_feature_usage(*, label, toolchain, requested_features, unsupported_features):
    """Checks the toolchain's allowlists to verify the requested features.

    If any of the features requested to be enabled or disabled is not allowed in
    the target's package by one of the allowlists, the build will fail with an
    error message indicating the feature and the allowlist that denied it.

    Args:
        toolchain: Either the mac or xplat toolchain to be used for the allowlists to check.
        label: The label of the target being checked against the allowlist.
        requested_features: The list of features to be enabled. This is
            typically obtained using the `ctx.features` field in a rule
            implementation function.
        unsupported_features: The list of features that are unsupported by the
            current rule. This is typically obtained using the
            `ctx.disabled_features` field in a rule implementation function.
    """
    features_to_check = list(requested_features)
    features_to_check.extend(
        ["-{}".format(feature) for feature in unsupported_features],
    )

    for allowlist in toolchain.feature_allowlists:
        for feature_string in features_to_check:
            # Any feature not managed by the allowlist is allowed by default.
            if feature_string not in allowlist.managed_features:
                continue

            if not label_matches_package_specs(
                label = label,
                package_specs = allowlist.package_specs,
            ):
                fail((
                    "Use of '{feature}' is not allowed to be set by the " +
                    "target '{target}'; see the allowlist at '{allowlist}' " +
                    "for more information."
                ).format(
                    allowlist = allowlist.allowlist_label,
                    feature = feature_string,
                    target = str(label),
                ))

def _cc_configured_features(
        *,
        ctx,
        extra_requested_features = None,
        extra_disabled_features = None):
    """Captures the rule ctx for a deferred `cc_common.configure_features(...)` call.

    Args:
      ctx: The rule context, expected to be captured directly in the rule context and NOT within a
        partial or helper method.
      extra_requested_features: An optional list of additional features requested.
      extra_disabled_features: An optional list of additional features to disable.

    Returns:
      A struct with the following fields:

        * configure_features: A lambda that has the captured instance of the rule context, which
            will always set that rule context as the `ctx` argument of
            `cc_common.configure_features(...)` and will forward any arguments additional it is
            given to `cc_common.configure_features(...)`.
        * enabled_features: The set of features that are enabled after taking into account the
            requested and disabled features. This is not taking the cc_toolchain's supported
            features into account; use `cc_common.is_enabled(...)` for that instead.
        * requested_features: The value computed for `cc_common.configure_features(...)`'s
            `requested_features` from args above.
        * unsupported_features: The value computed for `cc_common.configure_features(...)`'s
            `unsupported_features` from args above.
    """
    features = ctx.features
    if extra_requested_features:
        features += extra_requested_features

    disabled_features = ctx.disabled_features + [
        # Disabled include scanning (b/321109350) to work around issues with GrepIncludes actions
        # being routed to the wrong exec platform.
        "cc_include_scanning",
        # Disabled parse_headers (b/174937981) to avoid validating headers from top-level Apple
        # rules (i.e. legacy uses of ios_framework). Those headers are expected to be as public API
        # i.e. a "swiftinterface" equivalent for (Objective-)C(++) frameworks and are not expected
        # to build in any given Bazel WORKSPACE.
        #
        # TODO: b/251214758 - Re-enable parse_headers once 3P framework users establish interfaces
        # via a more stable means, as was done for generated interfaces in Swift.
        "parse_headers",
    ]
    if extra_disabled_features:
        disabled_features += extra_disabled_features

    enabled_features_set = set(features)
    enabled_features_set.difference_update(disabled_features)

    return struct(
        configure_features = lambda *args, **kwargs: cc_common.configure_features(
            ctx = ctx,
            requested_features = features,
            unsupported_features = disabled_features,
            *args,
            **kwargs
        ),
        enabled_features = enabled_features_set,
        requested_features = features,
        unsupported_features = disabled_features,
    )

features_support = struct(
    cc_configured_features = _cc_configured_features,
    validate_feature_usage = _validate_feature_usage,
)
