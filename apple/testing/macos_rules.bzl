# Copyright 2017 The Bazel Authors. All rights reserved.
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

"""Bazel rules for macOS tests."""

load(
    "@build_bazel_rules_apple//apple/bundling:binary_support.bzl",
    "binary_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:product_support.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/bundling:rule_factory.bzl",
    "rule_factory",
)
load(
    "@build_bazel_rules_apple//apple/internal/aspects:framework_import_aspect.bzl",
    "framework_import_aspect",
)
load(
    "@build_bazel_rules_apple//apple/internal/testing:macos_rules.bzl",
    "macos_test_bundle_impl",
)
load(
    "@build_bazel_rules_apple//apple/testing:apple_test_rules.bzl",
    "apple_ui_test",
    "apple_unit_test",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
)
load(
    "@build_bazel_rules_apple//apple:utils.bzl",
    "full_label",
)

_macos_test_bundle = rule_factory.make_bundling_rule(
    macos_test_bundle_impl,
    additional_attrs = {
        "dedupe_unbundled_resources": attr.bool(default = True),
        # The test host that will run these tests. Optional.
        "test_host": attr.label(providers = [AppleBundleInfo], aspects = [framework_import_aspect]),
    },
    archive_extension = ".zip",
    binary_providers = [apple_common.AppleLoadableBundleBinary],
    # When running tests, non-logic test bundles are expected to be embedded
    # inside an application bundle. But because of how bazel expects test
    # targets to be organized, the application target does not have a reference
    # to the test target. Therefore, whichever frameworks that are only used by
    # the test binary need to be embedded inside the test bundle, so we set
    # bundles_frameworks to True, and implementation of the rule should
    # deduplicate frameworks that are already present in the test host.
    bundles_frameworks = True,
    bundle_id_attr_mode = rule_factory.attribute_modes.OPTIONAL,
    code_signing = rule_factory.code_signing(
        ".provisionprofile",
        requires_signing_for_device = False,
    ),
    device_families = rule_factory.device_families(allowed = ["mac"]),
    path_formats = rule_factory.macos_path_formats(path_in_archive_format = "%s"),
    platform_type = apple_common.platform_type.macos,
    # The real value will be force by the macro when it invokes this.
    product_type = rule_factory.product_type(
        "",
        values = [
            apple_product_type.ui_test_bundle,
            apple_product_type.unit_test_bundle,
        ],
    ),
)

def _macos_test(
        name,
        product_type,
        bundle_id = None,
        bundle_loader = None,
        dedupe_unbundled_resources = None,
        infoplists = [
            "@build_bazel_rules_apple//apple/testing:DefaultTestBundlePlist",
        ],
        linkopts = [],
        minimum_os_version = None,
        runner = None,
        test_host = None,
        test_rule = None,
        deps = [],
        **kwargs):
    """Macro that routes the external macro arguments into the correct targets.

    This macro creates 3 targets:

    * name + ".apple_binary": Represents the binary that contains the test code. It
        captures the deps and test_host arguments.
    * name + "_test_bundle": Represents the xctest bundle that contains the binary
        along with the test resources. It captures the bundle_id and infoplists
        arguments.
    * name: The actual test target that can be invoked with `bazel test`. This
        target takes all the remaining arguments passed.
    """
    if "platform_type" in kwargs:
        fail("platform_type is not allowed as an attribute to macos_unit_test " +
             "and macos_ui_test")

    test_bundle_name = name + "_test_bundle"

    linkopts = [
        # TODO(b/62481675): Move these rpath flags into crosstool features.
        "-rpath",
        "@executable_path/../Frameworks",
        "-rpath",
        "@loader_path/../Frameworks",
    ] + linkopts

    # back door to support tags on the apple_binary for systems that
    # collect binaries from a package as they see this (and tag
    # can control that collection).
    binary_tags = kwargs.pop("binary_tags", [])

    bundling_args = binary_support.create_linked_binary_target(
        name = name,
        binary_type = "loadable_bundle",
        bundle_loader = bundle_loader,
        linkopts = linkopts,
        minimum_os_version = minimum_os_version,
        platform_type = "macos",
        sdk_frameworks = ["XCTest"],
        suppress_entitlements = True,
        target_name_template = "%s_test_binary",
        tags = binary_tags,
        testonly = 1,
        visibility = ["//visibility:private"],
        deps = deps,
    )

    _macos_test_bundle(
        name = test_bundle_name,
        bundle_id = bundle_id,
        bundle_name = name,
        dedupe_unbundled_resources = dedupe_unbundled_resources,
        infoplists = infoplists,
        product_type = product_type,
        test_host = test_host,
        **bundling_args
    )

    test_rule(
        name = name,
        platform_type = "macos",
        runner = runner,
        test_bundle = test_bundle_name,
        test_host = test_host,
        **kwargs
    )

def macos_unit_test(
        name,
        **kwargs):
    args = dict(kwargs)
    test_host = args.get("test_host", None)
    bundle_loader = None
    if test_host:
        bundle_loader = full_label(test_host) + ".apple_binary"

    _macos_test(
        name = name,
        product_type = apple_product_type.unit_test_bundle,
        bundle_loader = bundle_loader,
        test_rule = apple_unit_test,
        **kwargs
    )

def macos_ui_test(
        name,
        **kwargs):
    _macos_test(
        name = name,
        product_type = apple_product_type.ui_test_bundle,
        test_rule = apple_ui_test,
        **kwargs
    )
