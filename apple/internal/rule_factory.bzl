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

"""Helpers for defining Apple bundling rules uniformly."""

load(
    "@build_bazel_apple_support//lib:apple_support.bzl",
    "apple_support",
)
load(
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/internal:apple_support_toolchain.bzl",
    "apple_support_toolchain_utils",
)
load(
    "@build_bazel_rules_apple//apple/internal:entitlement_rules.bzl",
    "AppleEntitlementsInfo",
)
load(
    "@build_bazel_rules_apple//apple/internal/aspects:framework_import_aspect.bzl",
    "framework_import_aspect",
)
load(
    "@build_bazel_rules_apple//apple/internal/aspects:resource_aspect.bzl",
    "apple_resource_aspect",
)
load(
    "@build_bazel_rules_apple//apple/internal/aspects:swift_static_framework_aspect.bzl",
    "swift_static_framework_aspect",
)
load(
    "@build_bazel_rules_apple//apple/internal/aspects:swift_dynamic_framework_aspect.bzl",
    "swift_dynamic_framework_aspect",
)
load(
    "@build_bazel_rules_apple//apple/internal:transition_support.bzl",
    "transition_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/testing:apple_test_bundle_support.bzl",
    "apple_test_info_aspect",
)
load(
    "@build_bazel_rules_apple//apple/internal/testing:apple_test_rule_support.bzl",
    "coverage_files_aspect",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_support.bzl",
    "rule_support",
)
load(
    "@build_bazel_rules_apple//apple:common.bzl",
    "entitlements_validation_mode",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
    "AppleBundleVersionInfo",
    "AppleResourceBundleInfo",
    "AppleTestRunnerInfo",
    "IosAppClipBundleInfo",
    "IosApplicationBundleInfo",
    "IosExtensionBundleInfo",
    "IosFrameworkBundleInfo",
    "IosImessageApplicationBundleInfo",
    "IosImessageExtensionBundleInfo",
    "IosStickerPackExtensionBundleInfo",
    "MacosApplicationBundleInfo",
    "MacosExtensionBundleInfo",
    "MacosXPCServiceBundleInfo",
    "TvosApplicationBundleInfo",
    "TvosExtensionBundleInfo",
    "TvosFrameworkBundleInfo",
    "WatchosApplicationBundleInfo",
    "WatchosExtensionBundleInfo",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "swift_usage_aspect",
)
load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)

def _is_test_product_type(product_type):
    """Returns whether the given product type is for tests purposes or not."""
    return product_type in (
        apple_product_type.ui_test_bundle,
        apple_product_type.unit_test_bundle,
    )

# Private attributes on all rules.
_COMMON_ATTRS = dicts.add(
    {
        "_grep_includes": attr.label(
            cfg = "host",
            allow_single_file = True,
            executable = True,
            default = Label("@bazel_tools//tools/cpp:grep-includes"),
        ),
    },
    apple_support.action_required_attrs(),
)

# Private attributes on rules that perform binary linking.
_COMMON_BINARY_RULE_ATTRS = dicts.add(
    {
        "_cc_toolchain": attr.label(
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
        ),
        "_child_configuration_dummy": attr.label(
            cfg = apple_common.multi_arch_split,
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
        ),
        # Needed for the J2ObjC processing code that already exists in the implementation of
        # apple_common.link_multi_arch_binary.
        "_dummy_lib": attr.label(
            cfg = apple_common.multi_arch_split,
            default = Label("@bazel_tools//tools/objc:dummy_lib"),
        ),
        "_googlemac_proto_compiler": attr.label(
            cfg = "host",
            default = Label("@bazel_tools//tools/objc:protobuf_compiler_wrapper"),
        ),
        "_googlemac_proto_compiler_support": attr.label(
            cfg = "host",
            default = Label("@bazel_tools//tools/objc:protobuf_compiler_support"),
        ),
        # Needed for the J2ObjC processing code that already exists in the implementation of
        # apple_common.link_multi_arch_binary.
        "_j2objc_dead_code_pruner": attr.label(
            default = Label("@bazel_tools//tools/objc:j2objc_dead_code_pruner"),
        ),
        "_protobuf_well_known_types": attr.label(
            cfg = "host",
            default = Label("@bazel_tools//tools/objc:protobuf_well_known_types"),
        ),
        # xcrunwrapper is no longer used by rules_apple, but the underlying implementation of
        # apple_common.link_multi_arch_binary requires this attribute.
        # TODO(b/117932394): Remove this attribute once Bazel no longer uses xcrunwrapper.
        "_xcrunwrapper": attr.label(
            cfg = "host",
            executable = True,
            default = Label("@bazel_tools//tools/objc:xcrunwrapper"),
        ),
    },
)

