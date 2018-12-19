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

"""Support for describing rule implementations.

The main purpose of this file is to have a central location that fully describes how a rule
implementation should behave, based only on the platform and product type. In previous
implementations of the rules, these information would be encoded in multiple private attributes.
With this approach, both rule definition and implementation infrastructure can access the same
parameters that affect both the attributes and the implementation logic of the rules.
"""

load(
    "@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling:product_support.bzl",
    "apple_product_type",
    "product_support",
)

def _describe_bundle_locations(
        archive_relative = "",
        bundle_relative_contents = "",
        contents_relative_binary = "",
        contents_relative_frameworks = "Frameworks",
        contents_relative_plugins = "PlugIns",
        contents_relative_resources = "",
        contents_relative_watch = "Watch"):
    """Creates a descriptor of locations for different types of artifacts within an Apple bundle."""
    return struct(
        archive_relative = archive_relative,
        bundle_relative_contents = bundle_relative_contents,
        contents_relative_binary = contents_relative_binary,
        contents_relative_frameworks = contents_relative_frameworks,
        contents_relative_plugins = contents_relative_plugins,
        contents_relative_resources = contents_relative_resources,
        contents_relative_watch = contents_relative_watch,
    )

def _describe_rule_type(
        additional_infoplist_values = None,
        allowed_device_families = None,
        app_icon_extension = None,
        app_icon_parent_extension = None,
        archive_extension = ".zip",
        bundle_extension = None,
        bundle_locations = None,
        deps_cfg = None,
        has_infoplist = True,
        has_launch_images = False,
        has_settings_bundle = False,
        is_executable = False,
        mandatory_families = False,
        product_type = None,
        provisioning_profile_extension = ".mobileprovision",
        requires_bundle_id = True,
        requires_deps = True,
        requires_pkginfo = False,
        requires_provisioning_profile = True,
        requires_signing_for_device = True,
        skip_signing = False,
        skip_simulator_signing_allowed = True,
        stub_binary_path = None):
    """Creates a rule descriptor struct containing all the platform and product specific configs.

    Args:
        additional_infoplist_values: Dictionary of additional values to set into the rule's
            Info.plist.
        allowed_device_families: If given, the list of device families that this rule supports.
        app_icon_extension: For rules that require icons, the extension of the directory that should
            hold the icons (e.g. .appiconset).
        app_icon_parent_extension: For rules that require icons, the extension of the asset catalog
            that should hold the icon sets (e.g. .xcassets or .xcstickers).
        archive_extension: Extension for the archive output of the rule.
        bundle_extension: Extension for the Apple bundle inside the archive.
        bundle_locations: Struct with expected bundle locations for different types of artifacts.
        deps_cfg: The configuration for the deps attribute. This should be None for rules that use
            the apple_binary intermediate target, and apple_common.multi_arch_split for the rules
            that use the Starlark linking API.
        has_infoplist: Whether the rule should place an Info.plist file at the root of the bundle.
        has_launch_images: Whether the rule supports launch images.
        has_settings_bundle: Whether the rule supports a settings bundle.
        is_executable: Whether targets of this rule can be executed with `bazel run`.
        mandatory_families: If there are multiple families to choose from, whether the user is
            required to provide a value for them.
        product_type: The product type for this rule.
        provisioning_profile_extension: Extension for the expected provisioning profile files for
            this rule.
        requires_bundle_id: Whether the rule requires a bundle ID.
        requires_deps: Whether this rule has a user linked binary and accepts dependencies to be
            linked into the binary.
        requires_pkginfo: Whether the PkgInfo file should be included inside the rule's bundle.
        requires_provisioning_profile: Whether the rule requires a provisioning profile when
            building for devices.
        requires_signing_for_device: Whether signing is required when building for devices (as
            opposed to simulators).
        skip_signing: Whether this rule skips the signing step.
        skip_simulator_signing_allowed: Whether this rule is allowed to skip signing when building
            for the simulator.
        stub_binary_path: Xcode SDK root relative path to the stub binary to copy as this rule's
            binary artifact.

    Returns:
        A struct with fields that describe the configuration for a specific bundling rule.
    """

    if not bundle_locations:
        bundle_locations = _describe_bundle_locations()

    return struct(
        additional_infoplist_values = additional_infoplist_values,
        allowed_device_families = allowed_device_families,
        app_icon_extension = app_icon_extension,
        app_icon_parent_extension = app_icon_parent_extension,
        archive_extension = archive_extension,
        bundle_extension = bundle_extension,
        bundle_locations = bundle_locations,
        deps_cfg = deps_cfg,
        has_infoplist = has_infoplist,
        has_launch_images = has_launch_images,
        has_settings_bundle = has_settings_bundle,
        is_executable = is_executable,
        mandatory_families = mandatory_families,
        product_type = product_type,
        provisioning_profile_extension = provisioning_profile_extension,
        requires_bundle_id = requires_bundle_id,
        requires_deps = requires_deps,
        requires_pkginfo = requires_pkginfo,
        requires_provisioning_profile = requires_provisioning_profile,
        requires_signing_for_device = requires_signing_for_device,
        skip_simulator_signing_allowed = skip_simulator_signing_allowed,
        skip_signing = skip_signing,
        stub_binary_path = stub_binary_path,
    )

