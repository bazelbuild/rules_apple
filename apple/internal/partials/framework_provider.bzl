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

"""Partial implementation for AppleDynamicFrameworkInfo configuration."""

load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("//apple/internal:providers.bzl", "new_appledynamicframeworkinfo")

def _framework_provider_partial_impl(
        *,
        actions,
        binary_artifact,
        bundle_only,
        cc_configured_features_init,
        cc_info,
        cc_toolchain,
        disabled_features,
        features,
        rule_label):
    """Implementation for the framework provider partial."""

    feature_configuration = cc_configured_features_init(
        cc_toolchain = cc_toolchain,
        language = "objc",
        requested_features = features,
        unsupported_features = disabled_features,
    )
    library_to_link = cc_common.create_library_to_link(
        actions = actions,
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        dynamic_library = binary_artifact,
    )
    linker_input = cc_common.create_linker_input(
        owner = rule_label,
        libraries = depset([] if bundle_only else [library_to_link]),
    )
    wrapper_cc_info = cc_common.merge_cc_infos(
        cc_infos = [
            CcInfo(
                linking_context = cc_common.create_linking_context(
                    linker_inputs = depset(direct = [linker_input]),
                ),
            ),
            cc_info,
        ],
    )

    framework_provider = new_appledynamicframeworkinfo(
        cc_info = wrapper_cc_info,
    )

    return struct(
        providers = [framework_provider],
    )

def framework_provider_partial(
        *,
        actions,
        binary_artifact,
        bundle_only,
        cc_configured_features_init,
        cc_info,
        cc_toolchain,
        disabled_features,
        features,
        rule_label):
    """Constructor for the framework provider partial.

    This partial propagates the AppleDynamicFrameworkInfo provider required by
    the linking step. It contains the necessary files and configuration so that
    the framework can be linked against. This is only required for dynamic
    framework bundles.

    Args:
      actions: The actions provider from `ctx.actions`.
      binary_artifact: The linked dynamic framework binary.
      bundle_only: Only include the bundle but do not link the framework
      cc_configured_features_init: A lambda that is the same as cc_common.configure_features(...)
          without the need for a `ctx`.
      cc_info: The CcInfo provider containing information about the
          targets linked into the dynamic framework.
      cc_toolchain: The C++ toolchain to use.
      disabled_features: List of features to be disabled for C++ actions.
      features: List of features to be enabled for C++ actions.
      rule_label: The label of the target being analyzed.

    Returns:
      A partial that returns the AppleDynamicFrameworkInfo provider used to link
      this framework into the final binary.

    """
    return partial.make(
        _framework_provider_partial_impl,
        actions = actions,
        binary_artifact = binary_artifact,
        bundle_only = bundle_only,
        cc_configured_features_init = cc_configured_features_init,
        cc_info = cc_info,
        cc_toolchain = cc_toolchain,
        disabled_features = disabled_features,
        features = features,
        rule_label = rule_label,
    )
