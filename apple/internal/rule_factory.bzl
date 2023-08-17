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
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/internal:rule_attrs.bzl",
    "rule_attrs",
)
load(
    "@build_bazel_rules_apple//apple/internal:transition_support.bzl",
    "transition_support",
)
load(
    "@build_bazel_rules_apple//apple/internal/aspects:framework_provider_aspect.bzl",
    "framework_provider_aspect",
)
load(
    "@build_bazel_rules_apple//apple/internal/aspects:resource_aspect.bzl",
    "apple_resource_aspect",
)
load(
    "@build_bazel_rules_apple//apple/internal/aspects:swift_dynamic_framework_aspect.bzl",
    "swift_dynamic_framework_aspect",
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
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
    "AppleBundleVersionInfo",
    "ApplePlatformInfo",
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
    "MacosFrameworkBundleInfo",
    "MacosXPCServiceBundleInfo",
    "TvosApplicationBundleInfo",
    "TvosExtensionBundleInfo",
    "TvosFrameworkBundleInfo",
    "WatchosApplicationBundleInfo",
    "WatchosSingleTargetApplicationBundleInfo",
)
load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "use_cpp_toolchain")

def _is_test_product_type(product_type):
    """Returns whether the given product type is for tests purposes or not."""
    return product_type in (
        apple_product_type.ui_test_bundle,
        apple_product_type.unit_test_bundle,
    )

# Returns the common set of rule attributes to support Apple test rules.
# TODO(b/246990309): Move _COMMON_TEST_ATTRS to rule attrs in a follow up CL.
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
    "_apple_coverage_support": attr.label(
        cfg = "exec",
        default = Label("@build_bazel_apple_support//tools:coverage_support"),
    ),
    "_lcov_merger": attr.label(
        default = configuration_field(
            fragment = "coverage",
            name = "output_generator",
        ),
        cfg = "exec",
    ),
    "test_filter": attr.string(
        doc = """
Test filter string that will be passed into the test runner to select which tests will run.
""",
        default = "",
    ),
    "test_coverage_manifest": attr.label(
        doc = """
A file that will be used in lcov export calls to limit the scope of files instrumented with coverage.
""",
        allow_single_file = True,
    ),
    "bundle_name": attr.string(
        mandatory = False,
        doc = """
The desired name of the bundle (without the extension). If this attribute is not set, then the name
of the target will be used instead.
""",
    ),
}

def _get_common_bundling_attributes(deps_cfg, rule_descriptor):
    """Returns a list of dictionaries with attributes common to all bundling rules."""

    attrs = []

    if rule_descriptor.requires_bundle_id:
        bundle_id_mandatory = not _is_test_product_type(rule_descriptor.product_type)
        attrs.append(rule_attrs.bundle_id_attrs(is_mandatory = bundle_id_mandatory))

    if rule_descriptor.has_infoplist:
        attrs.append(rule_attrs.infoplist_attrs(default_infoplist = rule_descriptor.default_infoplist))

    if rule_descriptor.requires_provisioning_profile:
        attrs.append(
            rule_attrs.provisioning_profile_attrs(
                profile_extension = rule_descriptor.provisioning_profile_extension,
            ),
        )

    attrs.append(rule_attrs.common_bundle_attrs(deps_cfg = deps_cfg))

    if rule_descriptor.product_type != apple_product_type.static_framework:
        attrs.append({
            "version": attr.label(
                providers = [[AppleBundleVersionInfo]],
                doc = """
An `apple_bundle_version` target that represents the version for this target. See
[`apple_bundle_version`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-versioning.md#apple_bundle_version).
""",
            ),
        })

    if len(rule_descriptor.allowed_device_families) > 1:
        attrs.append(rule_attrs.device_family_attrs(
            allowed_families = rule_descriptor.allowed_device_families,
            is_mandatory = rule_descriptor.mandatory_families,
        ))

    if rule_descriptor.app_icon_extension:
        attrs.append(rule_attrs.app_icon_attrs(
            icon_extension = rule_descriptor.app_icon_extension,
            icon_parent_extension = rule_descriptor.app_icon_parent_extension,
        ))

    if rule_descriptor.has_alternate_icons:
        attrs.append({
            "alternate_icons": attr.label_list(
                allow_files = True,
                doc = """
Files that comprise the alternate app icons for the application. Each file must have a containing directory
named after the alternate icon identifier.""",
            ),
        })

    if rule_descriptor.has_launch_images:
        attrs.append(rule_attrs.launch_images_attrs)

    if rule_descriptor.has_settings_bundle:
        attrs.append(rule_attrs.settings_bundle_attrs)

    if rule_descriptor.codesigning_exceptions == rule_support.codesigning_exceptions.none:
        attrs.append(rule_attrs.entitlements_attrs)

    return attrs