_COMMON_TEST_ATTRS = {
    "data": attr.label_list(
        allow_files = True,
        default = [],
        doc = "Files to be made available to the test during its execution.",
    ),
    "env": attr.string_dict(
        doc = """
Dictionary of environment variables that should be set during the test execution.
""",
    ),
    "runner": attr.label(
        doc = """
The runner target that will provide the logic on how to run the tests. Needs to provide the
AppleTestRunnerInfo provider.
""",
        mandatory = True,
        providers = [AppleTestRunnerInfo],
    ),
    # This is an implementation detail attribute, so it's not documented on purpose.
    "deps": attr.label_list(
        mandatory = True,
        aspects = [coverage_files_aspect],
        providers = [AppleBundleInfo],
    ),
    # TODO(b/139430318): This attribute exists to apease the Tulsi gods and is not actually used by
    # the test rule implementation, and should be removed.
    # This is an implementation detail attribute, so it's not documented on purpose.
    "test_host": attr.label(
        providers = [AppleBundleInfo],
    ),
    "_apple_coverage_support": attr.label(
        cfg = "host",
        default = Label("@build_bazel_apple_support//tools:coverage_support"),
    ),
}

_EXTENSION_PROVIDES_MAIN_ATTRS = {
    "provides_main": attr.bool(
        default = False,
        doc = """
A value indicating whether one of this extension's dependencies provides a `main` entry point.

This is false by default, because most app extensions provide their implementation by specifying a
principal class or main storyboard in their `Info.plist` file, and the executable's entry point is
actually in a system framework that delegates to it.

However, some modern extensions (such as SwiftUI widget extensions introduced in iOS 14 and macOS
11) use the `@main` attribute to identify their primary type, which generates a traditional `main`
function that passes control to that type. For these extensions, this attribute should be set to
true.
""",
        mandatory = False,
    ),
}

def _common_binary_linking_attrs(default_binary_type, deps_cfg, product_type):
    deps_aspects = [
        swift_usage_aspect,
    ]

    default_stamp = -1
    if product_type:
        deps_aspects.extend([
            apple_resource_aspect,
            framework_import_aspect,
        ])
        if _is_test_product_type(product_type):
            deps_aspects.append(apple_test_info_aspect)
            default_stamp = 0
        if product_type == apple_product_type.static_framework:
            deps_aspects.append(swift_static_framework_aspect)
        if product_type == apple_product_type.framework:
            deps_aspects.append(swift_dynamic_framework_aspect)

    return dicts.add(
        _COMMON_ATTRS,
        _COMMON_BINARY_RULE_ATTRS,
        {
            "binary_type": attr.string(
                default = default_binary_type,
                doc = """
This attribute is public as an implementation detail while we migrate the architecture of the rules.
Do not change its value.
    """,
            ),
            "bundle_loader": attr.label(
                providers = [[apple_common.AppleExecutableBinary]],
                doc = """
This attribute is public as an implementation detail while we migrate the architecture of the rules.
Do not change its value.
    """,
            ),
            "dylibs": attr.label_list(
                doc = """
This attribute is public as an implementation detail while we migrate the architecture of the rules.
Do not change its value.
    """,
            ),
            "codesignopts": attr.string_list(
                doc = """
A list of strings representing extra flags that should be passed to `codesign`.
    """,
            ),
            "linkopts": attr.string_list(
                doc = """
A list of strings representing extra flags that should be passed to the linker.
    """,
            ),
            "stamp": attr.int(
                default = default_stamp,
                doc = """
Enable link stamping. Whether to encode build information into the binary. Possible values:

*   `stamp = 1`: Stamp the build information into the binary. Stamped binaries are only rebuilt
    when their dependencies change. Use this if there are tests that depend on the build
    information.
*   `stamp = 0`: Always replace build information by constant values. This gives good build
    result caching.
*   `stamp = -1`: Embedding of build information is controlled by the `--[no]stamp` flag.
""",
                values = [-1, 0, 1],
            ),
            "deps": attr.label_list(
                aspects = deps_aspects,
                cfg = deps_cfg,
                doc = """
A list of dependencies targets that will be linked into this target's binary. Any resources, such as
asset catalogs, that are referenced by those targets will also be transitively included in the final
bundle.
""",
            ),
        },
    )