_DEFAULT_MACOS_BUNDLE_LOCATIONS = _describe_bundle_locations(
    bundle_relative_contents = "Contents",
    contents_relative_binary = "MacOS",
    contents_relative_resources = "Resources",
)

# Descriptors for all possible platform/product type combinations.
_RULE_TYPE_DESCRIPTORS = {
    "ios": {
        # ios_application
        apple_product_type.application: _describe_rule_type(
            allowed_device_families = ["iphone", "ipad"],
            app_icon_parent_extension = ".xcassets",
            app_icon_extension = ".appiconset",
            archive_extension = ".ipa",
            bundle_extension = ".app",
            bundle_locations = _describe_bundle_locations(archive_relative = "Payload"),
            has_launch_images = True,
            has_settings_bundle = True,
            is_executable = True,
            mandatory_families = True,
            product_type = apple_product_type.application,
            requires_pkginfo = True,
        ),
        # ios_extension
        apple_product_type.app_extension: _describe_rule_type(
            allowed_device_families = ["iphone", "ipad"],
            bundle_extension = ".appex",
            mandatory_families = True,
            product_type = apple_product_type.app_extension,
        ),
        # ios_framework
        apple_product_type.framework: _describe_rule_type(
            allowed_device_families = ["iphone", "ipad"],
            bundle_extension = ".framework",
            mandatory_families = True,
            product_type = apple_product_type.framework,
            skip_signing = True,
        ),
        # ios_imessage_application
        apple_product_type.messages_application: _describe_rule_type(
            additional_infoplist_values = {"LSApplicationLaunchProhibited": True},
            allowed_device_families = ["iphone", "ipad"],
            app_icon_parent_extension = ".xcassets",
            app_icon_extension = ".appiconset",
            archive_extension = ".ipa",
            bundle_extension = ".app",
            bundle_locations = _describe_bundle_locations(archive_relative = "Payload"),
            mandatory_families = True,
            product_type = apple_product_type.messages_application,
            requires_deps = False,
            stub_binary_path = "../../../Library/Application Support/" +
                               "MessagesApplicationStub/MessagesApplicationStub",
        ),
        # ios_imessage_extension
        apple_product_type.messages_extension: _describe_rule_type(
            allowed_device_families = ["iphone", "ipad"],
            app_icon_parent_extension = ".xcassets",
            app_icon_extension = ".stickersiconset",
            bundle_extension = ".appex",
            deps_cfg = apple_common.multi_arch_split,
            mandatory_families = True,
            product_type = apple_product_type.messages_extension,
        ),
        # ios_stickerpack_extension
        apple_product_type.messages_sticker_pack_extension: _describe_rule_type(
            additional_infoplist_values = {"LSApplicationIsStickerProvider": "YES"},
            allowed_device_families = ["iphone", "ipad"],
            app_icon_parent_extension = ".xcstickers",
            app_icon_extension = ".stickersiconset",
            bundle_extension = ".appex",
            mandatory_families = True,
            product_type = apple_product_type.messages_sticker_pack_extension,
            requires_deps = False,
            stub_binary_path = "../../../Library/Application Support/" +
                               "MessagesApplicationExtensionStub/MessagesApplicationExtensionStub",
        ),
        # ios_static_framework
        apple_product_type.static_framework: _describe_rule_type(
            allowed_device_families = ["iphone", "ipad"],
            bundle_extension = ".framework",
            has_infoplist = False,
            product_type = apple_product_type.static_framework,
            requires_bundle_id = False,
            requires_provisioning_profile = False,
            skip_signing = True,
        ),
        # ios_ui_test
        apple_product_type.ui_test_bundle: _describe_rule_type(
            allowed_device_families = ["iphone", "ipad"],
            bundle_extension = ".xctest",
            product_type = apple_product_type.ui_test_bundle,
            requires_signing_for_device = False,
        ),
        # ios_unit_test
        apple_product_type.unit_test_bundle: _describe_rule_type(
            allowed_device_families = ["iphone", "ipad"],
            bundle_extension = ".xctest",
            product_type = apple_product_type.unit_test_bundle,
            requires_signing_for_device = False,
        ),
    },
    "macos": {
        # macos_application
        apple_product_type.application: _describe_rule_type(
            allowed_device_families = ["mac"],
            app_icon_parent_extension = ".xcassets",
            app_icon_extension = ".appiconset",
            bundle_extension = ".app",
            bundle_locations = _DEFAULT_MACOS_BUNDLE_LOCATIONS,
            product_type = apple_product_type.application,
            provisioning_profile_extension = ".provisioningprofile",
            requires_pkginfo = True,
            requires_signing_for_device = False,
        ),
        # macos_command_line_application
        apple_product_type.tool: _describe_rule_type(
            bundle_extension = "",
            product_type = apple_product_type.tool,
        ),
        # macos_dylib
        apple_product_type.dylib: _describe_rule_type(
            bundle_extension = "",
            product_type = apple_product_type.dylib,
        ),
        # macos_extension
        apple_product_type.app_extension: _describe_rule_type(
            allowed_device_families = ["mac"],
            bundle_extension = ".appex",
            bundle_locations = _DEFAULT_MACOS_BUNDLE_LOCATIONS,
            product_type = apple_product_type.app_extension,
            provisioning_profile_extension = ".provisioningprofile",
            requires_signing_for_device = False,
        ),
        # macos_bundle
        apple_product_type.bundle: _describe_rule_type(
            allowed_device_families = ["mac"],
            bundle_extension = ".bundle",
            bundle_locations = _DEFAULT_MACOS_BUNDLE_LOCATIONS,
            product_type = apple_product_type.bundle,
            provisioning_profile_extension = ".provisioningprofile",
            requires_signing_for_device = False,
        ),
        # macos_kernel_extension
        apple_product_type.kernel_extension: _describe_rule_type(
            allowed_device_families = ["mac"],
            bundle_extension = ".kext",
            bundle_locations = _DEFAULT_MACOS_BUNDLE_LOCATIONS,
            product_type = apple_product_type.kernel_extension,
            provisioning_profile_extension = ".provisioningprofile",
            requires_signing_for_device = False,
        ),
        # macos_spotlight_importer
        apple_product_type.spotlight_importer: _describe_rule_type(
            allowed_device_families = ["mac"],
            bundle_extension = ".mdimporter",
            bundle_locations = _DEFAULT_MACOS_BUNDLE_LOCATIONS,
            product_type = apple_product_type.spotlight_importer,
            provisioning_profile_extension = ".provisioningprofile",
            requires_signing_for_device = False,
        ),
        # macos_xpc_service
        apple_product_type.xpc_service: _describe_rule_type(
            allowed_device_families = ["mac"],
            bundle_extension = ".xpc",
            bundle_locations = _DEFAULT_MACOS_BUNDLE_LOCATIONS,
            product_type = apple_product_type.xpc_service,
            provisioning_profile_extension = ".provisioningprofile",
            requires_signing_for_device = False,
        ),
        # macos_ui_test
        apple_product_type.ui_test_bundle: _describe_rule_type(
            allowed_device_families = ["mac"],
            bundle_extension = ".xctest",
            bundle_locations = _DEFAULT_MACOS_BUNDLE_LOCATIONS,
            product_type = apple_product_type.ui_test_bundle,
            requires_signing_for_device = False,
        ),
        # macos_unit_test
        apple_product_type.unit_test_bundle: _describe_rule_type(
            allowed_device_families = ["mac"],
            bundle_extension = ".xctest",
            bundle_locations = _DEFAULT_MACOS_BUNDLE_LOCATIONS,
            product_type = apple_product_type.unit_test_bundle,
            requires_signing_for_device = False,
        ),
    },
    "tvos": {
        # tvos_application
        apple_product_type.application: _describe_rule_type(
            allowed_device_families = ["tv"],
            app_icon_parent_extension = ".xcassets",
            app_icon_extension = ".appiconset",
            archive_extension = ".ipa",
            bundle_extension = ".app",
            bundle_locations = _describe_bundle_locations(archive_relative = "Payload"),
            deps_cfg = apple_common.multi_arch_split,
            has_launch_images = True,
            has_settings_bundle = True,
            is_executable = True,
            product_type = apple_product_type.application,
            requires_pkginfo = True,
        ),
        # tvos_extension
        apple_product_type.app_extension: _describe_rule_type(
            allowed_device_families = ["tv"],
            bundle_extension = ".appex",
            deps_cfg = apple_common.multi_arch_split,
            product_type = apple_product_type.app_extension,
        ),
    },
    "watchos": {
        # watchos_application
        apple_product_type.watch2_application: _describe_rule_type(
            allowed_device_families = ["watch"],
            app_icon_parent_extension = ".xcassets",
            app_icon_extension = ".appiconset",
            bundle_extension = ".app",
            product_type = apple_product_type.watch2_application,
            requires_deps = False,
            requires_pkginfo = True,
            stub_binary_path = "Library/Application Support/WatchKit/WK",
        ),
        # watchos_extension
        apple_product_type.watch2_extension: _describe_rule_type(
            allowed_device_families = ["watch"],
            bundle_extension = ".appex",
            deps_cfg = apple_common.multi_arch_split,
            product_type = apple_product_type.watch2_extension,
        ),
    },
}

def _rule_descriptor_no_ctx(platform_type, product_type):
    """Returns the rule descriptor for the given platform and product types.

    This method fails if the platform and product combination is invalid.

    Args:
        platform_type: Platform of the rule (e.g. "macos").
        product_type: Product type of the rule (e.g. apple_product_type.application).

    Returns:
        The rule descriptor that describes the rule for the given platform and product types.
    """
    rule_descriptor = _RULE_TYPE_DESCRIPTORS[platform_type].get(product_type)
    if not rule_descriptor:
        fail(
            "Platform type '{platform_type}' does not support product type '{product_type}'".format(
                platform_type = platform_type,
                product_type = product_type,
            ),
        )
    return rule_descriptor

def _rule_descriptor(ctx):
    """Returns the rule descriptor for platform and product types derived from the rule context."""
    platform_type = platform_support.platform_type(ctx)
    product_type = product_support.product_type(ctx)
    return _rule_descriptor_no_ctx(str(platform_type), product_type)

rule_support = struct(
    rule_descriptor = _rule_descriptor,
    rule_descriptor_no_ctx = _rule_descriptor_no_ctx,
)
