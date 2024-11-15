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

"""Partial implementation for validating the AppleBundleInfo providers found in child bundles."""

load(
    "@bazel_skylib//lib:partial.bzl",
    "partial",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/internal/providers:apple_resource_validation_info.bzl",
    "AppleResourceValidationInfo",
)

visibility("@build_bazel_rules_apple//apple/...")

def compare_min_os(
        *,
        check_less_than,
        rule_label,
        rule_min_os,
        target_label,
        target_min_os,
        target_type):
    """Compare minimum_os_versions between the rule and target and report if changes should be made.

    Args:
        check_less_than: Boolean. Indicates if a lower `minimum_os_version` on the target should be
            reported as a non-fatal warning. This is useful for application targets that should set
            the absolute baseline minimum OS version for the rest of the app bundle to support, but
            should not be used for extensions and app clips that can have a higher
            `minimum_os_version` than the rest of the application.
        rule_label: The `Label` of the rule being built.
        rule_min_os: String. The string from the rule's `minimum_os_version` attribute.
        target_label: String. The label of the target being checked against the rule.
        target_min_os: String. A dotted version compatible representation of the target's
            `minimum_os_version`.
        target_type: String. A string to describe the type of target being checked. Should be user
            readable and all lower case with spaces, like "framework" or "extension" or "app clip".
    """
    if apple_common.dotted_version(rule_min_os) < apple_common.dotted_version(target_min_os):
        fail("""
ERROR: minimum_os_version {target_min_os} on the {target_type} {target_label} is too high compared to {rule_label}'s minimum_os_version of {rule_min_os}

Please address the minimum_os_version on {target_type} {target_label} to match {rule_label}'s minimum_os_version.
""".format(
            target_label = target_label,
            target_min_os = target_min_os,
            target_type = target_type,
            rule_min_os = rule_min_os,
            rule_label = rule_label,
        ))
    elif (check_less_than and
          apple_common.dotted_version(rule_min_os) > apple_common.dotted_version(target_min_os)):
        # There is no other way to issue a warning, so print is the only way to message.
        # buildifier: disable=print
        print("""
WARNING: minimum_os_version {target_min_os} on the {target_type} {target_label} is too low compared to {rule_label}'s minimum_os_version of {rule_min_os}

Consider addressing the minimum_os_version on {target_type} {target_label} to match {rule_label}'s minimum_os_version.
""".format(
            target_label = target_label,
            target_min_os = target_min_os,
            target_type = target_type,
            rule_min_os = rule_min_os,
            rule_label = rule_label,
        ))

def _child_bundle_info_validation_partial_impl(
        *,
        frameworks,
        platform_prerequisites,
        product_type,
        resource_validation_infos,
        rule_label):
    """Implementation for the child bundle info validation partial."""

    if frameworks or resource_validation_infos:
        target_type = "framework"
        check_less_than = False

        if product_type == apple_product_type.application:
            check_less_than = True

        for framework in frameworks:
            compare_min_os(
                check_less_than = check_less_than,
                target_label = framework.label,
                target_min_os = framework[AppleBundleInfo].minimum_os_version,
                target_type = target_type,
                rule_label = rule_label,
                rule_min_os = platform_prerequisites.minimum_os,
            )

        for resource_validation_info in resource_validation_infos:
            if AppleResourceValidationInfo in resource_validation_info:
                resource_validation_info = resource_validation_info[AppleResourceValidationInfo]
                target_bundle_infos = resource_validation_info.transitive_target_bundle_infos
                for target_bundle_info in target_bundle_infos.to_list():
                    apple_bundle_info = target_bundle_info.apple_bundle_info
                    compare_min_os(
                        check_less_than = check_less_than,
                        target_label = target_bundle_info.target_label,
                        target_min_os = apple_bundle_info.minimum_os_version,
                        target_type = target_type,
                        rule_label = rule_label,
                        rule_min_os = platform_prerequisites.minimum_os,
                    )

    return struct()

def child_bundle_info_validation_partial(
        *,
        frameworks,
        platform_prerequisites,
        product_type,
        resource_validation_infos,
        rule_label):
    """Constructor for the child bundle info validation partial.

    This partial validates that the bundle info found within child bundles aligns with the current
    target. A common validation is to check for minimum OS version to make sure that the framework
    version is not less than the current target.

    Some exceptional cases may temporarily exist for bundles that have minimum OS versions that
    must be higher than the given framework, i.e. extensions sharing a framework with applications.
    In this case, we warn, rather than fail.

    Args:
        frameworks: List of frameworks representing child bundles to validate for `AppleBundleInfo`
            instances. These should come from the `frameworks` attribute as well as
            `AppleBundleInfo` instances collected from framework rules in the resource aspect of
            `deps`.
        platform_prerequisites: Struct containing information on the platform being targeted.
        product_type: Product type identifier used to describe the current bundle type.
        resource_validation_infos: List of potential AppleResourceValidationInfo providers
            signalling child bundles with sources referenced via `deps` or a resource-aligned
            attribute.
        rule_label: The label of the target being analyzed.

    Returns:
        A partial that validates the AppleBundleInfo of all child bundles against its parent.
    """
    return partial.make(
        _child_bundle_info_validation_partial_impl,
        frameworks = frameworks,
        platform_prerequisites = platform_prerequisites,
        product_type = product_type,
        resource_validation_infos = resource_validation_infos,
        rule_label = rule_label,
    )
