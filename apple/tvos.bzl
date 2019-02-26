# Copyright 2019 The Bazel Authors. All rights reserved.
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

load(
    "@build_bazel_rules_apple//apple/internal/testing:tvos_rules.bzl",
    _tvos_unit_test = "tvos_unit_test",
)
load(
    "@build_bazel_rules_apple//apple/internal:binary_support.bzl",
    "binary_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:tvos_rules.bzl",
    _tvos_application = "tvos_application",
    _tvos_extension = "tvos_extension",
    _tvos_framework = "tvos_framework",
)

def tvos_application(name, **kwargs):
    """Builds and bundles a tvOS application.

    The named target produced by this macro is an IPA file.

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
      extensions: A list of extensions (see `tvos_extension`) to include in the
          final application.
      frameworks: A list of framework targets (see `tvos_framework`) that this
          application depends on.
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
      linkopts: A list of strings representing extra flags that the underlying
          `apple_binary` target should pass to the linker.
      provisioning_profile: The provisioning profile (`.mobileprovision` file) to
          use when bundling the application. This is only used for non-simulator
          builds.
      settings_bundle: A resource bundle target that contains the files that make
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
    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.tvos),
        **kwargs
    )

    _tvos_application(
        name = name,
        dylibs = kwargs.get("frameworks", []),
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
      entitlements_validation: An `entitlements_validation_mode` to control the
          validation of the requested entitlements against the provisioning
          profile to ensure they are supported.
      frameworks: A list of framework targets (see `tvos_framework`) that this
          extension depends on.
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
    # Make sure that TVServices.framework is linked in as well, to ensure that
    # _TVExtensionMain is found. (Anyone writing a TV extension should already be
    # importing this framework, anyway.)
    linkopts = kwargs.get("linkopts", [])
    linkopts += [
        "-e",
        "_TVExtensionMain",
        "-application_extension",
        "-framework",
        "TVServices",
    ]
    kwargs["linkopts"] = linkopts

    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.tvos),
        **kwargs
    )

    _tvos_extension(
        name = name,
        dylibs = kwargs.get("frameworks", []),
        **bundling_args
    )

def tvos_framework(name, **kwargs):
    """Builds and bundles a tvOS dynamic framework.

    The named target produced by this macro is a ZIP file. This macro also
    creates a target named "{name}.apple_binary" that represents the
    linked binary executable inside the framework bundle.

    Args:
      name: The name of the target.
      bundle_id: The bundle ID (reverse-DNS path followed by app name) of the
          framework. If specified, it will override the bundle ID in the plist
          file. If no bundle ID is specified by either this attribute or in the
          plist file, the build will fail.
      extension_safe: If true, compiles and links this framework with
          `-application-extension` restricting the binary to use only
          extension-safe APIs. False by default.
      frameworks: A list of framework targets that this framework depends on.
      infoplists: A list of `.plist` files that will be merged to form the
          Info.plist that represents the framework. The merge is only at the
          top level of the plist; so sub-dictionaries are not merged.
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

    # TODO(b/120861201): The linkopts macro additions here only exist because the Starlark linking
    # API does not accept extra linkopts and link inputs. With those, it will be possible to merge
    # these workarounds into the rule implementations.
    linkopts = kwargs.pop("linkopts", [])
    bundle_name = kwargs.get("bundle_name", name)
    linkopts += ["-install_name", "@rpath/%s.framework/%s" % (bundle_name, bundle_name)]
    kwargs["linkopts"] = linkopts

    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.tvos),
        **kwargs
    )

    # Remove any kwargs that shouldn't be passed to the underlying rule.
    bundling_args.pop("entitlements", None)

    _tvos_framework(
        name = name,
        dylibs = kwargs.get("frameworks", []),
        **bundling_args
    )

def tvos_unit_test(name, **kwargs):
    """Builds an XCTest unit test bundle and tests it using the provided runner.

    The named target produced by this macro is a test target that can be executed
    with the `bazel test` command.

    Args:
      name: The name of the target.
      test_host: The tvos_application target that contains the code to be
          tested. Optional.
      bundle_id: The bundle ID (reverse-DNS path followed by app name) of the
          test bundle. Optional. Defaults to the test_host's postfixed with
          "Tests".
      infoplists: A list of plist files that will be merged to form the
          Info.plist that represents the test bundle. The merge is only at the
          top level of the plist; so sub-dictionaries are not merged.
      minimum_os_version: The minimum OS version that this target and its
          dependencies should be built for. Optional.
      runner: The runner target that contains the logic of how the tests should
          be executed. This target needs to provide an AppleTestRunner provider.
          Optional.
      deps: A list of dependencies that contain the test code and dependencies
          needed to run the tests.
    """
    _tvos_unit_test(name = name, **kwargs)