def _get_common_bundling_attributes(rule_descriptor):
    """Returns a list of dictionaries with attributes common to all bundling rules."""

    # TODO(kaipi): Review platform specific wording in the documentation before migrating macOS
    # rules to use this rule factory.
    attrs = []

    if rule_descriptor.requires_bundle_id:
        bundle_id_mandatory = not _is_test_product_type(rule_descriptor.product_type)
        attrs.append({
            "bundle_id": attr.string(
                mandatory = bundle_id_mandatory,
                doc = "The bundle ID (reverse-DNS path followed by app name) for this target.",
            ),
        })

    if rule_descriptor.has_infoplist:
        attr_args = {}
        if rule_descriptor.default_infoplist:
            attr_args["default"] = [Label(rule_descriptor.default_infoplist)]
        else:
            attr_args["mandatory"] = True
        attrs.append({
            "infoplists": attr.label_list(
                allow_empty = False,
                allow_files = [".plist"],
                doc = """
A list of .plist files that will be merged to form the Info.plist for this target. At least one file
must be specified. Please see
[Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling)
for what is supported.
""",
                **attr_args
            ),
        })

    if rule_descriptor.requires_provisioning_profile:
        attrs.append({
            "provisioning_profile": attr.label(
                allow_single_file = [rule_descriptor.provisioning_profile_extension],
                doc = """
The provisioning profile (`{profile_extension}` file) to use when creating the bundle. This value is
optional for simulator builds as the simulator doesn't fully enforce entitlements, but is
required for device builds.
""".format(profile_extension = rule_descriptor.provisioning_profile_extension),
            ),
        })

    attrs.append({
        "bundle_name": attr.string(
            mandatory = False,
            doc = """
The desired name of the bundle (without the extension). If this attribute is not set, then the name
of the target will be used instead.
""",
        ),
        "executable_name": attr.string(
            mandatory = False,
            doc = """
The desired name of the executable, if the bundle has an executable. If this attribute is not set,
then the name of the `bundle_name` attribute will be used if it is set; if not, then the name of
the target will be used instead.
""",
        ),
        # TODO(b/36512239): Rename to "bundle_post_processor".
        "ipa_post_processor": attr.label(
            allow_files = True,
            executable = True,
            cfg = "host",
            doc = """
A tool that edits this target's archive after it is assembled but before it is signed. The tool is
invoked with a single command-line argument that denotes the path to a directory containing the
unzipped contents of the archive; this target's bundle will be the directory's only contents.

Any changes made by the tool must be made in this directory, and the tool's execution must be
hermetic given these inputs to ensure that the result can be safely cached.
""",
        ),
        "minimum_os_version": attr.string(
            mandatory = True,
            doc = """
A required string indicating the minimum OS version supported by the target, represented as a
dotted version number (for example, "9.0").
""",
        ),
        "strings": attr.label_list(
            allow_files = [".strings"],
            doc = """
A list of `.strings` files, often localizable. These files are converted to binary plists (if they
are not already) and placed in the root of the final bundle, unless a file's immediate containing
directory is named `*.lproj`, in which case it will be placed under a directory with the same name
in the bundle.
""",
        ),
        "resources": attr.label_list(
            allow_files = True,
            aspects = [apple_resource_aspect],
            doc = """
A list of resources or files bundled with the bundle. The resources will be stored in the
appropriate resources location within the bundle.
""",
        ),
        "version": attr.label(
            providers = [[AppleBundleVersionInfo]],
            doc = """
An `apple_bundle_version` target that represents the version for this target. See
[`apple_bundle_version`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-general.md?cl=head#apple_bundle_version).
""",
        ),
    })

    if len(rule_descriptor.allowed_device_families) > 1:
        extra_args = {}
        if not rule_descriptor.mandatory_families:
            extra_args["default"] = rule_descriptor.allowed_device_families
        attrs.append({
            "families": attr.string_list(
                mandatory = rule_descriptor.mandatory_families,
                allow_empty = False,
                doc = """
A list of device families supported by this extension. Valid values are `iphone` and `ipad`; at
least one must be specified.
""",
                **extra_args
            ),
        })

    if rule_descriptor.app_icon_extension:
        attrs.append({
            "app_icons": attr.label_list(
                allow_files = True,
                doc = """
Files that comprise the app icons for the application. Each file must have a containing directory
named `*.{app_icon_parent_extension}/*.{app_icon_extension}` and there may be only one such
`.{app_icon_extension}` directory in the list.""".format(
                    app_icon_extension = rule_descriptor.app_icon_extension,
                    app_icon_parent_extension = rule_descriptor.app_icon_parent_extension,
                ),
            ),
        })

    if rule_descriptor.has_launch_images:
        attrs.append({
            "launch_images": attr.label_list(
                allow_files = True,
                doc = """
Files that comprise the launch images for the application. Each file must have a containing
directory named `*.xcassets/*.launchimage` and there may be only one such `.launchimage` directory
in the list.
""",
            ),
        })

    if rule_descriptor.has_settings_bundle:
        attrs.append({
            "settings_bundle": attr.label(
                aspects = [apple_resource_aspect],
                providers = [["objc"], [AppleResourceBundleInfo]],
                doc = """
A resource bundle (e.g. `apple_bundle_import`) target that contains the files that make up the
application's settings bundle. These files will be copied into the root of the final application
bundle in a directory named `Settings.bundle`.
""",
            ),
        })

    if rule_descriptor.codesigning_exceptions == rule_support.codesigning_exceptions.none:
        attrs.append({
            "entitlements": attr.label(
                providers = [[], [AppleEntitlementsInfo]],
                doc = """
The entitlements file required for device builds of this target. If absent, the default entitlements
from the provisioning profile will be used.

The following variables are substituted in the entitlements file: `$(CFBundleIdentifier)` with the
bundle ID of the application and `$(AppIdentifierPrefix)` with the value of the
`ApplicationIdentifierPrefix` key from the target's provisioning profile.
""",
            ),
            "entitlements_validation": attr.string(
                default = entitlements_validation_mode.loose,
                doc = """
An `entitlements_validation_mode` to control the validation of the requested entitlements against
the provisioning profile to ensure they are supported.
""",
                values = [
                    entitlements_validation_mode.error,
                    entitlements_validation_mode.warn,
                    entitlements_validation_mode.loose,
                    entitlements_validation_mode.skip,
                ],
            ),
        })

    return attrs

