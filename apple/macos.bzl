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
# limitations under the Lice

"""Bazel rules for creating macOS applications and bundles."""

load("@build_bazel_rules_apple//apple/bundling:binary_support.bzl",
     "binary_support")

# Alias the internal rules when we load them. This lets the rules keep their
# original name in queries and logs since they collide with the wrapper macros.
load("@build_bazel_rules_apple//apple/bundling:macos_rules.bzl",
     _macos_application="macos_application",
     _macos_extension="macos_extension",
    )


def macos_application(name, **kwargs):
  """Packages a macOS application.

  The named target produced by this macro is a ZIP file. This macro also creates
  a target named "{name}.apple_binary" that represents the linked binary
  executable inside the application bundle.

  Args:
    name: The name of the target.
    app_icons: Files that comprise the app icons for the application. Each file
        must have a containing directory named "*.xcassets/*.appiconset" and
        there may be only one such .appiconset directory in the list.
    bundle_id: The bundle ID (reverse-DNS path followed by app name) of the
        application. Required.
    entitlements: The entitlements file required for this application. If
        absent, the default entitlements from the provisioning profile will be
        used. The following variables are substituted: $(CFBundleIdentifier)
        with the bundle ID and $(AppIdentifierPrefix) with the value of the
        ApplicationIdentifierPrefix key from this target's provisioning
        profile (or the default provisioning profile, if none is specified).
    extensions: A list of extensions to include in the final application.
    infoplists: A list of plist files that will be merged to form the
        Info.plist that represents the application.
    ipa_post_processor: A tool that edits this target's archive output
        after it is assembled but before it is (optionally) signed. The tool is
        invoked with a single positional argument that represents the path to a
        directory containing the unzipped contents of the archive. The only
        entry in this directory will be the Payload root directory of the
        archive. Any changes made by the tool must be made in this directory,
        and the tool's execution must be hermetic given these inputs to ensure
        that the result can be safely cached.
    linkopts: A list of strings representing extra flags that the underlying
        apple_binary target should pass to the linker.
    provisioning_profile: The provisioning profile (.provisionprofile file) to
        use when bundling the application.
    strings: A list of files that are plists of strings, often localizable.
        These files are converted to binary plists (if they are not already)
        and placed in the bundle root of the final package. If this file's
        immediate containing directory is named *.lproj, it will be placed
        under a directory of that name in the final bundle. This allows for
        localizable strings.
    deps: A list of dependencies, such as libraries, that are passed into the
        apple_binary rule. Any resources, such as asset catalogs, that are
        defined by these targets will also be transitively included in the
        final application.
  """
  # TODO(b/62481675): Move these linkopts to CROSSTOOL features.
  linkopts = kwargs.get("linkopts", [])
  linkopts += ["-rpath", "@executable_path/../Frameworks"]
  kwargs["linkopts"] = linkopts

  bundling_args = binary_support.create_binary(
      name,
      str(apple_common.platform_type.macos),
      features=["link_cocoa"],
      **kwargs)

  _macos_application(
      name = name,
      **bundling_args
  )


def macos_extension(name, **kwargs):
  """Packages a macOS extension.

  The named target produced by this macro is a ZIP file. This macro also
  creates a target named "{name}.apple_binary" that represents the linked
  binary executable inside the extension bundle.

  Args:
    name: The name of the target.
    app_icons: Files that comprise the app icons for the extension. Each file
        must have a containing directory named "*.xcassets/*.appiconset" and
        there may be only one such .appiconset directory in the list.
    bundle_id: The bundle ID (reverse-DNS path followed by app name) of the
        extension. Required.
    entitlements: The entitlements file required for this application. If
        absent, the default entitlements from the provisioning profile will be
        used. The following variables are substituted: $(CFBundleIdentifier)
        with the bundle ID and $(AppIdentifierPrefix) with the value of the
        ApplicationIdentifierPrefix key from this target's provisioning
        profile (or the default provisioning profile, if none is specified).
    infoplists: A list of plist files that will be merged to form the
        Info.plist that represents the extension.
    ipa_post_processor: A tool that edits this target's archive output
        after it is assembled but before it is (optionally) signed. The tool is
        invoked with a single positional argument that represents the path to a
        directory containing the unzipped contents of the archive. The only
        entry in this directory will be the .appex directory for the extension.
        Any changes made by the tool must be made in this directory, and the
        tool's execution must be hermetic given these inputs to ensure that the
        result can be safely cached.
    linkopts: A list of strings representing extra flags that the underlying
        apple_binary target should pass to the linker.
    provisioning_profile: The provisioning profile (.provisionprofile file) to
        use when bundling the application.
    strings: A list of files that are plists of strings, often localizable.
        These files are converted to binary plists (if they are not already)
        and placed in the bundle root of the final package. If this file's
        immediate containing directory is named *.lproj, it will be placed
        under a directory of that name in the final bundle. This allows for
        localizable strings.
    deps: A list of dependencies, such as libraries, that are passed into the
        apple_binary rule. Any resources, such as asset catalogs, that are
        defined by these targets will also be transitively included in the
        final extension.
  """

  # Add extension-specific linker options.
  # TODO(b/62481675): Move these linkopts to CROSSTOOL features.
  linkopts = kwargs.get("linkopts", [])
  linkopts += [
      "-e", "_NSExtensionMain",
      "-rpath", "@executable_path/../Frameworks",
      "-rpath", "@executable_path/../../../../Frameworks",
  ]
  kwargs["linkopts"] = linkopts

  bundling_args = binary_support.create_binary(
      name,
      str(apple_common.platform_type.macos),
      extension_safe=True,
      features=["link_cocoa"],
      **kwargs)

  _macos_extension(
      name = name,
      **bundling_args
  )
