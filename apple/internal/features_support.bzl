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

load("@bazel_skylib//lib:new_sets.bzl", "sets")
load(
    "@build_bazel_rules_apple//apple/internal/utils:package_specs.bzl",
    "label_matches_package_specs",
)

visibility([
    "@build_bazel_rules_apple//apple/...",
    "@build_bazel_rules_apple//test/...",
])

def _compute_enabled_features(*, requested_features, unsupported_features):
    """Returns a list of features for the given build.

    Args:
      requested_features: A list of features requested. Typically from `ctx.features`.
      unsupported_features: A list of features to ignore. Typically from `ctx.disabled_features`.

    Returns:
      A list containing the subset of features that should be used.
    """
    enabled_features_set = sets.make(requested_features)
    enabled_features_set = sets.difference(
        enabled_features_set,
        sets.make(unsupported_features),
    )
    return sets.to_list(enabled_features_set)

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

def _make_cc_configured_features_init(ctx):
    """Captures the rule ctx for a deferred `cc_common.configure_features(...)` call.

    Args:
      ctx: The rule context, expected to be captured directly in the rule context and NOT within a
        partial or helper method.

    Returns:
      A lambda that has the captured instance of the rule context, which will always set that rule
        context as the `ctx` argument of `cc_common.configure_features(...)` and will forward any
        arguments it is given to `cc_common.configure_features(...)`.
    """
    return lambda *args, **kwargs: cc_common.configure_features(ctx = ctx, *args, **kwargs)

features_support = struct(
    compute_enabled_features = _compute_enabled_features,
    make_cc_configured_features_init = _make_cc_configured_features_init,
    validate_feature_usage = _validate_feature_usage,
)