def _get_ios_attrs(rule_descriptor):
    """Returns a list of dictionaries with attributes for the iOS platform."""
    attrs = []

    # TODO(kaipi): Add support for all valid product types for iOS.
    if rule_descriptor.product_type == apple_product_type.messages_sticker_pack_extension:
        attrs.append({
            "sticker_assets": attr.label_list(
                allow_files = True,
                doc = """
List of sticker files to bundle. The collection of assets should be under a folder named
`*.*.xcstickers`. The icons go in a `*.stickersiconset` (instead of `*.appiconset`); and the files
for the stickers should all be in Sticker Pack directories, so `*.stickerpack/*.sticker` or
`*.stickerpack/*.stickersequence`.
""",
            ),
        })
    elif rule_descriptor.product_type == apple_product_type.messages_application:
        attrs.append({
            "extension": attr.label(
                mandatory = True,
                providers = [
                    [AppleBundleInfo, IosImessageExtensionBundleInfo],
                    [AppleBundleInfo, IosStickerPackExtensionBundleInfo],
                ],
                doc = """
Single label referencing either an ios_imessage_extension or ios_sticker_pack_extension target.
Required.
""",
            ),
        })
    elif rule_descriptor.product_type == apple_product_type.framework:
        attrs.append({
            # TODO(kaipi): This attribute is not publicly documented, but it is tested in
            # http://github.com/bazelbuild/rules_apple/test/ios_framework_test.sh?l=79. Figure out
            # what to do with this.
            "hdrs": attr.label_list(
                allow_files = [".h"],
            ),
            "extension_safe": attr.bool(
                default = False,
                doc = """
If true, compiles and links this framework with `-application-extension`, restricting the binary to
use only extension-safe APIs.
""",
            ),
            "bundle_only": attr.bool(
                default = False,
                doc = """
Avoid linking the dynamic framework, but still include it in the app. This is useful when you want
to manually dlopen the framework at runtime.
""",
            ),
        })
    elif rule_descriptor.product_type == apple_product_type.static_framework:
        attrs.append({
            "hdrs": attr.label_list(
                allow_files = [".h"],
                doc = """
A list of `.h` files that will be publicly exposed by this framework. These headers should have
framework-relative imports, and if non-empty, an umbrella header named `%{bundle_name}.h` will also
be generated that imports all of the headers listed here.
""",
            ),
            "umbrella_header": attr.label(
                allow_single_file = [".h"],
                doc = """
An optional single .h file to use as the umbrella header for this framework. Usually, this header
will have the same name as this target, so that clients can load the header using the #import
<MyFramework/MyFramework.h> format. If this attribute is not specified (the common use case), an
umbrella header will be generated under the same name as this target.
""",
            ),
            "avoid_deps": attr.label_list(
                doc = """
A list of library targets on which this framework depends in order to compile, but the transitive
closure of which will not be linked into the framework's binary.
""",
            ),
            "exclude_resources": attr.bool(
                default = False,
                doc = """
Indicates whether resources should be excluded from the bundle. This can be used to avoid
unnecessarily bundling resources if the static framework is being distributed in a different
fashion, such as a Cocoapod.
""",
            ),
        })
    elif rule_descriptor.product_type == apple_product_type.application:
        attrs.append({
            "app_clips": attr.label_list(
                providers = [[AppleBundleInfo, IosAppClipBundleInfo]],
                doc = """
A list of iOS app clips to include in the final application bundle.
""",
            ),
            "extensions": attr.label_list(
                providers = [[AppleBundleInfo, IosExtensionBundleInfo]],
                doc = """
A list of iOS application extensions to include in the final application bundle.
""",
            ),
            "launch_storyboard": attr.label(
                allow_single_file = [".storyboard", ".xib"],
                doc = """
The `.storyboard` or `.xib` file that should be used as the launch screen for the application. The
provided file will be compiled into the appropriate format (`.storyboardc` or `.nib`) and placed in
the root of the final bundle. The generated file will also be registered in the bundle's
Info.plist under the key `UILaunchStoryboardName`.
""",
            ),
            "watch_application": attr.label(
                providers = [[AppleBundleInfo, WatchosApplicationBundleInfo]],
                doc = """
A `watchos_application` target that represents an Apple Watch application that should be embedded in
the application bundle.
""",
            ),
            "_runner_template": attr.label(
                cfg = "host",
                allow_single_file = True,
                default = Label("@build_bazel_rules_apple//apple/internal/templates:ios_sim_template"),
            ),
        })
    elif rule_descriptor.product_type == apple_product_type.app_clip:
        attrs.append({
            "launch_storyboard": attr.label(
                allow_single_file = [".storyboard", ".xib"],
                doc = """
The `.storyboard` or `.xib` file that should be used as the launch screen for the app clip. The
provided file will be compiled into the appropriate format (`.storyboardc` or `.nib`) and placed in
the root of the final bundle. The generated file will also be registered in the bundle's
Info.plist under the key `UILaunchStoryboardName`.
""",
            ),
            "_runner_template": attr.label(
                cfg = "host",
                allow_single_file = True,
                default = Label("@build_bazel_rules_apple//apple/internal/templates:ios_sim_template"),
            ),
        })
    elif rule_descriptor.product_type == apple_product_type.app_extension:
        attrs.append(_EXTENSION_PROVIDES_MAIN_ATTRS)
    elif _is_test_product_type(rule_descriptor.product_type):
        required_providers = [
            [AppleBundleInfo, IosApplicationBundleInfo],
            [AppleBundleInfo, IosExtensionBundleInfo],
        ]
        test_host_mandatory = False
        if rule_descriptor.product_type == apple_product_type.ui_test_bundle:
            required_providers.append([AppleBundleInfo, IosImessageApplicationBundleInfo])
            test_host_mandatory = True

        attrs.append({
            "test_host": attr.label(
                aspects = [framework_import_aspect],
                mandatory = test_host_mandatory,
                providers = required_providers,
            ),
        })

    # TODO(kaipi): Once all platforms have framework rules, move this into
    # _common_binary_linking_attrs().
    if rule_descriptor.requires_deps:
        extra_args = {}
        if (rule_descriptor.product_type == apple_product_type.application or
            rule_descriptor.product_type == apple_product_type.app_clip):
            extra_args["aspects"] = [framework_import_aspect]

        attrs.append({
            "frameworks": attr.label_list(
                providers = [[AppleBundleInfo, IosFrameworkBundleInfo]],
                doc = """
A list of framework targets (see
[`ios_framework`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-ios.md#ios_framework))
that this target depends on.
""",
                **extra_args
            ),
        })

    # TODO(b/XXXXXXXX): `sdk_frameworks` was never documented on `ios_application` but it leaked
    # through due to the old macro passing it to the underlying `apple_binary`. Support this
    # temporarily for a limited set of product types until we can migrate teams off the attribute,
    # once explicit build targets are used to propagate linking information for system frameworks.
    if (rule_descriptor.product_type == apple_product_type.application or
        rule_descriptor.product_type == apple_product_type.app_extension):
        attrs.append({
            "sdk_frameworks": attr.string_list(
                allow_empty = True,
                doc = """
Names of SDK frameworks to link with (e.g., `AddressBook`, `QuartzCore`).
`UIKit` and `Foundation` are always included, even if this attribute is
provided and does not list them.

This attribute is discouraged; in general, targets should list system
framework dependencies in the library targets where that framework is used,
not in the top-level bundle.
""",
            ),
        })

    return attrs

