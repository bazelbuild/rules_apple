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

"""Bazel rules for creating iOS applications and bundles."""

load("@build_bazel_rules_apple//apple/bundling:binary_support.bzl",
     "binary_support")

# Alias the internal rules when we load them. This lets the rules keep their
# original name in queries and logs since they collide with the wrapper macros.
load("@build_bazel_rules_apple//apple/bundling:ios_rules.bzl",
     _ios_application="ios_application",
     _ios_extension="ios_extension",
     _ios_framework="ios_framework",
    )

# Explicitly export this because we want it visible to users loading this file.
load("@build_bazel_rules_apple//apple/bundling:product_support.bzl",
     "apple_product_type")


def ios_application(name, **kwargs):
  """Builds and bundles an iOS application.

  The named target produced by this macro is an IPA file. This macro also
  creates a target named `"{name}.apple_binary"` that represents the linked
  binary executable inside the application bundle.

  Args:
    name: A unique name for the target.
    app_icons: Files that comprise the app icons for the application. Each file
        must have a containing directory named `*.xcassets/*.appiconset` and
        there may be only one such `.appiconset` directory in the list.
    bundle_id: The bundle ID (reverse-DNS path followed by app name) of the
        application.
    entitlements: The entitlements file required for device builds of this
        application. If absent, the default entitlements from the provisioning
        profile will be used.

        The following variables are substituted: `$(CFBundleIdentifier)` with
        the bundle ID and `$(AppIdentifierPrefix)` with the value of the
        `ApplicationIdentifierPrefix` key from this target's provisioning
        profile.
    extensions: A list of extensions (see `ios_extension`) to include in the
        final application bundle.
    families: A list of device families supported by this application. Valid
        values are `iphone` and `ipad`; at least one must be specified.
    frameworks: A list of framework targets (see `ios_framework`) that this
        application depends on.
    infoplists: A list of `.plist` files that will be merged to form the
        Info.plist that represents the application. At least one file must be
        specified.
    ipa_post_processor: A tool that edits this target's IPA output after it is
        assembled but before it is (optionally) signed. The tool is invoked with
        a single command-line argument that denotes the path to a directory
        containing the unzipped contents of the IPA (that is, the `Payload`
        directory will be present in this directory).

        Any changes made by the tool must be made in this directory, and the
        tool's execution must be hermetic given these inputs to ensure that the
        result can be safely cached.
    launch_images: Files that comprise the launch images for the application.
        Each file must have a containing directory named
        `*.xcassets/*.launchimage` and there may be only one such
        `.launchimage` directory in the list.

        It is recommended that you use a `launch_storyboard` instead if you are
        targeting only iOS 8 and later.
    launch_storyboard: The `.storyboard` or `.xib` file that should be used as
        the launch screen for the application. The provided file will be
        compiled into the appropriate format (`.storyboardc` or `.nib`) and
        placed in the root of the final bundle. The generated file will also be
        registered in the bundle's `Info.plist` under the key
        `UILaunchStoryboardName`.
    linkopts: A list of strings representing extra flags that the underlying
        `apple_binary` target created by this rule should pass to the linker.
    product_type: An optional string denoting a special type of application,
        such as a Messages Application in iOS 10 and higher. See
        `apple_product_type`.
    provisioning_profile: The provisioning profile (`.mobileprovision` file) to
        use when bundling the application. This value is optional (and unused)
        for simulator builds but **required** for device builds.
    settings_bundle: An `objc_bundle` target that contains the files that make
        up the application's settings bundle. These files will be copied into
        the root of the final application bundle in a directory named
        `Settings.bundle`.
    strings: A list of `.strings` files, often localizable.
        These files are converted to binary plists (if they are not already)
        and placed in the root of the final application bundle, unless a file's
        immediate containing directory is named `*.lproj`, in which case it will
        be placed under a directory with the same name in the bundle.
    watch_application: A `watchos_application` target that represents an Apple
        Watch application that should be embedded in the application.
    deps: A list of targets that are passed into the `apple_binary` rule to be
        linked. Any resources, such as asset catalogs, that are referenced by
        those targets will also be transitively included in the final
        application.

  """
  bundling_args = binary_support.create_binary(
      name, str(apple_common.platform_type.ios), **kwargs)

  _ios_application(
      name = name,
      **bundling_args
  )


