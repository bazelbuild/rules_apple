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


def _macos_test_bundle_impl(ctx):
  """Implementation for the _macos_test_bundle rule."""
  return apple_test_bundle_support.apple_test_bundle_impl(
      ctx,
      "MacOSTestArchive",
      "MacOSTest",
      [MacosXcTestBundleInfo()],
  )


_macos_test_bundle = rule_factory.make_bundling_rule(
    _macos_test_bundle_impl,
    additional_attrs={
        # The test host that will run these tests. Optional.
        "test_host": attr.label(providers=[AppleBundleInfo]),
    },
    archive_extension=".zip",
    binary_providers=[apple_common.AppleLoadableBundleBinary],
    bundle_id_attr_mode=rule_factory.attribute_modes.OPTIONAL,
    code_signing=rule_factory.code_signing(
        ".provisionprofile",
        requires_signing_for_device=False
    ),
    device_families=rule_factory.device_families(allowed=["mac"]),
    path_formats=rule_factory.macos_path_formats(path_in_archive_format="%s"),
    platform_type=apple_common.platform_type.macos,
    # The real value will be force by the macro when it invokes this.
    product_type=rule_factory.product_type(
       "",
       values=[
         apple_product_type.ui_test_bundle,
         apple_product_type.unit_test_bundle,
       ],
    ),
)


def _macos_test(name,
                product_type,
                bundle_id=None,
                bundle_loader=None,
                infoplists=[
                    "@build_bazel_rules_apple//apple/testing:DefaultTestBundlePlist",
                ],
                linkopts=None,
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
  * name: The actual test target that can be invoked with `bazel test`. This
      target takes all the remaining arguments passed.
  """
  if "platform_type" in kwargs:
    fail("platform_type is not allowed as an attribute to macos_unit_test " +
         "and macos_ui_test")

  test_binary_name = name + "_test_binary"
  test_bundle_name = name + "_test_bundle"

  linkopts = [
      # TODO(b/62481675): Move these rpath flags into crosstool features.
      "-rpath", "@executable_path/../Frameworks",
      "-rpath", "@loader_path/../Frameworks",
  ] + (linkopts or [])

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