def _get_macos_attrs(rule_descriptor):
    """Returns a list of dictionaries with attributes for the macOS platform."""
    attrs = []

    attrs.append({
        "additional_contents": attr.label_keyed_string_dict(
            allow_files = True,
            doc = """
Files that should be copied into specific subdirectories of the Contents folder in the bundle. The
keys of this dictionary are labels pointing to single files, filegroups, or targets; the
corresponding value is the name of the subdirectory of Contents where they should be placed.

The relative directory structure of filegroup contents is preserved when they are copied into the
desired Contents subdirectory.
""",
        ),
    })

    if rule_descriptor.product_type in [apple_product_type.application, apple_product_type.bundle]:
        attrs.append({
            # TODO(b/117886202): This should be part of the rule descriptor, once the new
            # macos_kernel_extension, macos_spotlight_importer and macos_xpc_service rules are
            # extracted from macos_application and macos_bundle.
            "bundle_extension": attr.string(
                doc = """
The extension, without a leading dot, that will be used to name the bundle. If this attribute is not
set, then the default extension is determined by the application's product_type.
""",
            ),
        })

    if rule_descriptor.product_type == apple_product_type.application:
        attrs.append({
            "extensions": attr.label_list(
                providers = [
                    [AppleBundleInfo, MacosExtensionBundleInfo],
                ],
                doc = "A list of macOS extensions to include in the final application bundle.",
            ),
            "xpc_services": attr.label_list(
                providers = [
                    [AppleBundleInfo, MacosXPCServiceBundleInfo],
                ],
                doc = "A list of macOS XPC Services to include in the final application bundle.",
            ),
            "_runner_template": attr.label(
                cfg = "host",
                allow_single_file = True,
                default = Label("@build_bazel_rules_apple//apple/internal/templates:macos_template"),
            ),
        })

    elif rule_descriptor.product_type == apple_product_type.app_extension:
        attrs.append(_EXTENSION_PROVIDES_MAIN_ATTRS)

    elif _is_test_product_type(rule_descriptor.product_type):
        test_host_mandatory = rule_descriptor.product_type == apple_product_type.ui_test_bundle
        attrs.append({
            "test_host": attr.label(
                aspects = [framework_import_aspect],
                mandatory = test_host_mandatory,
                providers = [
                    [AppleBundleInfo, MacosApplicationBundleInfo],
                    [AppleBundleInfo, MacosExtensionBundleInfo],
                ],
            ),
        })

    return attrs

