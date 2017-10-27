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
     "full_label",
     "merge_dictionaries")
load("@build_bazel_rules_apple//apple/bundling:binary_support.bzl", "binary_support")
load("@build_bazel_rules_apple//apple/bundling:bundler.bzl",
     "bundler")
load("@build_bazel_rules_apple//apple/bundling:product_support.bzl",
     "apple_product_type")
load("@build_bazel_rules_apple//apple/bundling:rule_factory.bzl",
     "rule_factory")
load("@build_bazel_rules_apple//common:providers.bzl",
    "providers")
load("@build_bazel_rules_apple//apple/testing:apple_test_rules.bzl",
     "apple_unit_test",
     "apple_ui_test")


def _ios_test_bundle_impl(ctx):
  """Implementation for the _ios_test_bundle rule."""
  host_bundle_info = ctx.attr.test_host[AppleBundleInfo]
  bundle_id = host_bundle_info.bundle_id + "Tests"
  if ctx.attr.bundle_id:
    bundle_id = ctx.attr.bundle_id

  if not bundle_id:
    fail("Bundle identifier missing. You need to either provide a test_host " +
         "or a bundle_id.")

  if bundle_id == host_bundle_info.bundle_id:
    fail("The test bundle's identifier of '" + bundle_id + "' can't be the " +
         "same as the test host's bundle identifier. Please change one of " +
         "them.")

  binary_artifact = binary_support.get_binary_provider(
      ctx.attr.deps, apple_common.AppleLoadableBundleBinary).binary
  deps_objc_providers = providers.find_all(ctx.attr.deps, "objc")
  additional_providers, legacy_providers, additional_outputs = bundler.run(
      ctx,
      "IosTestArchive", "IosTest",
      bundle_id,
      binary_artifact=binary_artifact,
      deps_objc_providers=deps_objc_providers,
  )
  return struct(
      files=additional_outputs,
      instrumented_files=struct(dependency_attributes=["binary", "test_host"]),
      providers=[
          IosXcTestBundleInfo(),
      ] + additional_providers,
      **legacy_providers
  )


_ios_test_bundle = rule_factory.make_bundling_rule(
    _ios_test_bundle_impl,
    additional_attrs={
        # Override of the common_rule_attributes() bundle_id attribute in
        # order to make it optional. Bundle identifier for the
        # _ios_test_bundle output.
        "bundle_id": attr.string(),
        # The test host that will run these tests. This is required in order to
        # obtain a sensible default for the tests bundle identifier.
        "test_host": attr.label(mandatory=True, providers=[AppleBundleInfo]),
    },
    # TODO(b/34774324): Rename to zip.
    archive_extension=".ipa",
    binary_providers=[apple_common.AppleLoadableBundleBinary],
    code_signing=rule_factory.code_signing(
        ".mobileprovision",
        requires_signing_for_device=False
    ),
    device_families=rule_factory.device_families(
        allowed=["iphone", "ipad"],
        mandatory=False,
    ),
    needs_pkginfo=False,
    path_formats=rule_factory.simple_path_formats("Payload/%s"),
    platform_type=apple_common.platform_type.ios,
    # The empty string will be overridden by the wrapping macros.
    product_type=rule_factory.product_type(""),
)


def _ios_test(name,
              product_type,
              bundle_id=None,
              bundle_loader=None,
              infoplists=[
                  "@build_bazel_rules_apple//apple/testing:DefaultTestBundlePlist",
              ],
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
  * name: The actual test target that can be invoked with `blaze test`. This
      target takes all the remaining arguments passed.
  """
  if "platform_type" in kwargs:
    fail("platform_type is not allowed as an attribute to ios_unit_test and " +
         "ios_ui_test")

  test_binary_name = name + "_test_binary"
  test_bundle_name = name + "_test_bundle"

  # TODO(b/38350264): Remove these linkopts once bazel adds the
  # @loader_path/Frameworks rpath by default.
  linkopts = None
  if not bundle_loader:
    linkopts = ["-rpath", "@loader_path/Frameworks"]

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
      deps = [":" + test_binary_name],
      bundle_name = name,
      bundle_id = bundle_id,
      infoplists = infoplists,
      minimum_os_version = minimum_os_version,
      product_type = product_type,
      test_host = test_host,
      testonly = 1,
      visibility = ["//visibility:private"],
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
    test_host = "@build_bazel_rules_apple//apple/testing/default_host/ios",
    **kwargs):
  bundle_loader = full_label(test_host) + ".apple_binary"
  _ios_test(
      name = name,
      product_type = apple_product_type.unit_test_bundle,
      bundle_loader = bundle_loader,
      runner = runner,
      test_rule = apple_unit_test,
      test_host = test_host,
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