def ios_extension(name, **kwargs):
  """Builds and bundles an iOS application extension.

  The named target produced by this macro is a ZIP file. This macro also
  creates a target named `"{name}.apple_binary"` that represents the linked
  binary executable inside the extension bundle.

  Args:
    name: The name of the target.
    app_icons: Files that comprise the app icons for the extension. Each file
        must have a containing directory named `"*.xcassets/*.appiconset"` and
        there may be only one such `.appiconset` directory in the list.
    bundle_id: The bundle ID (reverse-DNS path followed by app name) of the
        extension. Required.
    entitlements: The entitlements file required for device builds of this
        application. If absent, the default entitlements from the provisioning
        profile will be used. The following variables are substituted:
        `$(CFBundleIdentifier)` with the bundle ID and `$(AppIdentifierPrefix)`
        with the value of the `ApplicationIdentifierPrefix` key from this
        target's provisioning profile (or the default provisioning profile, if
        none is specified).
    families: A list of device families supported by this extension. Valid
        values are `"iphone"` and `"ipad"`.
    frameworks: A list of framework targets (see `ios_framework`) that this
        extension depends on.
    infoplists: A list of `.plist` files that will be merged to form the
        `Info.plist` that represents the extension.
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
    product_type: An optional string denoting a special type of extension,
        such as an iMessages sticker pack in iOS 10 and higher.
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
  linkopts += ["-e", "_NSExtensionMain", "-application_extension"]
  kwargs["linkopts"] = linkopts

  bundling_args = binary_support.create_binary(
      name, str(apple_common.platform_type.ios), **kwargs)

  _ios_extension(
      name = name,
      **bundling_args
  )


def ios_framework(name, **kwargs):
  """Builds and bundles an iOS dynamic framework.

  The named target produced by this macro is a ZIP file. This macro also
  creates a target named "{name}.apple_binary" that represents the
  linked binary executable inside the framework bundle.

  Args:
    name: The name of the target.
    bundle_id: The bundle ID (reverse-DNS path followed by app name) of the
        framework. If specified, it will override the bundle ID in the plist
        file. If no bundle ID is specified by either this attribute or in the
        plist file, the build will fail.
    families: A list of device families supported by this framework. Valid
        values are `"iphone"` and `"ipad"`.
    infoplists: A list of `.plist` files that will be merged to form the
        Info.plist that represents the framework.
    ipa_post_processor: A tool that edits this target's archive after it is
        assembled but before it is (optionally) signed. The tool is invoked
        with a single positional argument that represents the path to a
        directory containing the unzipped contents of the archive. The only
        entry in this directory will be the `.framework` directory for the
        framework. Any changes made by the tool must be made in this directory,
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
        final framework.
  """
  deps = kwargs.pop("deps", [])
  apple_dylib_name = "%s.apple_binary" % name

  linkopts = kwargs.get("linkopts", [])
  linkopts += ["-install_name", "@rpath/%s.framework/%s" % (name, name)]

  # Link the executable from any library deps and sources provided.
  native.apple_binary(
      name = apple_dylib_name,
      binary_type = "dylib",
      hdrs = kwargs.get("hdrs", []),
      platform_type = str(apple_common.platform_type.ios),
      deps = deps,
      testonly = kwargs.get("testonly"),
      linkopts = linkopts,
  )

  # Remove any kwargs that shouldn't be passed to the underlying rule.
  passthrough_args = kwargs
  passthrough_args.pop("entitlements", None)

  _ios_framework(
      name = name,
      binary = apple_dylib_name,
      **passthrough_args
  )
