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

# Product type identifiers used to describe various bundle types.
#
# The "product type" is a concept used internally by Xcode (the strings themselves
# are visible inside the `.pbxproj` file) that describes properties of the bundle,
# such as its default extension.
#
# Additionally, products like iMessage applications and sticker packs in iOS 10
# require a stub executable instead of a user-defined binary and additional values
# injected into their `Info.plist` files. These behaviors are also captured in the
# product type identifier. The product types currently supported are:
#
# * `application`: A basic iOS, macOS, or tvOS application. This is the default
#   product type for those targets; it can be overridden with a more specific
#   product type if needed.
# * `app_extension`: A basic iOS, macOS, or tvOS application extension. This is
#   the default product type for those targets; it can be overridden with a more
#   specific product type if needed.
# * `bundle`: A loadable macOS bundle. This is the default product type for
#   `macos_bundle` targets; it can be overridden with a more specific product type
#   if needed.
# * `dylib`: A dynamically-loadable library. This is the default product type for
#   `macos_dylib`; it does not need to be set explicitly (and cannot be changed).
# * `framework`: A basic dynamic framework. This is the default product type for
#   those targets; it does not need to be set explicitly (and cannot be changed).
# * `kernel_extension`: A macOS kernel extension. This product type should be used
#   with a `macos_bundle` target to create such a plug-in; the built bundle will
#   have the extension `.kext`.
# * `messages_application`: An application that integrates with the Messages
#   app (iOS 10 and above). This application must include an `ios_extension`
#   with the `messages_extension` or `messages_sticker_pack_extension` product
#   type (or both extensions). This product type does not contain a user-provided
#   binary.
# * `messages_extension`: An extension that integrates custom code/behavior into
#   a Messages application. This product type should contain a user-provided
#   binary.
# * `messages_sticker_pack_extension`: An extension that defines custom sticker
#   packs for the Messages app. This product type does not contain a
#   user-provided binary.
# * `spotlight_importer`: A macOS Spotlight importer plug-in. This product type
#   should be used with a `macos_bundle` target to create such a plug-in; the
#   built bundle will have the extension `.mdimporter`.
# * `static_framework`: An iOS static framework, which is a `.framework` bundle
#   that contains resources and headers but a static library instead of a dynamic
#   library.
# * `tool`: A command-line tool. This is the default product type for
#   `macos_command_line_application`; it does not need to be set explicitly (and
#   cannot be changed).
# * `ui_test_bundle`: A UI testing bundle (.xctest). This is the default product
#   type for those targets; it does not need to be set explicitly (and cannot be
#   changed).
# * `unit_test_bundle`: A unit test bundle (.xctest). This is the default product
#   type for those targets; it does not need to be set explicitly (and cannot be
#   changed).
# * `watch2_application`: A watchOS 2+ application. This is the default product
#   type for those targets; it does not need to be set explicitly (and cannot be
#   changed).
# * `watch2_extension`: A watchOS 2+ application extension. This is the default
#   product type for those targets; it does not need to be set explicitly (and
#   cannot be changed).
# * `xpc_service`: A macOS XPC service. This product type should be used with a
#   `macos_application` target to create such a service; the built bundle will
#   have the extension `.xpc`.
apple_product_type = struct(
    application = "com.apple.product-type.application",
    app_extension = "com.apple.product-type.app-extension",
    bundle = "com.apple.product-type.bundle",
    dylib = "com.apple.product-type.library.dynamic",
    framework = "com.apple.product-type.framework",
    kernel_extension = "com.apple.product-type.kernel-extension",
    messages_application = "com.apple.product-type.application.messages",
    messages_extension = "com.apple.product-type.app-extension.messages",
    messages_sticker_pack_extension = (
        "com.apple.product-type.app-extension.messages-sticker-pack"
    ),
    spotlight_importer = "com.apple.product-type.spotlight-importer",
    static_framework = "com.apple.product-type.framework.static",
    tool = "com.apple.product-type.tool",
    ui_test_bundle = "com.apple.product-type.bundle.ui-testing",
    unit_test_bundle = "com.apple.product-type.bundle.unit-test",
    watch2_application = "com.apple.product-type.application.watchapp2",
    watch2_extension = "com.apple.product-type.watchkit2-extension",
    xpc_service = "com.apple.product-type.xpc-service",
)

def _is_test_product_type(product_type):
    """Returns whether the given product type is for tests purposes or not."""
    return product_type in [apple_product_type.ui_test_bundle, apple_product_type.unit_test_bundle]

def _product_type(ctx):
    """Returns the product type identifier for the current target.

    Args:
      ctx: The Skylark context.

    Returns:
      The product type identifier for the current target, or None if there is
      none.
    """
    return attrs.get(ctx.attr, "product_type", default = attrs.private_fallback)

# Define the loadable module that lists the exported symbols in this file.
product_support = struct(
    is_test_product_type = _is_test_product_type,
    product_type = _product_type,
)
