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

load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

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

    disabled_features = ctx.disabled_features
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
)