def _get_tvos_attrs(rule_descriptor):
    """Returns a list of dictionaries with attributes for the tvOS platform."""
    attrs = []

    if rule_descriptor.product_type == apple_product_type.application:
        attrs.append({
            "extensions": attr.label_list(
                providers = [
                    [AppleBundleInfo, TvosExtensionBundleInfo],
                ],
                doc = "A list of tvOS extensions to include in the final application bundle.",
            ),
            "_runner_template": attr.label(
                cfg = "host",
                allow_single_file = True,
                # Currently using the iOS Simulator template for tvOS, as tvOS does not require
                # significantly different sim runner logic from iOS.
                default = Label("@build_bazel_rules_apple//apple/internal/templates:ios_sim_template"),
            ),
        })
    elif rule_descriptor.product_type == apple_product_type.framework:
        attrs.append({
            # TODO(kaipi): This attribute is not publicly documented, but it is tested in
            # http://github.com/bazelbuild/rules_apple/test/ios_framework_test.sh?l=79. Figure out
            # what to do with this.
            "hdrs": attr.label_list(
                allow_files = [".h"],
            ),
            "extension_safe": attr.bool(
                default = False,
                doc = """
If true, compiles and links this framework with `-application-extension`, restricting the binary to
use only extension-safe APIs.
""",
            ),
        })
    elif rule_descriptor.product_type == apple_product_type.static_framework:
        attrs.append({
            "hdrs": attr.label_list(
                allow_files = [".h"],
                doc = """
A list of `.h` files that will be publicly exposed by this framework. These headers should have
framework-relative imports, and if non-empty, an umbrella header named `%{bundle_name}.h` will also
be generated that imports all of the headers listed here.
""",
            ),
            "umbrella_header": attr.label(
                allow_single_file = [".h"],
                doc = """
An optional single .h file to use as the umbrella header for this framework. Usually, this header
will have the same name as this target, so that clients can load the header using the #import
<MyFramework/MyFramework.h> format. If this attribute is not specified (the common use case), an
umbrella header will be generated under the same name as this target.
""",
            ),
            "avoid_deps": attr.label_list(
                doc = """
A list of library targets on which this framework depends in order to compile, but the transitive
closure of which will not be linked into the framework's binary.
""",
            ),
            "exclude_resources": attr.bool(
                default = False,
                doc = """
Indicates whether resources should be excluded from the bundle. This can be used to avoid
unnecessarily bundling resources if the static framework is being distributed in a different
fashion, such as a Cocoapod.
""",
            ),
        })
    elif _is_test_product_type(rule_descriptor.product_type):
        test_host_mandatory = rule_descriptor.product_type == apple_product_type.ui_test_bundle
        attrs.append({
            "test_host": attr.label(
                aspects = [framework_import_aspect],
                mandatory = test_host_mandatory,
                providers = [
                    [AppleBundleInfo, TvosApplicationBundleInfo],
                    [AppleBundleInfo, TvosExtensionBundleInfo],
                ],
            ),
        })

    # TODO(kaipi): Once all platforms have framework rules, move this into
    # _common_binary_linking_attrs().
    if rule_descriptor.requires_deps:
        extra_args = {}
        if rule_descriptor.product_type == apple_product_type.application:
            extra_args["aspects"] = [framework_import_aspect]

        attrs.append({
            "frameworks": attr.label_list(
                providers = [[AppleBundleInfo, TvosFrameworkBundleInfo]],
                doc = """
A list of framework targets (see
[`tvos_framework`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-tvos.md#tvos_framework))
that this target depends on.
""",
                **extra_args
            ),
        })

    return attrs

