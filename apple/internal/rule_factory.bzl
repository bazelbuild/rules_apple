# Copyright 2018 The Bazel Authors. All rights reserved.
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
    "@build_bazel_rules_apple//apple/bundling:product_support.bzl",
    "apple_product_type",
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
    "IosFrameworkBundleInfo",
    "IosImessageExtensionBundleInfo",
    "IosStickerPackExtensionBundleInfo",
)
load(
    "@build_bazel_rules_swift//swift:swift.bzl",
    "swift_usage_aspect",
)
load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)

# Private attributes on every rule that provide access to tools and other file dependencies.
_COMMON_PRIVATE_TOOL_ATTRS = {
    "_bundletool": attr.label(
        cfg = "host",
        executable = True,
        default = Label("@build_bazel_rules_apple//tools/bundletool"),
    ),
    "_bundletool_experimental": attr.label(
        cfg = "host",
        executable = True,
        default = Label("@build_bazel_rules_apple//tools/bundletool:bundletool_experimental"),
    ),
    "_environment_plist": attr.label(
        cfg = "host",
        executable = True,
        default = Label("@build_bazel_rules_apple//tools/environment_plist"),
    ),
    "_plisttool": attr.label(
        cfg = "host",
        default = Label("@build_bazel_rules_apple//tools/plisttool"),
        executable = True,
    ),
    "_process_and_sign_template": attr.label(
        allow_single_file = True,
        default = Label("@build_bazel_rules_apple//tools/bundletool:process_and_sign_template"),
    ),
    # TODO(b/117933004): Find out whether realpath is still needed for symlinking, and if not,
    # remove this attribute, which is still used by file_actions.symlink.
    "_realpath": attr.label(
        cfg = "host",
        allow_single_file = True,
        default = Label("@build_bazel_rules_apple//tools/realpath"),
    ),
    "_xcode_config": attr.label(
        default = configuration_field(
            name = "xcode_config_label",
            fragment = "apple",
        ),
    ),
    # TODO(b/117932394): Remove uses of this private attribute and migrate them to the _xctoolrunner
    # tool instead.
    "_xcrunwrapper": attr.label(
        cfg = "host",
        executable = True,
        default = Label("@bazel_tools//tools/objc:xcrunwrapper"),
    ),
    "_xctoolrunner": attr.label(
        cfg = "host",
        executable = True,
        default = Label("@build_bazel_rules_apple//tools/xctoolrunner"),
    ),
}

_COMMON_BINARY_LINKING_ATTRS = {
    "_cc_toolchain": attr.label(
        default = configuration_field(
            name = "cc_toolchain",
            fragment = "cpp",
        ),
    ),
    "_child_configuration_dummy": attr.label(
        cfg = apple_common.multi_arch_split,
        default = configuration_field(
            name = "cc_toolchain",
            fragment = "cpp",
        ),
    ),
    "_googlemac_proto_compiler": attr.label(
        cfg = "host",
        default = Label("@bazel_tools//tools/objc:protobuf_compiler_wrapper"),
    ),
    "_googlemac_proto_compiler_support": attr.label(
        cfg = "host",
        default = Label("@bazel_tools//tools/objc:protobuf_compiler_support"),
    ),
    "_protobuf_well_known_types": attr.label(
        cfg = "host",
        default = Label("@bazel_tools//tools/objc:protobuf_well_known_types"),
    ),
    "binary_type": attr.string(
        default = "executable",
        doc = """
This attribute is public as an implementation detail while we migrate the architecture of the rules.
Do not change its value.
""",
    ),
    "bundle_loader": attr.label(
        aspects = [apple_common.objc_proto_aspect],
        doc = """
This attribute is public as an implementation detail while we migrate the architecture of the rules.
Do not change its value.
""",
    ),
    "deps": attr.label_list(
        aspects = [
            apple_common.objc_proto_aspect,
            apple_resource_aspect,
            framework_import_aspect,
            swift_usage_aspect,
        ],
        cfg = apple_common.multi_arch_split,
        doc = """
A list of dependencies targets that will be linked into this target's binary. Any resources, such as
asset catalogs, that are referenced by those targets will also be transitively included in the final
bundle.
""",
    ),
    "dylibs": attr.label_list(
        aspects = [apple_common.objc_proto_aspect],
        doc = """
This attribute is public as an implementation detail while we migrate the architecture of the rules.
Do not change its value.
""",
    ),
    "linkopts": attr.string_list(
        doc = """
A list of strings representing extra flags that should be passed to the linker.
""",
    ),
}

