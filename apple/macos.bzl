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

"""Bazel rules for creating macOS applications and bundles."""

load(
    "@build_bazel_rules_apple//apple/bundling:binary_support.bzl",
    "binary_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:product_support.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/internal/testing:macos_rules.bzl",
    _macos_ui_test = "macos_ui_test",
    _macos_unit_test = "macos_unit_test",
)
load(
    "@build_bazel_rules_apple//apple/internal:macos_binary_support.bzl",
    "macos_binary_infoplist",
    "macos_command_line_launchdplist",
)
load(
    "@build_bazel_rules_apple//apple/internal:macos_rules.bzl",
    _macos_application = "macos_application",
    _macos_bundle = "macos_bundle",
    _macos_command_line_application = "macos_command_line_application",
    _macos_dylib = "macos_dylib",
    _macos_extension = "macos_extension",
    _macos_kernel_extension = "macos_kernel_extension",
    _macos_spotlight_importer = "macos_spotlight_importer",
    _macos_xpc_service = "macos_xpc_service",
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
      bundle_extension: The extension, without a leading dot, that will be used to
          name the application bundle. If this attribute is not set, then the
          default extension is determined by the application's `product_type`. For
          example, `apple_product_type.application` uses the extension `app`,
          while `apple_product_type.xpc_service` uses the extension `xpc`.
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
          Info.plist that represents the application. The merge is only at the
          top level of the plist; so sub-dictionaries are not merged.
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
    binary_args = dict(kwargs)

    # TODO(b/62481675): Move these linkopts to CROSSTOOL features.
    linkopts = binary_args.get("linkopts", [])
    linkopts += ["-rpath", "@executable_path/../Frameworks"]
    binary_args["linkopts"] = linkopts

    bundling_args = binary_support.create_binary(
        name,
        str(apple_common.platform_type.macos),
        features = ["link_cocoa"],
        **binary_args
    )

    _macos_application(
        name = name,
        **bundling_args
    )

def macos_bundle(name, **kwargs):
    """Packages a macOS loadable bundle.

    The named target produced by this macro is a ZIP file. This macro also creates
    a target named "{name}.apple_binary" that represents the linked binary
    executable inside the application bundle.

    Args:
      name: The name of the target.
      app_icons: Files that comprise the app icons for the bundle. Each file
          must have a containing directory named "*.xcassets/*.appiconset" and
          there may be only one such .appiconset directory in the list.
      bundle_id: The bundle ID (reverse-DNS path followed by app name) of the
          bundle. Required.
      bundle_extension: The extension, without a leading dot, that will be used to
          name the bundle. If this attribute is not set, then the default
          extension is determined by the application's `product_type`. For
          example, `apple_product_type.bundle` uses the extension `bundle`, while
          `apple_product_type.spotlight_importer` uses the extension `mdimporter`.
      bundle_loader: A label to a macOS executable target (i.e
          macos_command_line_application, macos_application or macos_extension).
          The macOS bundle binary generated by this rule will then assume that it
          will be loaded by that targets's binary at runtime. If this attribute is
          set, this macos_bundle target _cannot_ be a dependency for that target.
      entitlements: The entitlements file required for this bundle. If
          absent, the default entitlements from the provisioning profile will be
          used. The following variables are substituted: $(CFBundleIdentifier)
          with the bundle ID and $(AppIdentifierPrefix) with the value of the
          ApplicationIdentifierPrefix key from this target's provisioning
          profile (or the default provisioning profile, if none is specified).
      infoplists: A list of plist files that will be merged to form the
          Info.plist that represents the bundle. The merge is only at the top
          level of the plist; so sub-dictionaries are not merged.
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
          use when bundling the bundle.
      strings: A list of files that are plists of strings, often localizable.
          These files are converted to binary plists (if they are not already)
          and placed in the bundle root of the final package. If this file's
          immediate containing directory is named *.lproj, it will be placed
          under a directory of that name in the final bundle. This allows for
          localizable strings.
      deps: A list of dependencies, such as libraries, that are passed into the
          apple_binary rule. Any resources, such as asset catalogs, that are
          defined by these targets will also be transitively included in the
          final bundle.
    """
    binary_args = dict(kwargs)

    # If a bundle loader was passed, re-write it to use the underlying
    # apple_binary target instead. When migrating to rules, we should validate
    # the attribute with providers.
    bundle_loader = binary_args.pop("bundle_loader", None)
    if bundle_loader:
        bundle_loader = "%s.apple_binary" % bundle_loader
        binary_args["bundle_loader"] = bundle_loader

    # TODO(b/62481675): Move these linkopts to CROSSTOOL features.
    features = []
    linkopts = binary_args.get("linkopts", [])
    if binary_args.get("product_type") != apple_product_type.kernel_extension:
        features.append("link_cocoa")
        linkopts += ["-rpath", "@executable_path/../Frameworks"]
    binary_args["linkopts"] = linkopts

    bundling_args = binary_support.create_binary(
        name,
        str(apple_common.platform_type.macos),
        binary_type = "loadable_bundle",
        features = features,
        **binary_args
    )

    _macos_bundle(
        name = name,
        **bundling_args
    )

def macos_kernel_extension(name, **kwargs):
    """Packages a macOS Kernel Extension."""
    binary_args = dict(kwargs)
    features = binary_args.pop("features", [])
    features += ["kernel_extension"]

    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.macos),
        features = features,
        **binary_args
    )

    _macos_kernel_extension(
        name = name,
        **bundling_args
    )

