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

"""Bazel rules for creating watchOS applications and bundles."""

load(
    "@build_bazel_rules_apple//apple/bundling:binary_support.bzl",
    "binary_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:product_support.bzl",
    "apple_product_type",
)

# Alias the internal rules when we load them. This lets the rules keep their
# original name in queries and logs since they collide with the wrapper macros.
load("@build_bazel_rules_apple//apple/bundling:watchos_rules.bzl",
     _watchos_application="watchos_application",
     _watchos_extension="watchos_extension",
    )


def watchos_application(name, **kwargs):
  """Builds and bundles a watchOS application.

  This rule only supports watchOS 2.0 and higher. It cannot be used to produce
  watchOS 1.x application, as Apple no longer supports that version of the
  platform.

  The named target produced by this macro is a zip file. The watch application
  is not executable or installable by itself; it must be used by adding the
  target to a companion `"ios_application"` using the `"watch_application"`
  attribute on that rule.

  Args:
    name: The name of the target.
    app_icons: Files that comprise the app icons for the application. Each file
        must have a containing directory named `"*.xcassets/*.appiconset"` and
        there may be only one such `.appiconset` directory in the list.
    bundle_id: The bundle ID (reverse-DNS path followed by app name) of the
        application. If specified, it will override the bundle ID in the plist
        file. If no bundle ID is specified by either this attribute or in the
        plist file, the build will fail.
    entitlements: The entitlements file required for device builds of this
        application. If absent, the default entitlements from the provisioning
        profile will be used. The following variables are substituted:
        `$(CFBundleIdentifier)` with the bundle ID and `$(AppIdentifierPrefix)`
        with the value of the `ApplicationIdentifierPrefix` key from this
        target's provisioning profile (or the default provisioning profile, if
        none is specified).
    entitlements_validation: An `entitlements_validation_mode` to control the
        validation of the requested entitlements against the provisioning
        profile to ensure they are supported.
    extension: The watch extension (see `watchos_extension`) to bundle with
        this application. This attribute is required.
    infoplists: A list of `.plist` files that will be merged to form the
        Info.plist that represents the application. The merge is only at the
        top level of the plist; so sub-dictionaries are not merged.
    ipa_post_processor: A tool that edits this target's IPA output after it is
        assembled but before it is (optionally) signed. The tool is invoked
        with a single positional argument that represents the path to a
        directory containing the unzipped contents of the IPA. The only entry
        in this directory will be the Payload root directory of the IPA. Any
        changes made by the tool must be made in this directory, and the tool's
        execution must be hermetic given these inputs to ensure that the result
        can be safely cached.
    provisioning_profile: The provisioning profile (`.mobileprovision` file) to
        use when bundling the application. This is only used for non-simulator
        builds.
    strings: A list of files that are plists of strings, often localizable.
        These files are converted to binary plists (if they are not already)
        and placed in the bundle root of the final package. If this file's
        immediate containing directory is named `*.lproj`, it will be placed
        under a directory of that name in the final bundle. This allows for
        localizable strings.
    deps: A list of dependencies whose resources will be included in the final
        application bundle. (Since a watchOS application does not contain any
        code of its own, any code in the dependent libraries will be ignored.)
  """

  bundling_args = binary_support.entitlement_args_for_stub(
      name,
      platform_type=str(apple_common.platform_type.watchos),
      **kwargs)

  _watchos_application(
      name = name,
      **bundling_args
  )


def watchos_extension(name, **kwargs):
  """Builds and bundles a watchOS extension.

  This rule only supports watchOS 2.0 and higher. It cannot be used to produce
  watchOS 1.x application, as Apple no longer supports that version of the
  platform.

  The named target produced by this macro is a ZIP file. This macro also
  creates a target named `"{name}.apple_binary"` that represents the linked
  binary executable inside the extension bundle.

  Args:
    name: The name of the target.
    app_icons: Files that comprise the app icons for the extension. Each file
        must have a containing directory named `"*.xcassets/*.appiconset"` and
        there may be only one such .appiconset directory in the list.
    bundle_id: The bundle ID (reverse-DNS path followed by app name) of the
        extension. If specified, it will override the bundle ID in the plist
        file. If no bundle ID is specified by either this attribute or in the
        plist file, the build will fail.
    entitlements: The entitlements file required for device builds of this
        application. If absent, the default entitlements from the provisioning
        profile will be used. The following variables are substituted:
        `$(CFBundleIdentifier)` with the bundle ID and `$(AppIdentifierPrefix)`
        with the value of the `ApplicationIdentifierPrefix` key from this
        target's provisioning profile (or the default provisioning profile, if
        none is specified).
    entitlements_validation: An `entitlements_validation_mode` to control the
        validation of the requested entitlements against the provisioning
        profile to ensure they are supported.
    infoplists: A list of `.plist` files that will be merged to form the
        Info.plist that represents the extension. The merge is only at the top
        level of the plist; so sub-dictionaries are not merged.
    ipa_post_processor: A tool that edits this target's archive after it is
        assembled but before it is (optionally) signed. The tool is invoked
        with a single positional argument that represents the path to a
        directory containing the unzipped contents of the archive. The only
        entry in this directory will be the `.appex` directory for the
        extension. Any changes made by the tool must be made in this directory,
        and the tool's execution must be hermetic given these inputs to ensure
        that the result can be safely cached.
    linkopts: A list of strings representing extra flags that the underlying
        `apple_binary` target should pass to the linker.
    strings: A list of files that are plists of strings, often localizable.
        These files are converted to binary plists (if they are not already)
        and placed in the bundle root of the final package. If this file's
        immediate containing directory is named `*.lproj`, it will be placed
        under a directory of that name in the final bundle. This allows for
        localizable strings.
    deps: A list of dependencies, such as libraries, that are passed into the
        `apple_binary` rule. Any resources, such as asset catalogs, that are
        defined by these targets will also be transitively included in the
        final extension.
  """

  # Add extension-specific linker options. Note that since apple_binary
  # prepends "-Wl," to each option, we must use the form expected by ld, not
  # the form expected by clang (i.e., -application_extension, not
  # -fapplication-extension).
  linkopts = kwargs.get("linkopts", [])
  linkopts += ["-application_extension"]
  kwargs["linkopts"] = linkopts

  bundling_args = binary_support.create_binary(
      name,
      str(apple_common.platform_type.watchos),
      _product_type=apple_product_type.watch2_extension,
      **kwargs)

  _watchos_extension(
      name = name,
      **bundling_args
  )