def _get_watchos_attrs(rule_descriptor):
    """Returns a list of dictionaries with attributes for the watchOS platform."""
    attrs = []

    if rule_descriptor.product_type == apple_product_type.watch2_extension:
        attrs.append({"extensions": attr.label_list(
            providers = [[AppleBundleInfo, WatchosExtensionBundleInfo]],
            doc = """
A list of watchOS application extensions to include in the final watch extension bundle.
""",
        )})
    if rule_descriptor.product_type == apple_product_type.watch2_application:
        attrs.append({
            "extension": attr.label(
                providers = [
                    [AppleBundleInfo, WatchosExtensionBundleInfo],
                ],
                doc = "The `watchos_extension` that is bundled with the watch application.",
            ),
            "storyboards": attr.label_list(
                allow_files = [".storyboard"],
                doc = """
A list of `.storyboard` files, often localizable. These files are compiled and placed in the root of
the final application bundle, unless a file's immediate containing directory is named `*.lproj`, in
which case it will be placed under a directory with the same name in the bundle.
""",
            ),
            # TODO(b/121201268): Rename this attribute as it implies code dependencies, but they are
            # not actually compiled and linked, since the watchOS application uses a stub binary.
            "deps": attr.label_list(
                aspects = [apple_resource_aspect],
                doc = """
A list of targets whose resources will be included in the final application. Since a watchOS
application does not contain any code of its own, any code in the dependent libraries will be
ignored.
""",
            ),
        })
    elif rule_descriptor.product_type == apple_product_type.framework:
        attrs.append({
            "extension_safe": attr.bool(
                default = False,
                doc = """
If true, compiles and links this framework with `-application-extension`, restricting the binary to
use only extension-safe APIs.
""",
            ),
        })

        if rule_descriptor.requires_deps:
            extra_args = {}
            attrs.append({
                "frameworks": attr.label_list(
                    providers = [[AppleBundleInfo, IosFrameworkBundleInfo]],
                    doc = """
A list of framework targets (see
[`ios_framework`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-ios.md#ios_framework))
that this target depends on.
""",
                    **extra_args
                ),
            })
    elif rule_descriptor.product_type == apple_product_type.static_framework:
        attrs.append({
            "hdrs": attr.label_list(
                allow_files = [".h"],
                doc = """
A list of `.h` files that will be publicly exposed by this framework. These headers should have
framework-relative imports, and if non-empty, an umbrella header named `%{bundle_name}.h` will also
be generated that imports all of the headers listed here.
""",
            ),
            "umbrella_header": attr.label(
                allow_single_file = [".h"],
                doc = """
An optional single .h file to use as the umbrella header for this framework. Usually, this header
will have the same name as this target, so that clients can load the header using the #import
<MyFramework/MyFramework.h> format. If this attribute is not specified (the common use case), an
umbrella header will be generated under the same name as this target.
""",
            ),
            "avoid_deps": attr.label_list(
                doc = """
A list of library targets on which this framework depends in order to compile, but the transitive
closure of which will not be linked into the framework's binary.
""",
            ),
            "exclude_resources": attr.bool(
                default = False,
                doc = """
Indicates whether resources should be excluded from the bundle. This can be used to avoid
unnecessarily bundling resources if the static framework is being distributed in a different
fashion, such as a Cocoapod.
""",
            ),
        })

    return attrs

def _get_macos_binary_attrs(rule_descriptor):
    """Returns a list of dictionaries with attributes for macOS binary rules."""
    attrs = []

    if rule_descriptor.requires_provisioning_profile:
        attrs.append({
            "provisioning_profile": attr.label(
                allow_single_file = [rule_descriptor.provisioning_profile_extension],
                doc = """
The provisioning profile (`{profile_extension}` file) to use when creating the bundle. This value is
optional for simulator builds as the simulator doesn't fully enforce entitlements, but is
required for device builds.
""".format(profile_extension = rule_descriptor.provisioning_profile_extension),
            ),
        })

    if rule_descriptor.product_type == apple_product_type.tool:
        # TODO(kaipi): Document this attribute.
        attrs.append({
            "launchdplists": attr.label_list(
                allow_files = [".plist"],
            ),
        })

    attrs.append({
        "bundle_id": attr.string(
            doc = """
The bundle ID (reverse-DNS path followed by app name) of the command line application. If present,
this value will be embedded in an Info.plist in the application binary.
""",
        ),
        "infoplists": attr.label_list(
            allow_files = [".plist"],
            doc = """
A list of .plist files that will be merged to form the Info.plist that represents the application
and is embedded into the binary. Please see
[Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling)
for what is supported.
""",
        ),
        "version": attr.label(
            providers = [[AppleBundleVersionInfo]],
            doc = """
An `apple_bundle_version` target that represents the version for this target. See
[`apple_bundle_version`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-general.md?cl=head#apple_bundle_version).
""",
        ),
    })

    return attrs