def macos_spotlight_importer(name, **kwargs):
    """Packages a macOS Spotlight Importer Bundle."""
    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.macos),
        **kwargs
    )

    _macos_spotlight_importer(
        name = name,
        **bundling_args
    )

def macos_xpc_service(name, **kwargs):
    """Packages a macOS XPC Service Application."""
    binary_args = dict(kwargs)

    # TODO(b/62481675): Move these linkopts to CROSSTOOL features.
    linkopts = binary_args.pop("linkopts", [])
    linkopts += [
        "-rpath",
        "@executable_path/../../../../Frameworks",
    ]

    bundling_args = binary_support.add_entitlements_and_swift_linkopts(
        name,
        platform_type = str(apple_common.platform_type.macos),
        linkopts = linkopts,
        **binary_args
    )

    _macos_xpc_service(
        name = name,
        **bundling_args
    )

def macos_command_line_application(name, **kwargs):
    """Builds a macOS command line application.

    A command line application is a standalone binary file, rather than a `.app`
    bundle like those produced by `macos_application`. Unlike a plain
    `apple_binary` target, however, this rule supports versioning and embedding an
    `Info.plist` into the binary and allows the binary to be code-signed.

    Args:
      name: The name of the target.
      bundle_id: The bundle ID (reverse-DNS path followed by app name) of the
          extension. Optional.
      infoplists: A list of plist files that will be merged and embedded in the
          binary. The merge is only at the top level of the plist; so
          sub-dictionaries are not merged.
      launchdplists: A list of plist files that will be merged and embedded.
      linkopts: A list of strings representing extra flags that should be passed
          to the linker.
      minimum_os_version: An optional string indicating the minimum macOS version
          supported by the target, represented as a dotted version number (for
          example, `"10.11"`). If this attribute is omitted, then the value
          specified by the flag `--macos_minimum_os` will be used instead.
      deps: A list of dependencies, such as libraries, that are linked into the
          final binary. Any resources found in those dependencies are
          ignored.
    """

    # Xcode will happily apply entitlements during code signing for a command line
    # tool even though it doesn't have a Capabilities tab in the project settings.
    # Until there's official support for it, we'll fail if we see those attributes
    # (which are added to the rule because of the code_signing_attributes usage in
    # the rule definition).
    if "entitlements" in kwargs or "provisioning_profile" in kwargs:
        fail("macos_command_line_application does not support entitlements or " +
             "provisioning profiles at this time")

    binary_args = dict(kwargs)

    original_deps = binary_args.pop("deps")
    binary_deps = list(original_deps)

    # If any of the Info.plist-affecting attributes is provided, create a merged
    # Info.plist target. This target also propagates an objc provider that
    # contains the linkopts necessary to add the Info.plist to the binary, so it
    # must become a dependency of the binary as well.
    bundle_id = binary_args.get("bundle_id")
    infoplists = binary_args.get("infoplists")
    launchdplists = binary_args.get("launchdplists")
    version = binary_args.get("version")

    if bundle_id or infoplists or version:
        merged_infoplist_name = name + ".merged_infoplist"

        macos_binary_infoplist(
            name = merged_infoplist_name,
            bundle_id = bundle_id,
            infoplists = infoplists,
            minimum_os_version = binary_args.get("minimum_os_version"),
            version = version,
        )
        binary_deps.extend([":" + merged_infoplist_name])

    if launchdplists:
        merged_launchdplists_name = name + ".merged_launchdplists"

        macos_command_line_launchdplist(
            name = merged_launchdplists_name,
            launchdplists = launchdplists,
        )
        binary_deps.extend([":" + merged_launchdplists_name])

    # Create the unsigned binary, then run the command line application rule that
    # signs it.
    cmd_line_app_args = binary_support.create_binary(
        name,
        str(apple_common.platform_type.macos),
        deps = binary_deps,
        link_swift_statically = True,
        suppress_entitlements = True,
        **binary_args
    )

    _macos_command_line_application(
        name = name,
        **cmd_line_app_args
    )

