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

"""Support for product types used by Apple bundling rules.

This file should be loaded by the top-level Apple platform .bzl files
(ios.bzl, watchos.bzl, and so forth) and should export *only* the
`apple_product_type` struct so that BUILD files can import it through there
and access the constants in their own targets.
"""

load(
    "@build_bazel_rules_apple//apple/bundling:attribute_support.bzl",
    "attribute_support",
)


apple_product_type = struct(
    application="com.apple.product-type.application",
    app_extension="com.apple.product-type.app-extension",
    framework="com.apple.product-type.framework",
    messages_application="com.apple.product-type.application.messages",
    messages_extension="com.apple.product-type.app-extension.messages",
    messages_sticker_pack_extension=(
        "com.apple.product-type.app-extension.messages-sticker-pack"),
    ui_test_bundle="com.apple.product-type.bundle.ui-testing",
    unit_test_bundle="com.apple.product-type.bundle.unit-test",
    watch2_application="com.apple.product-type.application.watchapp2",
    watch2_extension="com.apple.product-type.watchkit2-extension",
)
"""
Product type identifiers used by special application and extension types.

Some applications and extensions, such as iMessage applications and
sticker packs in iOS 10, receive special treatment when building (for example,
bundling a stub executable instead of a user-defined binary, or extra arguments
passed to tools like the asset compiler). These behaviors are captured in the
product type identifier. The product types currently supported are:

* `application`: A basic iOS, macOS, or tvOS application. This is the default
  product type for those targets; it can be overridden with a more specific
  product type if needed.
* `app_extension`: A basic iOS, macOS, or tvOS application extension. This is
  the default product type for those targets; it can be overridden with a more
  specific product type if needed.
* `framework`: A basic dynamic framework. This is the default product type for
  those targets; it does not need to be set explicitly (and cannot be changed).
* `messages_application`: An application that integrates with the Messages
  app (iOS 10 and above). This application must include an `ios_extension`
  with the `messages_extension` or `messages_sticker_pack_extension` product
  type (or both extensions). This product type does not contain a user-provided
  binary.
* `messages_extension`: An extension that integrates custom code/behavior into
  a Messages application. This product type should contain a user-provided
  binary.
* `messages_sticker_pack_extension`: An extension that defines custom sticker
  packs for the Messages app. This product type does not contain a
  user-provided binary.
* `ui_test_bundle`: A UI testing bundle (.xctest). This is the default product
  type for those targets; it does not need to be set explicitly (and cannot be
  changed).
* `unit_test_bundle`: A unit test bundle (.xctest). This is the default product
  type for those targets; it does not need to be set explicitly (and cannot be
  changed).
* `watch2_application`: A watchOS 2+ application. This is the default product
  type for those targets; it does not need to be set explicitly (and cannot be
  changed).
* `watch2_extension`: A watchOS 2+ application extension. This is the default
  product type for those targets; it does not need to be set explicitly (and
  cannot be changed).
"""


# Watch applications and some iOS extensions (like message sticker packs) do
# not include source code of their own and require stub binaries copied in from
# the platform SDK. See the docstring for `_stub_binary_info_for_target` for
# the meaning of these struct fields.
_PRODUCT_TYPE_INFO_MAP = {
    apple_product_type.messages_application: struct(
        stub_path=("$(PLATFORM_DIR)/Library/Application Support/" +
                   "MessagesApplicationStub/MessagesApplicationStub"),
        archive_path=("MessagesApplicationSupport/" +
                      "MessagesApplicationSupportStub"),
        bundle_path=None,
        additional_infoplist_values={
            "LSApplicationLaunchProhibited": True,
        },
    ),
    apple_product_type.messages_sticker_pack_extension: struct(
        stub_path=("$(PLATFORM_DIR)/Library/Application Support/" +
                   "MessagesApplicationExtensionStub/" +
                   "MessagesApplicationExtensionStub"),
        archive_path=("MessagesApplicationExtensionSupport/" +
                      "MessagesApplicationExtensionSupportStub"),
        bundle_path=None,
        additional_infoplist_values={
            "LSApplicationIsStickerPack": True,
        },
    ),
    apple_product_type.watch2_application: struct(
        stub_path="$(SDKROOT)/Library/Application Support/WatchKit/WK",
        archive_path="WatchKitSupport2/WK",
        bundle_path="_WatchKitStub/WK",
        additional_infoplist_values=None,
    ),
}


def _product_type(ctx):
  """Returns the product type identifier for the current target.

  Args:
    ctx: The Skylark context.
  Returns:
    The product type identifier for the current target, or None if there is
    none.
  """
  return attribute_support.get(ctx.attr, "product_type")


def _product_type_info(product_type):
  """Returns the stub binary info for the given product type.

  Args:
    product_type: The product type.
  Returns:
    The info about the stub executable, or None if the target's product type
    does not use a stub executable (meaning it requires a user binary). If not
    None, the returned value is a struct with the following fields:

    * `stub_path`, which is the path (prefixed with an environment variable
      like `${SDKROOT}`) from which the stub should be copied;
    * `archive_path`, which is the support path at the archive root at which
      the stub should be placed; and
    * `bundle_path`, which is an additional bundle-relative location where the
      stub should be copied (in addition to the bundle's binary itself).
    * `additional_infoplist_values`, which is a dictionary of additional
      key/value pairs that should be merged into the Info.plist for a bundle
      with this product type.
  """
  return _PRODUCT_TYPE_INFO_MAP.get(product_type)


def _product_type_info_for_target(ctx):
  """Returns the stub binary info for a target's product type.

  Args:
    ctx: The Skylark context.
  Returns:
    The info about the stub executable, or None if the target's product type
    does not use a stub executable (meaning it requires a user binary). If not
    None, the returned value is a struct with the following fields:

    * `file`, which is the path (prefixed with an environment variable like
      `${SDKROOT}`) from which the stub should be copied;
    * `archive_path`, which is the support path at the archive root at which
      the stub should be placed; and
    * `bundle_path`, which is an additional bundle-relative location where the
      stub should be copied (in addition to the bundle's binary itself).
  """
  product_type = _product_type(ctx)
  if product_type:
    return _product_type_info(product_type)
  return None


# Define the loadable module that lists the exported symbols in this file.
product_support = struct(
    product_type=_product_type,
    product_type_info=_product_type_info,
    product_type_info_for_target=_product_type_info_for_target,
)