def _get_legacy_attributes(rule_descriptor):
    """Returns a dictionary with legacy attributes that should get replaced by rule descriptors."""

    # TODO(b/117933005): Remove these attributes once the uses of these are migrated to retrieving
    # these configs from the rule descriptors.
    return {
        "_allowed_families": attr.string_list(default = rule_descriptor.allowed_device_families),
        "_needs_pkginfo": attr.bool(default = rule_descriptor.requires_pkginfo),
        "_requires_signing_for_device": attr.bool(
            default = rule_descriptor.requires_signing_for_device,
        ),
        "_skip_signing": attr.bool(default = rule_descriptor.skip_signing),
        "_skip_simulator_signing_allowed": attr.bool(
            default = rule_descriptor.skip_simulator_signing_allowed,
        ),
    }

def _get_common_bundling_attributes(rule_descriptor):
    """Returns a list of dictionaries with attributes common to all bundling rules."""

    # TODO(kaipi): Review platform specific wording in the documentation before migrating macOS
    # rules to use this rule factory.
    attrs = [_COMMON_PRIVATE_TOOL_ATTRS]
    attrs.append({
        "bundle_id": attr.string(
            mandatory = True,
            doc = "The bundle ID (reverse-DNS path followed by app name) for this target.",
        ),
        "bundle_name": attr.string(
            mandatory = False,
            doc = """
The desired name of the bundle (without the extension). If this attribute is not set, then the name
of the target will be used instead.
""",
        ),
        "infoplists": attr.label_list(
            allow_empty = False,
            allow_files = [".plist"],
            mandatory = True,
            doc = """
A list of .plist files that will be merged to form the Info.plist for this target. At least one file
must be specified. Please see
[Info.plist Handling](https://github.com/bazelbuild/rules_apple/blob/master/doc/common_info.md#infoplist-handling)
for what is supported.
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
An optional string indicating the minimum OS version supported by the target, represented as a
dotted version number (for example, "9.0"). If this attribute is omitted, then the value specified
by the flag `--ios_minimum_os` will be used instead.
""",
        ),
        "provisioning_profile": attr.label(
            allow_single_file = [rule_descriptor.provisioning_profile_extension],
            doc = """
The provisioning profile (`{profile_extension}` file) to use when creating the bundle. This value is
optional for simulator builds as the simulator doesn't fully enforce entitlements, but is
required for device builds.
""".format(profile_extension = rule_descriptor.provisioning_profile_extension),
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
        "version": attr.label(
            providers = [[AppleBundleVersionInfo]],
            doc = """
An `apple_bundle_version` target that represents the version for this target. See
[`apple_bundle_version`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-general.md?cl=head#apple_bundle_version).
""",
        ),
    })

    if len(rule_descriptor.allowed_device_families):
        attrs.append({
            "families": attr.string_list(
                mandatory = True,
                allow_empty = False,
                doc = """
A list of device families supported by this extension. Valid values are `iphone` and `ipad`; at
least one must be specified.
""",
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

    if rule_descriptor.requires_deps:
        attrs.append({
            "entitlements": attr.label(
                allow_single_file = [".entitlements"],
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

    # TODO(kaipi): Once all platforms have framework rules, move this into
    # _COMMON_BINARY_LINKING_ATTRS.
    if rule_descriptor.requires_deps:
        attrs.append({
            "frameworks": attr.label_list(
                providers = [[AppleBundleInfo, IosFrameworkBundleInfo]],
                doc = """
A list of framework targets (see
[`ios_framework`](https://github.com/bazelbuild/rules_apple/blob/master/doc/rules-ios.md#ios_framework))
that this target depends on.
""",
            ),
        })

    return attrs

def _create_apple_bundling_rule(implementation, platform_type, product_type, doc):
    """Creates an Apple bundling rule."""
    rule_attrs = [
        {
            # TODO(kaipi): Make these attributes private. They are required by the native linking
            # API and product_support.
            "platform_type": attr.string(default = platform_type),
            "product_type": attr.string(default = product_type),
        },
    ]

    rule_descriptor = rule_support.rule_descriptor_no_ctx(platform_type, product_type)

    rule_attrs.extend(_get_common_bundling_attributes(rule_descriptor))
    rule_attrs.append(_get_legacy_attributes(rule_descriptor))

    if rule_descriptor.requires_deps:
        rule_attrs.append(_COMMON_BINARY_LINKING_ATTRS)

    # TODO(kaipi): Add support for all platforms.
    if platform_type == "ios":
        rule_attrs.extend(_get_ios_attrs(rule_descriptor))

    archive_name = "%{name}" + rule_descriptor.archive_extension
    return rule(
        implementation = implementation,
        # TODO(kaipi): Replace dicts.add with a version that errors on duplicate keys.
        attrs = dicts.add(*rule_attrs),
        doc = doc,
        fragments = ["apple", "cpp", "objc"],
        # TODO(kaipi): Remove the implicit output and use DefaultInfo instead.
        outputs = {"archive": archive_name},
    )

rule_factory = struct(
    create_apple_bundling_rule = _create_apple_bundling_rule,
)