def macos_dylib(name, **kwargs):
    """Builds a macOS dylib.

    A dylib is a standalone binary dynamic library. Unlike a plain `apple_binary`
    target, however, this rule supports versioning and embedding an `Info.plist`
    into the binary and allows the binary to be code-signed.

    Args:
      name: The name of the target. (The extension `.dylib` will be added.)
      bundle_id: The bundle ID (reverse-DNS path followed by app name) of the
          extension. Optional.
      infoplists: A list of plist files that will be merged and embedded in the
          binary. The merge is only at the top level of the plist; so
          sub-dictionaries are not merged.
      linkopts: A list of strings representing extra flags that should be passed
          to the linker.
      minimum_os_version: An optional string indicating the minimum macOS version
          supported by the target, represented as a dotted version number (for
          example, `"10.11"`). If this attribute is omitted, then the value
          specified by the flag `--macos_minimum_os` will be used instead.
      deps: A list of dependencies, such as libraries, that are linked into the
          final binary. Any resources found in those dependencies are
          ignored.
    """

    # Xcode will happily apply entitlements during code signing for a dylib even
    # though it doesn't have a Capabilities tab in the project settings.
    # Until there's official support for it, we'll fail if we see those attributes
    # (which are added to the rule because of the code_signing_attributes usage in
    # the rule definition).
    if "entitlements" in kwargs or "provisioning_profile" in kwargs:
        fail("macos_dylib does not support entitlements or provisioning " +
             "profiles at this time")

    binary_args = dict(kwargs)

    original_deps = binary_args.pop("deps")
    binary_deps = list(original_deps)

    # If any of the Info.plist-affecting attributes is provided, create a merged
    # Info.plist target. This target also propagates an objc provider that
    # contains the linkopts necessary to add the Info.plist to the binary, so it
    # must become a dependency of the binary as well.
    bundle_id = binary_args.get("bundle_id")
    infoplists = binary_args.get("infoplists")
    version = binary_args.get("version")

    if bundle_id or infoplists or version:
        merged_infoplist_name = name + ".merged_infoplist"

        macos_binary_infoplist(
            name = merged_infoplist_name,
            bundle_id = bundle_id,
            infoplists = infoplists,
            minimum_os_version = binary_args.get("minimum_os_version"),
            version = version,
        )
        binary_deps.extend([":" + merged_infoplist_name])

    dylib_args = binary_support.create_binary(
        name,
        str(apple_common.platform_type.macos),
        binary_type = "dylib",
        deps = binary_deps,
        link_swift_statically = True,
        suppress_entitlements = True,
        **binary_args
    )

    _macos_dylib(
        name = name,
        **dylib_args
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
    binary_args = dict(kwargs)

    # Add extension-specific linker options.
    # TODO(b/62481675): Move these linkopts to CROSSTOOL features.
    linkopts = binary_args.get("linkopts", [])
    linkopts += [
        "-e",
        "_NSExtensionMain",
        "-rpath",
        "@executable_path/../Frameworks",
        "-rpath",
        "@executable_path/../../../../Frameworks",
    ]
    binary_args["linkopts"] = linkopts

    original_deps = binary_args.pop("deps")
    binary_deps = list(original_deps)

    bundling_args = binary_support.create_binary(
        name,
        str(apple_common.platform_type.macos),
        deps = binary_deps,
        extension_safe = True,
        features = ["link_cocoa"],
        **binary_args
    )

    _macos_extension(
        name = name,
        **bundling_args
    )

def macos_ui_test(
        name,
        runner = "@build_bazel_rules_apple//apple/testing/default_runner:macos_default_runner",
        **kwargs):
    """Builds an XCUITest test bundle and tests it using the provided runner.

    The named target produced by this macro is an test target that can be executed
    with the `bazel test` command.

    Args:
      name: The name of the target.
      test_host: The macos_application target that contains the code to be
          tested. Required.
      bundle_id: The bundle ID (reverse-DNS path followed by app name) of the
          test bundle. Optional. Defaults to the test_host's postfixed with
          "Tests".
      infoplists: A list of plist files that will be merged to form the
          Info.plist that represents the test bundle.
      minimum_os_version: The minimum OS version that this target and its
          dependencies should be built for. Optional.
      runner: The runner target that contains the logic of how the tests should
          be executed. This target needs to provide an AppleTestRunner provider.
          Optional.
      deps: A list of dependencies that contain the test code and resources
          needed to run the tests.
    """
    _macos_ui_test(
        name = name,
        runner = runner,
        **kwargs
    )

def macos_unit_test(
        name,
        runner = "@build_bazel_rules_apple//apple/testing/default_runner:macos_default_runner",
        **kwargs):
    """Builds an XCTest unit test bundle and tests it using the provided runner.

    The named target produced by this macro is a test target that can be executed
    with the `bazel test` command.

    Args:
      name: The name of the target.
      test_host: The macos_application target that contains the code to be
          tested. Optional.
      bundle_id: The bundle ID (reverse-DNS path followed by app name) of the
          test bundle. Optional. Defaults to the test_host's postfixed with
          "Tests".
      infoplists: A list of plist files that will be merged to form the
          Info.plist that represents the test bundle.
      minimum_os_version: The minimum OS version that this target and its
          dependencies should be built for. Optional.
      runner: The runner target that contains the logic of how the tests should
          be executed. This target needs to provide an AppleTestRunner provider.
          Optional.
      deps: A list of dependencies that contain the test code and resources
          needed to run the tests.
    """
    _macos_unit_test(
        name = name,
        runner = runner,
        **kwargs
    )
