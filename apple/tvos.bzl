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

"""Bazel rules for creating tvOS applications and bundles."""

load("@build_bazel_rules_apple//apple/bundling:binary_support.bzl",
     "binary_support")

# Alias the internal rules when we load them. This lets the rules keep their
# original name in queries and logs since they collide with the wrapper macros.
load("@build_bazel_rules_apple//apple/bundling:tvos_rules.bzl",
     _tvos_application="tvos_application",
     _tvos_extension="tvos_extension",
    )

# Explicitly export this because we want it visible to users loading this file.
load(
    "@build_bazel_rules_apple//apple/bundling:product_support.bzl",
    "apple_product_type",
)


def tvos_application(name, **kwargs):
  """Builds and bundles a tvOS application.

  The named target produced by this macro is an IPA file. This macro also
  creates a target named `"{name}.apple_binary"` that represents the linked
  binary executable inside the application bundle.

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
    extensions: A list of extensions (see `tvos_extension`) to include in the
        final application.
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
    launch_images: Files that comprise the launch images for the application.
        Each file must have a containing directory named
        `"*.xcassets/*.launchimage"` and there may be only one such
        `.launchimage` directory in the list.
    launch_storyboard: The `.storyboard` or `.xib` file that should be used as
        the launch screen for the application. The provided file will be
        compiled into the appropriate format and placed in the root of the
        final bundle. The generated file is registered in the final bundle's
        `Info.plist` under the key `UILaunchStoryboardName`.
    linkopts: A list of strings representing extra flags that the underlying
        `apple_binary` target should pass to the linker.
    provisioning_profile: The provisioning profile (`.mobileprovision` file) to
        use when bundling the application. This is only used for non-simulator
        builds.
    settings_bundle: An `objc_bundle` target that contains the files that make
        up the application's settings bundle. These files will be copied into
        the application in a directory named `Settings.bundle`.
    strings: A list of files that are plists of strings, often localizable.
        These files are converted to binary plists (if they are not already)
        and placed in the bundle root of the final package. If this file's
        immediate containing directory is named `*.lproj`, it will be placed
        under a directory of that name in the final bundle. This allows for
        localizable strings.
    deps: A list of dependencies, such as libraries, that are passed into the
        `apple_binary` rule. Any resources, such as asset catalogs, that are
        defined by these targets will also be transitively included in the
        final application.
  """
  bundling_args = binary_support.create_binary(
      name, str(apple_common.platform_type.tvos), **kwargs)

  _tvos_application(
      name = name,
      **bundling_args
  )


def tvos_extension(name, **kwargs):
  """Builds and bundles a tvOS extension.

  The named target produced by this macro is a ZIP file. This macro also
  creates a target named `"{name}.apple_binary"` that represents the linked
  binary executable inside the extension bundle.

  Args:
    name: The name of the target.
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
    infoplists: A list of `.plist` files that will be merged to form the
        `Info.plist` that represents the extension. The merge is only at the
        top level of the plist; so sub-dictionaries are not merged.
    ipa_post_processor: A tool that edits this target's archive after it is
        assembled but before it is (optionally) signed. The tool is invoked
        with a single positional argument that represents the path to a
        directory containing the unzipped contents of the archive. The only
        entry in this directory will be the `.appex` directory for the
        extension. Any changes made by the tool must be made in this
        directory, and the tool's execution must be hermetic given these inputs
        to ensure that the result can be safely cached.
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
  linkopts += ["-e", "_TVExtensionMain", "-application_extension"]
  kwargs["linkopts"] = linkopts

  # Make sure that TVServices.framework is linked in as well, to ensure that
  # _TVExtensionMain is found. (Anyone writing a TV extension should already be
  # importing this framework, anyway.)
  bundling_args = binary_support.create_binary(
      name,
      str(apple_common.platform_type.tvos),
      sdk_frameworks=["TVServices"],
      **kwargs
  )

  _tvos_extension(
      name = name,
      **bundling_args
  )