def _get_ios_attrs(rule_descriptor):
    """Returns a list of dictionaries with attributes for the iOS platform."""
    attrs = []

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
            "_emitswiftinterface": attr.bool(
                default = True,
                doc = "Private attribute to generate Swift interfaces for static frameworks.",
            ),
            "_cc_toolchain_forwarder": attr.label(
                cfg = transition_support.apple_platform_split_transition,
                providers = [cc_common.CcToolchainInfo, ApplePlatformInfo],
                default =
                    "@build_bazel_rules_apple//apple:default_cc_toolchain_forwarder",
            ),
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
                cfg = transition_support.apple_platform_split_transition,
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
                providers = [
                    [AppleBundleInfo, WatchosApplicationBundleInfo],
                    [AppleBundleInfo, WatchosSingleTargetApplicationBundleInfo],
                ],
                doc = """
A `watchos_application` target that represents an Apple Watch application or a
`watchos_single_target_application` target that represents a single-target Apple Watch application
that should be embedded in the application bundle.
""",
            ),
            "_runner_template": attr.label(
                cfg = "exec",
                allow_single_file = True,
                default = Label("@build_bazel_rules_apple//apple/internal/templates:ios_sim_template"),
            ),
            "include_symbols_in_bundle": attr.bool(
                default = False,
                doc = """
If true and `--output_groups=+dsyms` and `--apple_generate_dsym` are specified, generates
`$UUID.symbols` files from all `{binary: .dSYM, ...}` pairs for the application and its
dependencies, then packages them under the `Symbols/` directory in the final application bundle.
""",
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
                cfg = "exec",
                allow_single_file = True,
                default = Label("@build_bazel_rules_apple//apple/internal/templates:ios_sim_template"),
            ),
        })
    elif _is_test_product_type(rule_descriptor.product_type):
        required_providers = [
            [AppleBundleInfo, IosApplicationBundleInfo],
            [AppleBundleInfo, IosExtensionBundleInfo],
        ]
        test_host_mandatory = False
        if rule_descriptor.product_type == apple_product_type.ui_test_bundle:
            required_providers.append([AppleBundleInfo, IosImessageApplicationBundleInfo])
            test_host_mandatory = True

        attrs.append(rule_attrs.test_host_attrs(
            aspects = rule_attrs.aspects.test_host_aspects,
            is_mandatory = test_host_mandatory,
            providers = required_providers,
        ))

        attrs.append({
            "_swizzle_absolute_xcttestsourcelocation": attr.label(
                default = Label(
                    "@build_bazel_apple_support//lib:swizzle_absolute_xcttestsourcelocation",
                ),
            ),
        })

    if rule_descriptor.requires_deps:
        extra_args = {}
        if (rule_descriptor.product_type == apple_product_type.application or
            rule_descriptor.product_type == apple_product_type.app_clip):
            extra_args["aspects"] = [framework_provider_aspect]

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

    # TODO(b/162600187): `sdk_frameworks` was never documented on `ios_application` but it leaked
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

    if rule_descriptor.product_type == apple_product_type.bundle:
        attrs.append({
            "bundle_extension": attr.string(
                doc = """
The extension, without a leading dot, that will be used to name the bundle. If this attribute is not
set, then the extension will be `.bundle`.
""",
            ),
            "bundle_loader": attr.label(
                doc = """
The target representing the executable that will be loading this bundle. Undefined symbols from the
bundle are checked against this execuable during linking as if it were one of the dynamic libraries
the bundle was linked with.
""",
                providers = [apple_common.AppleExecutableBinary],
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
                cfg = "exec",
                allow_single_file = True,
                default = Label("@build_bazel_rules_apple//apple/internal/templates:macos_template"),
            ),
            "include_symbols_in_bundle": attr.bool(
                default = False,
                doc = """
    If true and --output_groups=+dsyms is specified, generates `$UUID.symbols`
    files from all `{binary: .dSYM, ...}` pairs for the application and its
    dependencies, then packages them under the `Symbols/` directory in the
    final application bundle.
    """,
            ),
        })
    elif rule_descriptor.product_type == apple_product_type.framework:
        attrs.append({
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
            "_emitswiftinterface": attr.bool(
                default = True,
                doc = "Private attribute to generate Swift interfaces for static frameworks.",
            ),
            "_cc_toolchain_forwarder": attr.label(
                cfg = transition_support.apple_platform_split_transition,
                providers = [cc_common.CcToolchainInfo, ApplePlatformInfo],
                default =
                    "@build_bazel_rules_apple//apple:default_cc_toolchain_forwarder",
            ),
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
                cfg = transition_support.apple_platform_split_transition,
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
fashion, such as CocoaPods.
""",
            ),
        })
    elif _is_test_product_type(rule_descriptor.product_type):
        test_host_mandatory = rule_descriptor.product_type == apple_product_type.ui_test_bundle
        attrs.append(
            rule_attrs.test_host_attrs(
                aspects = rule_attrs.aspects.test_host_aspects,
                is_mandatory = test_host_mandatory,
                providers = [
                    [AppleBundleInfo, MacosApplicationBundleInfo],
                    [AppleBundleInfo, MacosExtensionBundleInfo],
                ],
            ),
        )

        attrs.append({
            "_swizzle_absolute_xcttestsourcelocation": attr.label(
                default = Label(
                    "@build_bazel_apple_support//lib:swizzle_absolute_xcttestsourcelocation",
                ),
            ),
        })

    # TODO(kaipi): Once all platforms have framework rules, move this into
    # _common_binary_linking_attrs().
    if rule_descriptor.requires_deps:
        extra_args = {}
        if (rule_descriptor.product_type == apple_product_type.application or
            rule_descriptor.product_type == apple_product_type.app_clip):
            extra_args["aspects"] = [framework_provider_aspect]

        attrs.append({
            "frameworks": attr.label_list(
                providers = [[AppleBundleInfo, MacosFrameworkBundleInfo]],
                doc = """
A list of framework targets (see
[`macos_framework`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-macos.md#macos_framework))
that this target depends on.
""",
                **extra_args
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
                cfg = "exec",
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
            "_emitswiftinterface": attr.bool(
                default = True,
                doc = "Private attribute to generate Swift interfaces for static frameworks.",
            ),
            "_cc_toolchain_forwarder": attr.label(
                cfg = transition_support.apple_platform_split_transition,
                providers = [cc_common.CcToolchainInfo, ApplePlatformInfo],
                default =
                    "@build_bazel_rules_apple//apple:default_cc_toolchain_forwarder",
            ),
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
                cfg = transition_support.apple_platform_split_transition,
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
        attrs.append(
            rule_attrs.test_host_attrs(
                aspects = rule_attrs.aspects.test_host_aspects,
                is_mandatory = test_host_mandatory,
                providers = [
                    [AppleBundleInfo, TvosApplicationBundleInfo],
                    [AppleBundleInfo, TvosExtensionBundleInfo],
                ],
            ),
        )

        attrs.append({
            "_swizzle_absolute_xcttestsourcelocation": attr.label(
                default = Label(
                    "@build_bazel_apple_support//lib:swizzle_absolute_xcttestsourcelocation",
                ),
            ),
        })

    if rule_descriptor.requires_deps:
        extra_args = {}
        if rule_descriptor.product_type == apple_product_type.application:
            extra_args["aspects"] = [framework_provider_aspect]

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
[`apple_bundle_version`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-versioning.md#apple_bundle_version).
""",
        ),
    })

    return attrs

def _create_apple_binary_rule(
        implementation,
        doc,
        additional_attrs = {},
        cfg = transition_support.apple_rule_transition,
        platform_type = None,
        product_type = None,
        require_linking_attrs = True):
    """Creates an Apple rule that produces a single binary output."""
    attrs = [
        {
            "_allowlist_function_transition": attr.label(
                default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
            ),
        },
    ]

    if platform_type:
        attrs.extend([
            rule_attrs.common_tool_attrs,
            rule_attrs.platform_attrs(platform_type = platform_type, add_environment_plist = True),
        ])
    else:
        attrs.append(rule_attrs.platform_attrs())

    extra_deps_aspects = []
    if product_type == apple_product_type.framework:
        extra_deps_aspects.append(swift_dynamic_framework_aspect)

    if platform_type and product_type:
        rule_descriptor = rule_support.rule_descriptor(
            platform_type = platform_type,
            product_type = product_type,
        )
        is_executable = rule_descriptor.is_executable

        if rule_descriptor.requires_deps:
            attrs.append(rule_attrs.binary_linking_attrs(
                deps_cfg = rule_descriptor.deps_cfg,
                extra_deps_aspects = [
                    apple_resource_aspect,
                    framework_provider_aspect,
                ] + extra_deps_aspects,
                is_test_supporting_rule = _is_test_product_type(product_type),
                requires_legacy_cc_toolchain = True,
            ))

        attrs.extend(
            [
                {"_product_type": attr.string(default = product_type)},
            ] + _get_macos_binary_attrs(rule_descriptor),
        )
    else:
        is_executable = False
        if require_linking_attrs:
            attrs.append(rule_attrs.binary_linking_attrs(
                deps_cfg = transition_support.apple_platform_split_transition,
                extra_deps_aspects = extra_deps_aspects,
                is_test_supporting_rule = False,
                requires_legacy_cc_toolchain = True,
            ))
        else:
            attrs.append(rule_attrs.common_attrs)

    attrs.append(additional_attrs)

    return rule(
        implementation = implementation,
        attrs = dicts.add(*attrs),
        cfg = cfg,
        doc = doc,
        executable = is_executable,
        fragments = ["apple", "cpp", "objc"],
        toolchains = use_cpp_toolchain(),
    )

def _create_apple_bundling_rule(
        implementation,
        platform_type,
        product_type,
        doc,
        cfg = transition_support.apple_rule_transition):
    """Creates an Apple bundling rule."""
    attrs = [
        dicts.add(
            rule_attrs.platform_attrs(platform_type = platform_type, add_environment_plist = True),
            {
                "_product_type": attr.string(default = product_type),
            },
        ),
    ]

    rule_descriptor = rule_support.rule_descriptor(
        platform_type = platform_type,
        product_type = product_type,
    )

    attrs.extend([rule_attrs.common_tool_attrs] + _get_common_bundling_attributes(
        deps_cfg = rule_descriptor.deps_cfg,
        rule_descriptor = rule_descriptor,
    ))

    if rule_descriptor.requires_deps:
        extra_deps_aspects = []
        if product_type == apple_product_type.framework:
            extra_deps_aspects.append(swift_dynamic_framework_aspect)

        attrs.append(rule_attrs.binary_linking_attrs(
            deps_cfg = rule_descriptor.deps_cfg,
            extra_deps_aspects = [
                apple_resource_aspect,
                framework_provider_aspect,
            ] + extra_deps_aspects,
            is_test_supporting_rule = _is_test_product_type(product_type),
            requires_legacy_cc_toolchain = True,
        ))

    is_test_product_type = _is_test_product_type(rule_descriptor.product_type)
    if is_test_product_type:
        # We need to add an explicit output attribute so that the output file name from the test
        # bundle target matches the test name, otherwise, it we'd be breaking the assumption that
        # ios_unit_test(name = "Foo") creates a :Foo.zip target.
        # This is an implementation detail attribute, so it's not documented on purpose.
        attrs.append(rule_attrs.test_bundle_attrs)

    # TODO(b/246990309): Move the other platform types off of this rule and onto the equivalent with
    # _create_apple_bundling_rule_with_attrs(...).
    if platform_type == "ios":
        attrs.extend(_get_ios_attrs(rule_descriptor))
    elif platform_type == "macos":
        attrs.extend(_get_macos_attrs(rule_descriptor))
    elif platform_type == "tvos":
        attrs.extend(_get_tvos_attrs(rule_descriptor))
    else:
        fail((
            "Internal Error: platform_type of \"{platform_type}\" is no longer supported by " +
            "_create_apple_bundling_rule(...) . Please file an issue against the Apple rules if " +
            "you are seeing this problem when using an existing rule."
        ).format(
            platform_type = platform_type,
        ))

    attrs.append({
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    })

    archive_name = "%{name}" + rule_descriptor.archive_extension
    return rule(
        implementation = implementation,
        attrs = dicts.add(*attrs),
        cfg = cfg,
        doc = doc,
        executable = rule_descriptor.is_executable,
        fragments = ["apple", "cpp", "objc"],
        outputs = {"archive": archive_name},
        toolchains = use_cpp_toolchain(),
    )

def _create_apple_bundling_rule_with_attrs(
        *,
        archive_extension = ".zip",
        attrs,
        cfg = transition_support.apple_rule_transition,
        doc,
        implementation,
        is_executable = False):
    """Creates an Apple bundling rule with additional control of the set of rule attributes.

    Args:
        archive_extension: An extension to be applied to the generated archive file. Optional. This
            will be `.zip` by default.
        attrs: A list of dictionaries of attributes to be applied to the generated rule.
        cfg: The rule transition to be applied directly on the generated rule. Optional. This will
            be the Starlark Apple rule transition `transition_support.apple_rule_transition` by
            default.
        doc: The documentation string for the rule itself.
        implementation: The method to handle the implementation of the given rule.
        is_executable: Boolean. If set to True, marks the rule as executable. Optional. False by
            default.
    """

    return rule(
        implementation = implementation,
        attrs = dicts.add(
            {
                # Required to use the Apple Starlark rule and split transitions.
                "_allowlist_function_transition": attr.label(
                    default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
                ),
            },
            *attrs
        ),
        cfg = cfg,
        doc = doc,
        executable = is_executable,
        fragments = ["apple", "cpp", "objc"],
        outputs = {"archive": "%{name}" + archive_extension},
        toolchains = use_cpp_toolchain(),
    )

def _create_apple_test_rule(implementation, doc, platform_type):
    """Creates an Apple test rule."""

    # These attrs are exposed for IDE experiences via `bazel query` as long as these test rules are
    # split between an actual test rule and a test bundle rule generated by a macro.
    #
    # These attrs are not required for linking the test rule itself. However, similarly named attrs
    # are all used for linking the test bundle target that is an implementation detail of the macros
    # that generate Apple tests. That information is still of interest to IDEs via `bazel query`.
    ide_visible_attrs = [
        # The private environment plist attr is omitted as it's of no use to IDE experiences.
        rule_attrs.platform_attrs(platform_type = platform_type),
        # The aspect is withheld to avoid unnecessary overhead in this instance of `test_host`, and
        # the provider is unnecessarily generic to accomodate any possible value of `test_host`.
        rule_attrs.test_host_attrs(aspects = [], providers = [[AppleBundleInfo]]),
    ]

    return rule(
        implementation = implementation,
        attrs = dicts.add(
            rule_attrs.common_tool_attrs,
            _COMMON_TEST_ATTRS,
            *ide_visible_attrs
        ),
        doc = doc,
        test = True,
        toolchains = use_cpp_toolchain(),
    )

rule_factory = struct(
    create_apple_binary_rule = _create_apple_binary_rule,
    create_apple_bundling_rule = _create_apple_bundling_rule,
    create_apple_bundling_rule_with_attrs = _create_apple_bundling_rule_with_attrs,
    create_apple_test_rule = _create_apple_test_rule,
)
