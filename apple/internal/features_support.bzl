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
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

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
)
