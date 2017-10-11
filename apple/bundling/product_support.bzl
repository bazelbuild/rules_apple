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
    "@build_bazel_rules_apple//common:attrs.bzl",
    "attrs",
)


apple_product_type = struct(
    application="com.apple.product-type.application",
    app_extension="com.apple.product-type.app-extension",
    bundle="com.apple.product-type.bundle",
    framework="com.apple.product-type.framework",
    kernel_extension="com.apple.product-type.kernel-extension",
    messages_application="com.apple.product-type.application.messages",
    messages_extension="com.apple.product-type.app-extension.messages",
    messages_sticker_pack_extension=(
        "com.apple.product-type.app-extension.messages-sticker-pack"),
    spotlight_importer="com.apple.product-type.spotlight-importer",
    static_framework="com.apple.product-type.framework.static",
    tool="com.apple.product-type.tool",
    ui_test_bundle="com.apple.product-type.bundle.ui-testing",
    unit_test_bundle="com.apple.product-type.bundle.unit-test",
    watch2_application="com.apple.product-type.application.watchapp2",
    watch2_extension="com.apple.product-type.watchkit2-extension",
    xpc_service="com.apple.product-type.xpc-service",
)
"""
Product type identifiers used to describe various bundle types.

The "product type" is a concept used internally by Xcode (the strings themselves
are visible inside the `.pbxproj` file) that describes properties of the bundle,
such as its default extension.

Additionally, products like iMessage applications and sticker packs in iOS 10
require a stub executable instead of a user-defined binary and additional values
injected into their `Info.plist` files. These behaviors are also captured in the
product type identifier. The product types currently supported are:

* `application`: A basic iOS, macOS, or tvOS application. This is the default
  product type for those targets; it can be overridden with a more specific
  product type if needed.
* `app_extension`: A basic iOS, macOS, or tvOS application extension. This is
  the default product type for those targets; it can be overridden with a more
  specific product type if needed.
* `bundle`: A loadable macOS bundle. This is the default product type for
  `macos_bundle` targets; it can be overridden with a more specific product type
  if needed.
* `framework`: A basic dynamic framework. This is the default product type for
  those targets; it does not need to be set explicitly (and cannot be changed).
* `kernel_extension`: A macOS kernel extension. This product type should be used
  with a `macos_bundle` target to create such a plug-in; the built bundle will
  have the extension `.kext`.
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
* `spotlight_importer`: A macOS Spotlight importer plug-in. This product type
  should be used with a `macos_bundle` target to create such a plug-in; the
  built bundle will have the extension `.mdimporter`.
* `static_framework`: An iOS static framework, which is a `.framework` bundle
  that contains resources and headers but a static library instead of a dynamic
  library.
* `tool`: A command-line tool. This is the default product type for
  `macos_command_line_application`; it does not need to be set explicitly (and
  cannot be changed).
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
* `xpc_service`: A macOS XPC service. This product type should be used with a
  `macos_application` target to create such a service; the built bundle will
  have the extension `.xpc`.
"""


def _describe_stub(xcenv_based_path,
                   path_in_archive,
                   additional_bundle_path=None):
  """Returns a struct suitable for the `stub` field of a product type struct.

  Args:
    xcenv_based_path: The Xcode-environment-based path from which the stub
        binary should be copied (rooted at either `$(SDKROOT)` or
        `$(PLATFORM_DIR)`).
    path_in_archive: The path relative to the root of a top-level application
        archive where the stub should be copied as a support file.
    additional_bundle_path: A path relative to the bundle where the stub binary
        should be copied, *in addition to* the standard location of the
        executable.
  Returns:
    A struct suitable for the `stub` field of a product type struct.
  """
  return struct(xcenv_based_path=xcenv_based_path,
                path_in_archive=path_in_archive,
                additional_bundle_path=additional_bundle_path)


def _describe_product_type(bundle_extension,
                           additional_infoplist_values={},
                           stub=None):
  """Returns a new product type descriptor.

  Args:
    bundle_extension: The default extension for bundles with this product type,
        which will be used if not overridden on the target. The extension
        includes the leading dot.
    additional_infoplist_values: Any additional keys and values that should be
        added to the `Info.plist` for bundles with this product type.
    stub: A descriptor returned by `_stub_descriptor` that contains information
        about the stub binary for the bundle, if any.
  Returns:
    A new product type descriptor.
  """
  return struct(bundle_extension=bundle_extension,
                additional_infoplist_values=additional_infoplist_values,
                stub=stub)


