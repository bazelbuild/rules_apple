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

load("@build_bazel_rules_apple//apple:providers.bzl",
     "AppleBundleInfo",
     "MacosXcTestBundleInfo")
load("@build_bazel_rules_apple//apple:utils.bzl",
     "full_label",
     "merge_dictionaries")
load("@build_bazel_rules_apple//apple/bundling:apple_bundling_aspect.bzl",
     "apple_bundling_aspect")
load("@build_bazel_rules_apple//apple/bundling:binary_support.bzl", "binary_support")
load("@build_bazel_rules_apple//apple/bundling:bundler.bzl",
     "bundler")
load("@build_bazel_rules_apple//apple/bundling:product_support.bzl",
     "apple_product_type")
load("@build_bazel_rules_apple//apple/bundling:rule_factory.bzl",
     "rule_factory")
load("@build_bazel_rules_apple//apple/testing:apple_test_rules.bzl",
     "apple_unit_test",
     "apple_ui_test")


def _macos_test_bundle_impl(ctx):
  """Implementation for the _macos_test_bundle rule."""
  bundle_id = None
  test_host_bundle_id = None

  if ctx.attr.test_host:
    host_bundle_info = ctx.attr.test_host[AppleBundleInfo]
    test_host_bundle_id = host_bundle_info.bundle_id
    bundle_id = test_host_bundle_id + "Tests"
  if ctx.attr.bundle_id:
    bundle_id = ctx.attr.bundle_id

  if not bundle_id:
    fail("Bundle identifier missing. You need to either provide a bundle_id " +
         "or a sensible test_host.")

  if bundle_id == test_host_bundle_id:
    fail("The test bundle's identifier of '" + bundle_id + "' can't be the " +
         "same as the test host's bundle identifier. Please change one of " +
         "them.")

  binary_artifact = binary_support.get_binary_provider(
      ctx, apple_common.AppleLoadableBundleBinary).binary
  additional_providers, legacy_providers, additional_outputs = bundler.run(
      ctx,
      "MacOSTestArchive", "MacOSTest",
      bundle_id,
      binary_artifact=binary_artifact)
  return struct(
      files=additional_outputs,
      instrumented_files=struct(dependency_attributes=["binary", "test_host"]),
      providers=[
          MacosXcTestBundleInfo(),
      ] + additional_providers,
      **legacy_providers
  )


_macos_test_bundle = rule_factory.make_bundling_rule(
    _macos_test_bundle_impl,
    additional_attrs={
        # Override of the common_rule_attributes() bundle_id attribute in
        # order to make it optional. Bundle identifier for the
        # _macos_test_bundle output.
        "bundle_id": attr.string(),
        # The test host that will run these tests. Optional.
        "test_host": attr.label(providers=[AppleBundleInfo]),
    },
    archive_extension=".zip",
    binary_providers=[apple_common.AppleLoadableBundleBinary],
    code_signing=rule_factory.code_signing(
        ".provisionprofile",
        requires_signing_for_device=False
    ),
    device_families=rule_factory.device_families(allowed=["mac"]),
    path_formats=rule_factory.macos_path_formats(path_in_archive_format="%s"),
    platform_type=apple_common.platform_type.macos,
    # The empty string will be overridden by the wrapping macros.
    product_type=rule_factory.product_type(""),
)


def _macos_test(name,
                product_type,
                bundle_id=None,
                bundle_loader=None,
                infoplists=[
                    "@build_bazel_rules_apple//apple/testing:DefaultTestBundlePlist",
                ],
                minimum_os_version=None,
                runner=None,
                test_host=None,
                test_rule=None,
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
  test_binary_name = name + "_test_binary"
  test_bundle_name = name + "_test_bundle"

  # TODO(b/64032879): Cleanup this framework include path.
  linkopts = [
      "-F__BAZEL_XCODE_DEVELOPER_DIR__/Platforms/MacOSX.platform/Developer/Library/Frameworks"]

  native.apple_binary(
      name = test_binary_name,
      binary_type = "loadable_bundle",
      bundle_loader = bundle_loader,
      linkopts = linkopts,
      minimum_os_version = minimum_os_version,
      platform_type = "macos",
      sdk_frameworks = ["XCTest"],
      testonly = 1,
      visibility = ["//visibility:private"],
      deps = deps,
  )

  _macos_test_bundle(
      name = test_bundle_name,
      binary = ":" + test_binary_name,
      bundle_id = bundle_id,
      bundle_name = name,
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
      test_bundle = test_bundle_name,
      test_host = test_host,
      runner = runner,
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