def _create_apple_binary_rule(
        implementation,
        doc,
        additional_attrs = {},
        implicit_outputs = None,
        platform_type = None,
        product_type = None):
    """Creates an Apple rule that produces a single binary output."""
    rule_attrs = [
        {
            "minimum_os_version": attr.string(
                mandatory = True,
                doc = """
A required string indicating the minimum OS version supported by the target, represented as a
dotted version number (for example, "10.11").
""",
            ),
            "_allowlist_function_transition": attr.label(
                default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
            ),
        },
    ]

    if platform_type:
        rule_attrs.extend([
            _COMMON_ATTRS,
            apple_support_toolchain_utils.shared_attrs(),
            {
                # TODO(kaipi): Make this attribute private when a platform_type is
                # specified. It is required by the native linking API.
                "platform_type": attr.string(default = platform_type),
                "_environment_plist": attr.label(
                    allow_single_file = True,
                    default = "@build_bazel_rules_apple//apple/internal:environment_plist_{}".format(
                        platform_type,
                    ),
                ),
            },
        ])
    else:
        rule_attrs.append({
            "platform_type": attr.string(
                doc = """
The target Apple platform for which to create a binary. This dictates which SDK
is used for compilation/linking and which flag is used to determine the
architectures to target. For example, if `ios` is specified, then the output
binaries/libraries will be created combining all architectures specified by
`--ios_multi_cpus`. Options are:

*   `ios`: architectures gathered from `--ios_multi_cpus`.
*   `macos`: architectures gathered from `--macos_cpus`.
*   `tvos`: architectures gathered from `--tvos_cpus`.
*   `watchos`: architectures gathered from `--watchos_cpus`.
""",
                mandatory = True,
            ),
        })

    if platform_type and product_type:
        rule_descriptor = rule_support.rule_descriptor_no_ctx(platform_type, product_type)
        is_executable = rule_descriptor.is_executable

        if rule_descriptor.requires_deps:
            rule_attrs.append(_common_binary_linking_attrs(
                default_binary_type = rule_descriptor.binary_type,
                deps_cfg = rule_descriptor.deps_cfg,
                product_type = product_type,
            ))

        rule_attrs.extend(
            [
                {"_product_type": attr.string(default = product_type)},
            ] + _get_macos_binary_attrs(rule_descriptor),
        )
    else:
        is_executable = False
        rule_attrs.append(_common_binary_linking_attrs(
            default_binary_type = "executable",
            deps_cfg = apple_common.multi_arch_split,
            product_type = None,
        ))

    rule_attrs.append(additional_attrs)

    return rule(
        implementation = implementation,
        # TODO(kaipi): Replace dicts.add with a version that errors on duplicate keys.
        attrs = dicts.add(*rule_attrs),
        cfg = transition_support.apple_rule_transition,
        doc = doc,
        executable = is_executable,
        fragments = ["apple", "cpp", "objc"],
        outputs = implicit_outputs,
    )

def _create_apple_bundling_rule(implementation, platform_type, product_type, doc):
    """Creates an Apple bundling rule."""
    rule_attrs = [
        {
            # TODO(kaipi): Make this attribute private. It is required by the native linking
            # API.
            "platform_type": attr.string(default = platform_type),
            "_product_type": attr.string(default = product_type),
            "_environment_plist": attr.label(
                allow_single_file = True,
                default = "@build_bazel_rules_apple//apple/internal:environment_plist_{}".format(platform_type),
            ),
        },
    ]

    rule_descriptor = rule_support.rule_descriptor_no_ctx(platform_type, product_type)

    rule_attrs.extend(
        [
            _COMMON_ATTRS,
            apple_support_toolchain_utils.shared_attrs(),
        ] + _get_common_bundling_attributes(rule_descriptor),
    )

    if rule_descriptor.requires_deps:
        rule_attrs.append(_common_binary_linking_attrs(
            default_binary_type = rule_descriptor.binary_type,
            deps_cfg = rule_descriptor.deps_cfg,
            product_type = product_type,
        ))

    is_test_product_type = _is_test_product_type(rule_descriptor.product_type)
    if is_test_product_type:
        # We need to add an explicit output attribute so that the output file name from the test
        # bundle target matches the test name, otherwise, it we'd be breaking the assumption that
        # ios_unit_test(name = "Foo") creates a :Foo.zip target.
        # This is an implementation detail attribute, so it's not documented on purpose.
        rule_attrs.append({"test_bundle_output": attr.output(mandatory = True)})

    # TODO(kaipi): Add support for all platforms.
    if platform_type == "ios":
        rule_attrs.extend(_get_ios_attrs(rule_descriptor))
    elif platform_type == "macos":
        rule_attrs.extend(_get_macos_attrs(rule_descriptor))
    elif platform_type == "tvos":
        rule_attrs.extend(_get_tvos_attrs(rule_descriptor))
    elif platform_type == "watchos":
        rule_attrs.extend(_get_watchos_attrs(rule_descriptor))

    rule_attrs.append({
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    })

    archive_name = "%{name}" + rule_descriptor.archive_extension
    return rule(
        implementation = implementation,
        # TODO(kaipi): Replace dicts.add with a version that errors on duplicate keys.
        attrs = dicts.add(*rule_attrs),
        cfg = transition_support.apple_rule_transition,
        doc = doc,
        executable = rule_descriptor.is_executable,
        fragments = ["apple", "cpp", "objc"],
        # TODO(kaipi): Remove the implicit output and use DefaultInfo instead.
        outputs = {"archive": archive_name},
    )

def _create_apple_test_rule(implementation, doc, platform_type):
    """Creates an Apple test rule."""

    # TODO(cl/264421322): Once Tulsi propagates this change, remove this attribute.
    extra_attrs = [{
        "platform_type": attr.string(default = platform_type),
    }]

    return rule(
        implementation = implementation,
        attrs = dicts.add(
            _COMMON_ATTRS,
            apple_support_toolchain_utils.shared_attrs(),
            _COMMON_TEST_ATTRS,
            *extra_attrs
        ),
        doc = doc,
        test = True,
    )

rule_factory = struct(
    common_tool_attributes = dicts.add(
        _COMMON_ATTRS,
        apple_support_toolchain_utils.shared_attrs(),
    ),
    create_apple_binary_rule = _create_apple_binary_rule,
    create_apple_bundling_rule = _create_apple_bundling_rule,
    create_apple_test_rule = _create_apple_test_rule,
)