# Descriptors for the various product types.
_PRODUCT_TYPE_DESCRIPTORS = {
    apple_product_type.application: _describe_product_type(
        bundle_extension=".app",
    ),
    apple_product_type.app_extension: _describe_product_type(
        bundle_extension=".appex",
    ),
    apple_product_type.bundle: _describe_product_type(
        bundle_extension=".bundle",
    ),
    apple_product_type.framework: _describe_product_type(
        bundle_extension=".framework",
    ),
    apple_product_type.kernel_extension: _describe_product_type(
        bundle_extension=".kext",
    ),
    apple_product_type.messages_application: _describe_product_type(
        bundle_extension=".app",
        additional_infoplist_values={"LSApplicationLaunchProhibited": True},
        stub=_describe_stub(
            xcenv_based_path=("$(PLATFORM_DIR)/Library/Application Support/" +
                              "MessagesApplicationStub/" +
                              "MessagesApplicationStub"),
            path_in_archive=("MessagesApplicationSupport/" +
                             "MessagesApplicationSupportStub"),
        ),
    ),
    apple_product_type.messages_extension: _describe_product_type(
        bundle_extension=".appex",
    ),
    apple_product_type.messages_sticker_pack_extension: _describe_product_type(
        bundle_extension=".appex",
        additional_infoplist_values={"LSApplicationIsStickerPack": True},
        stub=_describe_stub(
            xcenv_based_path=("$(PLATFORM_DIR)/Library/Application Support/" +
                              "MessagesApplicationExtensionStub/" +
                              "MessagesApplicationExtensionStub"),
            path_in_archive=("MessagesApplicationExtensionSupport/" +
                             "MessagesApplicationExtensionSupportStub"),
        ),
    ),
    apple_product_type.spotlight_importer: _describe_product_type(
        bundle_extension=".mdimporter",
    ),
    apple_product_type.static_framework: _describe_product_type(
        bundle_extension=".framework",
    ),
    apple_product_type.tool: _describe_product_type(
        bundle_extension="",
    ),
    apple_product_type.ui_test_bundle: _describe_product_type(
        bundle_extension=".xctest",
    ),
    apple_product_type.unit_test_bundle: _describe_product_type(
        bundle_extension=".xctest",
    ),
    apple_product_type.watch2_application: _describe_product_type(
        bundle_extension=".app",
        stub=_describe_stub(
            xcenv_based_path=("$(SDKROOT)/Library/Application Support/" +
                              "WatchKit/WK"),
            path_in_archive="WatchKitSupport2/WK",
            additional_bundle_path="_WatchKitStub/WK",
        ),
    ),
    apple_product_type.watch2_extension: _describe_product_type(
        bundle_extension=".appex",
    ),
    apple_product_type.xpc_service: _describe_product_type(
        bundle_extension=".xpc",
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
  return attrs.get(ctx.attr, "product_type", default=attrs.private_fallback)


def _product_type_descriptor(product_type):
  """Returns the descriptor for the given product type.

  The returned descriptor has the following fields:

  * `bundle_extension`: The default extension for bundles with this product
    type, including the leading dot.
  * `additional_infoplist_values`: A dictionary of keys and values that should
    be added to the `Info.plist` of a bundle with this product type.
  * `stub`: A descriptor for the stub binary required by this product type, if
    any (or `None` if this product type does not use a stub binary). This
    descriptor contains the following fields:

    * `xcenv_based_path`: The Xcode-environment-based path from which the stub
      binary should be copied.
    * `path_in_archive`: The path relative to the root of a top-level
      application archive where the stub should be copied as a support file.
    * `additional_bundle_path`: A path relative to the bundle where the stub
      binary should be copied, *in addition to* the standard location of the
      executable.

  Args:
    product_type: The product type.
  Returns:
    The product type descriptor.
  """
  return _PRODUCT_TYPE_DESCRIPTORS.get(product_type)


# Define the loadable module that lists the exported symbols in this file.
product_support = struct(
    product_type=_product_type,
    product_type_descriptor=_product_type_descriptor,
)
