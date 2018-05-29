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

"""Bazel rules for iOS tests."""

load("@build_bazel_rules_apple//apple:providers.bzl",
     "AppleBundleInfo",
     "IosXcTestBundleInfo")
load("@build_bazel_rules_apple//apple:utils.bzl",
     "full_label")
load("@build_bazel_rules_apple//apple/bundling:product_support.bzl",
     "apple_product_type")
load("@build_bazel_rules_apple//apple/bundling:rule_factory.bzl",
     "rule_factory")
load("@build_bazel_rules_apple//apple/testing:apple_test_rules.bzl",
     "apple_unit_test",
     "apple_ui_test")
load("@build_bazel_rules_apple//apple/testing:apple_test_bundle_support.bzl",
     "apple_test_bundle_support")


def _ios_test_bundle_impl(ctx):
  """Implementation for the _ios_test_bundle rule."""
  return apple_test_bundle_support.apple_test_bundle_impl(
      ctx,
      "IosTestArchive",
      "IosTest",
      [IosXcTestBundleInfo()],
  )


_ios_test_bundle = rule_factory.make_bundling_rule(
    _ios_test_bundle_impl,
    additional_attrs={
        "dedupe_unbundled_resources": attr.bool(default=True),
        # The test host that will run these tests. Optional.
        "test_host": attr.label(mandatory=False, providers=[AppleBundleInfo]),
    },
    archive_extension=".zip",
    binary_providers=[apple_common.AppleLoadableBundleBinary],
    bundle_id_attr_mode=rule_factory.attribute_modes.OPTIONAL,
    # When running tests, non-logic test bundles are expected to be embedded
    # inside an application bundle. But because of how bazel expects test
    # targets to be organized, the application target does not have a reference
    # to the test target. Therefore, whichever frameworks that are only used by
    # the test binary need to be embedded inside the test bundle, so we set
    # bundles_frameworks to True, and implementation of the rule should
    # deduplicate frameworks that are already present in the test host.
    bundles_frameworks=True,
    code_signing=rule_factory.code_signing(
        ".mobileprovision",
        # Disable signing for devices, as this rule will most likely be used
        # by Xcode/Tulsi in some capacity, which will usually resign it anyways,
        # which means we can save some time off when building.
        requires_signing_for_device=False,
        skip_simulator_signing_allowed=False
    ),
    device_families=rule_factory.device_families(
        allowed=["iphone", "ipad"],
        mandatory=False,
    ),
    path_formats=rule_factory.simple_path_formats("%s"),
    platform_type=apple_common.platform_type.ios,
    # The real value will be force by the macro when it invokes this.
    product_type=rule_factory.product_type(
       "",
       values=[
         apple_product_type.ui_test_bundle,
         apple_product_type.unit_test_bundle,
       ],
    ),
)


def _ios_test(name,
              product_type,
              bundle_id=None,
              bundle_loader=None,
              dedupe_unbundled_resources=None,
              infoplists=[
                  "@build_bazel_rules_apple//apple/testing:DefaultTestBundlePlist",
              ],
              linkopts=None,
              minimum_os_version=None,
              runner=None,
              test_rule=None,
              test_host=None,
              deps=[],
              **kwargs):
  """Macro that routes the external macro arguments into the correct targets.

  This macro creates 3 targets:

  * name + "_test_binary": Represents the binary that contains the test code. It
      captures the deps and test_host arguments.
  * name + "_test_bundle": Represents the xctest bundle that contains the binary
      along with the test resources. It captures the bundle_id and infoplists
      arguments.
  * name: The actual test target that can be invoked with `bazel test`. This
      target takes all the remaining arguments passed.
  """
  if "platform_type" in kwargs:
    fail("platform_type is not allowed as an attribute to ios_unit_test and " +
         "ios_ui_test")

  test_binary_name = name + "_test_binary"
  test_bundle_name = name + "_test_bundle"

  # TODO(b/38350264): Remove these linkopts once bazel adds the
  # @loader_path/Frameworks rpath by default.
  if not bundle_loader:
    linkopts = ["-rpath", "@loader_path/Frameworks"] + (linkopts or [])

  # back door to support tags on the apple_binary for systems that
  # collect binaries from a package as they see this (and tag
  # can control that collection).
  binary_tags = kwargs.pop("binary_tags", [])

  native.apple_binary(
      name = test_binary_name,
      deps = deps,
      sdk_frameworks = ["XCTest"],
      binary_type = "loadable_bundle",
      bundle_loader = bundle_loader,
      minimum_os_version = minimum_os_version,
      platform_type = "ios",
      visibility = ["//visibility:private"],
      linkopts = linkopts,
      testonly = 1,
      tags = binary_tags,
  )

  _ios_test_bundle(
      name = test_bundle_name,
      binary = ":" + test_binary_name,
      bundle_name = name,
      bundle_id = bundle_id,
      dedupe_unbundled_resources = dedupe_unbundled_resources,
      infoplists = infoplists,
      minimum_os_version = minimum_os_version,
      product_type = product_type,
      test_host = test_host,
      testonly = 1,
      visibility = ["//visibility:private"],
      deps = [":" + test_binary_name],
  )

  test_rule(
      name = name,
      platform_type="ios",
      runner = runner,
      test_host = test_host,
      test_bundle = test_bundle_name,
      **kwargs)


def ios_unit_test(
    name,
    runner = "@build_bazel_rules_apple//apple/testing/default_runner:ios_default_runner",
    test_host = None,
    **kwargs):
  bundle_loader = None
  if test_host:
    bundle_loader = full_label(test_host) + ".apple_binary"
  _ios_test(
      name=name,
      product_type=apple_product_type.unit_test_bundle,
      bundle_loader=bundle_loader,
      runner=runner,
      test_rule=apple_unit_test,
      test_host=test_host,
      **kwargs
  )


def ios_ui_test(
    name,
    runner = "@build_bazel_rules_apple//apple/testing/default_runner:ios_default_runner",
    **kwargs):
  _ios_test(
      name = name,
      product_type = apple_product_type.ui_test_bundle,
      runner = runner,
      test_rule = apple_ui_test,
      **kwargs
  )
