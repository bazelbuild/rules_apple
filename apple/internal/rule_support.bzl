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

"""Support for describing rule implementations.

The main purpose of this file is to have a central location that fully describes how a rule
implementation should behave, based only on the platform and product type. In previous
implementations of the rules, these information would be encoded in multiple private attributes.
With this approach, both rule definition and implementation infrastructure can access the same
parameters that affect both the attributes and the implementation logic of the rules.
"""

load(
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
)
load(
    "@build_bazel_rules_apple//apple/internal:transition_support.bzl",
    "transition_support",
)

def _describe_bundle_locations(
        archive_relative = "",
        bundle_relative_contents = "",
        contents_relative_binary = "",
        contents_relative_frameworks = "Frameworks",
        contents_relative_plugins = "PlugIns",
        contents_relative_resources = "",
        contents_relative_watch = "Watch",
        contents_relative_xpc_service = "XPCServices"):
    """Creates a descriptor of locations for different types of artifacts within an Apple bundle."""
    return struct(
        archive_relative = archive_relative,
        bundle_relative_contents = bundle_relative_contents,
        contents_relative_binary = contents_relative_binary,
        contents_relative_frameworks = contents_relative_frameworks,
        contents_relative_plugins = contents_relative_plugins,
        contents_relative_resources = contents_relative_resources,
        contents_relative_watch = contents_relative_watch,
        contents_relative_xpc_service = contents_relative_xpc_service,
    )

def _describe_rule_type(
        additional_infoplist_values = None,
        allowed_device_families = None,
        allows_locale_trimming = False,
        app_icon_extension = None,
        app_icon_parent_extension = None,
        archive_extension = ".zip",
        binary_infoplist = True,
        binary_type = "executable",
        bundle_extension = None,
        bundle_locations = None,
        default_infoplist = None,
        default_test_runner = None,
        deps_cfg = None,
        extra_linkopts = [],
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
        rpaths = [],
        rule_transition = None,
        skip_signing = False,
        skip_simulator_signing_allowed = True,
        stub_binary_path = None):
    """Creates a rule descriptor struct containing all the platform and product specific configs.

    Args:
        additional_infoplist_values: Dictionary of additional values to set into the rule's
            Info.plist.
        allowed_device_families: If given, the list of device families that this rule supports.
        allows_locale_trimming: Whether the rule supports trimming `.lproj` localizations.
        app_icon_extension: For rules that require icons, the extension of the directory that should
            hold the icons (e.g. .appiconset).
        app_icon_parent_extension: For rules that require icons, the extension of the asset catalog
            that should hold the icon sets (e.g. .xcassets or .xcstickers).
        archive_extension: Extension for the archive output of the rule.
        binary_infoplist: Whether the Info.plist output should be in binary form.
        binary_type: Binary type to use for the binary_type attribute in the bundling rules. This
            attribute is read by apple_common.link_multi_arch_binary, so rules that use apple_binary
            underneath are not affected.
        bundle_extension: Extension for the Apple bundle inside the archive.
        bundle_locations: Struct with expected bundle locations for different types of artifacts.
        default_infoplist: Default Info.plist to set in the infoplists attribute. Only used for
            tests.
        default_test_runner: Default test runner to set in the runner attribute. Only used for
            tests.
        deps_cfg: The configuration for the deps attribute. This should be None for rules that use
            the apple_binary intermediate target, and apple_common.multi_arch_split for the rules
            that use the Starlark linking API.
        extra_linkopts: Extra options to pass to the linker.
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
        rpaths: List of rpaths to add to the linker.
        rule_transition: Starlark transition to apply to the rule.
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
        allows_locale_trimming = allows_locale_trimming,
        app_icon_extension = app_icon_extension,
        app_icon_parent_extension = app_icon_parent_extension,
        archive_extension = archive_extension,
        binary_infoplist = binary_infoplist,
        binary_type = binary_type,
        bundle_extension = bundle_extension,
        bundle_locations = bundle_locations,
        default_infoplist = default_infoplist,
        default_test_runner = default_test_runner,
        deps_cfg = deps_cfg,
        extra_linkopts = extra_linkopts,
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
        rpaths = rpaths,
        rule_transition = rule_transition,
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
# TODO(b/62481675): Migrate extra_linkopts to crosstool features instead.
_RULE_TYPE_DESCRIPTORS = {
    "ios": {
        # ios_application
        apple_product_type.application: _describe_rule_type(
            allowed_device_families = ["iphone", "ipad"],
            allows_locale_trimming = True,
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
            rpaths = [
                # Application binaries live in Application.app/Application
                # Frameworks are packaged in Application.app/Frameworks
                "@executable_path/Frameworks",
            ],
        ),
        # ios_extension
        apple_product_type.app_extension: _describe_rule_type(
            allowed_device_families = ["iphone", "ipad"],
            allows_locale_trimming = True,
            app_icon_parent_extension = ".xcassets",
            app_icon_extension = ".appiconset",
            bundle_extension = ".appex",
            extra_linkopts = [
                # Migrate to -fapplication-extension, like the other rules, once ios_extension is
                # migrated to a proper rule and not a macro with an apple_binary.
                "-application_extension",
                "-e",
                "_NSExtensionMain",
            ],
            mandatory_families = True,
            product_type = apple_product_type.app_extension,
            rpaths = [
                # Extension binaries live in Application.app/PlugIns/Extension.appex/Extension
                # Frameworks are packaged in Application.app/Frameworks
                "@executable_path/../../Frameworks",
            ],
        ),
        # ios_framework
        apple_product_type.framework: _describe_rule_type(
            allowed_device_families = ["iphone", "ipad"],
            bundle_extension = ".framework",
            mandatory_families = True,
            product_type = apple_product_type.framework,
            rpaths = [
                # Framework binaries live in
                # Application.app/Frameworks/Framework.framework/Framework
                # Frameworks are packaged in Application.app/Frameworks
                "@executable_path/Frameworks",
            ],
            skip_signing = True,
        ),
        # ios_imessage_application
        apple_product_type.messages_application: _describe_rule_type(
            additional_infoplist_values = {"LSApplicationLaunchProhibited": True},
            allows_locale_trimming = True,
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
            allows_locale_trimming = True,
            app_icon_parent_extension = ".xcassets",
            app_icon_extension = ".stickersiconset",
            bundle_extension = ".appex",
            deps_cfg = apple_common.multi_arch_split,
            extra_linkopts = [
                "-fapplication-extension",
                "-e",
                "_NSExtensionMain",
            ],
            mandatory_families = True,
            product_type = apple_product_type.messages_extension,
            rpaths = [
                # Extension binaries live in Application.app/PlugIns/Extension.appex/Extension
                # Frameworks are packaged in Application.app/Frameworks
                "@executable_path/../../Frameworks",
            ],
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
            binary_type = "loadable_bundle",
            bundle_extension = ".xctest",
            default_infoplist = "@build_bazel_rules_apple//apple/testing:DefaultTestBundlePlist",
            default_test_runner = "@build_bazel_rules_apple//apple/testing/default_runner:ios_default_runner",
            deps_cfg = apple_common.multi_arch_split,
            extra_linkopts = [
                "-framework",
                "XCTest",
            ],
            product_type = apple_product_type.ui_test_bundle,
            requires_signing_for_device = False,
            rpaths = [
                # Test binaries live in Application.app/PlugIns/Test.xctest/Test
                # Frameworks are packaged in Application.app/Frameworks and in
                # Application.app/PlugIns/Test.xctest/Frameworks
                "@executable_path/Frameworks",
                "@loader_path/Frameworks",
            ],
            skip_simulator_signing_allowed = False,
        ),
        # ios_unit_test
        apple_product_type.unit_test_bundle: _describe_rule_type(
            allowed_device_families = ["iphone", "ipad"],
            binary_type = "loadable_bundle",
            bundle_extension = ".xctest",
            default_infoplist = "@build_bazel_rules_apple//apple/testing:DefaultTestBundlePlist",
            default_test_runner = "@build_bazel_rules_apple//apple/testing/default_runner:ios_default_runner",
            deps_cfg = apple_common.multi_arch_split,
            extra_linkopts = [
                "-framework",
                "XCTest",
            ],
            product_type = apple_product_type.unit_test_bundle,
            requires_signing_for_device = False,
            rpaths = [
                # Test binaries live in Application.app/PlugIns/Test.xctest/Test
                # Frameworks are packaged in Application.app/Frameworks and in
                # Application.app/PlugIns/Test.xctest/Frameworks
                "@executable_path/Frameworks",
                "@loader_path/Frameworks",
            ],
            skip_simulator_signing_allowed = False,
        ),
    },
    "macos": {
        # macos_application
        apple_product_type.application: _describe_rule_type(
            allowed_device_families = ["mac"],
            allows_locale_trimming = True,
            app_icon_parent_extension = ".xcassets",
            app_icon_extension = ".appiconset",
            bundle_extension = ".app",
            bundle_locations = _DEFAULT_MACOS_BUNDLE_LOCATIONS,
            deps_cfg = apple_common.multi_arch_split,
            is_executable = True,
            product_type = apple_product_type.application,
            provisioning_profile_extension = ".provisionprofile",
            requires_pkginfo = True,
            requires_signing_for_device = False,
            rpaths = [
                # Application binaries live in Application.app/Contents/MacOS/Application
                # Frameworks are packaged in Application.app/Contents/Frameworks
                "@executable_path/../Frameworks",
            ],
            rule_transition = transition_support.apple_rule_transition,
        ),
        # macos_command_line_application
        apple_product_type.tool: _describe_rule_type(
            allowed_device_families = ["mac"],
            bundle_extension = "",
            deps_cfg = apple_common.multi_arch_split,
            is_executable = True,
            product_type = apple_product_type.tool,
            provisioning_profile_extension = ".provisionprofile",
            requires_provisioning_profile = True,
            requires_signing_for_device = False,
            rule_transition = transition_support.apple_rule_transition,
        ),
        # macos_dylib
        apple_product_type.dylib: _describe_rule_type(
            allowed_device_families = ["mac"],
            binary_type = "dylib",
            bundle_extension = "",
            deps_cfg = apple_common.multi_arch_split,
            product_type = apple_product_type.dylib,
            requires_signing_for_device = False,
            rule_transition = transition_support.apple_rule_transition,
        ),
        # macos_extension
        apple_product_type.app_extension: _describe_rule_type(
            allowed_device_families = ["mac"],
            allows_locale_trimming = True,
            app_icon_parent_extension = ".xcassets",
            app_icon_extension = ".appiconset",
            bundle_extension = ".appex",
            bundle_locations = _DEFAULT_MACOS_BUNDLE_LOCATIONS,
            deps_cfg = apple_common.multi_arch_split,
            extra_linkopts = [
                "-e",
                "_NSExtensionMain",
            ],
            product_type = apple_product_type.app_extension,
            provisioning_profile_extension = ".provisionprofile",
            requires_signing_for_device = False,
            rpaths = [
                # Extension binaries live in
                # Application.app/Contents/PlugIns/Extension.appex/Contents/MacOS/Extension
                # Frameworks are packaged in Application.app/Contents/Frameworks
                "@executable_path/../../../../Frameworks",
            ],
            rule_transition = transition_support.apple_rule_transition,
        ),
        # macos_quick_look_plugin
        apple_product_type.quicklook_plugin: _describe_rule_type(
            allowed_device_families = ["mac"],
            binary_type = "dylib",
            bundle_extension = ".qlgenerator",
            bundle_locations = _DEFAULT_MACOS_BUNDLE_LOCATIONS,
            deps_cfg = apple_common.multi_arch_split,
            product_type = apple_product_type.quicklook_plugin,
            provisioning_profile_extension = ".provisionprofile",
            requires_deps = True,
            requires_signing_for_device = False,
            rule_transition = transition_support.apple_rule_transition,
        ),
        # macos_bundle
        apple_product_type.bundle: _describe_rule_type(
            allowed_device_families = ["mac"],
            app_icon_parent_extension = ".xcassets",
            app_icon_extension = ".appiconset",
            binary_type = "loadable_bundle",
            bundle_extension = ".bundle",
            bundle_locations = _DEFAULT_MACOS_BUNDLE_LOCATIONS,
            deps_cfg = apple_common.multi_arch_split,
            product_type = apple_product_type.bundle,
            provisioning_profile_extension = ".provisionprofile",
            requires_signing_for_device = False,
            rpaths = [
                # Bundle binaries are loaded from the executable location and application binaries
                # live in Application.app/Contents/MacOS/Application
                # Frameworks are packaged in Application.app/Contents/Frameworks
                "@executable_path/../Frameworks",
            ],
            rule_transition = transition_support.apple_rule_transition,
        ),
        # macos_kernel_extension
        apple_product_type.kernel_extension: _describe_rule_type(
            allowed_device_families = ["mac"],
            binary_infoplist = False,
            bundle_extension = ".kext",
            bundle_locations = _DEFAULT_MACOS_BUNDLE_LOCATIONS,
            deps_cfg = apple_common.multi_arch_split,
            # This was added for b/122473338, and should be removed eventually once symbol
            # stripping is better-handled. It's redundant with an option added in the CROSSTOOL
            # for the "kernel_extension" feature, but for now it's necessary to detect kext
            # linking so CompilationSupport.java can apply the correct type of symbol stripping.
            extra_linkopts = [
                "-Xlinker",
                "-kext",
            ],
            product_type = apple_product_type.kernel_extension,
            provisioning_profile_extension = ".provisionprofile",
            requires_deps = True,
            requires_signing_for_device = False,
            rule_transition = transition_support.apple_rule_transition,
        ),
        # macos_spotlight_importer
        apple_product_type.spotlight_importer: _describe_rule_type(
            allowed_device_families = ["mac"],
            bundle_extension = ".mdimporter",
            bundle_locations = _DEFAULT_MACOS_BUNDLE_LOCATIONS,
            deps_cfg = apple_common.multi_arch_split,
            product_type = apple_product_type.spotlight_importer,
            provisioning_profile_extension = ".provisionprofile",
            requires_deps = True,
            requires_signing_for_device = False,
            rule_transition = transition_support.apple_rule_transition,
        ),
        # macos_xpc_service
        apple_product_type.xpc_service: _describe_rule_type(
            allowed_device_families = ["mac"],
            bundle_extension = ".xpc",
            bundle_locations = _DEFAULT_MACOS_BUNDLE_LOCATIONS,
            deps_cfg = apple_common.multi_arch_split,
            product_type = apple_product_type.xpc_service,
            provisioning_profile_extension = ".provisionprofile",
            requires_deps = True,
            requires_signing_for_device = False,
            requires_pkginfo = True,
            rpaths = [
                # XPC Application binaries live in
                # Application.app/Contents/XCPServices/XPCService.xpc/Contents/MacOS/XPCService
                # Frameworks are packaged in Application.app/Contents/Frameworks
                "@executable_path/../../../../Frameworks",
            ],
            rule_transition = transition_support.apple_rule_transition,
        ),
        # macos_ui_test
        apple_product_type.ui_test_bundle: _describe_rule_type(
            allowed_device_families = ["mac"],
            binary_type = "loadable_bundle",
            bundle_extension = ".xctest",
            bundle_locations = _DEFAULT_MACOS_BUNDLE_LOCATIONS,
            default_infoplist = "@build_bazel_rules_apple//apple/testing:DefaultTestBundlePlist",
            default_test_runner = "@build_bazel_rules_apple//apple/testing/default_runner:macos_default_runner",
            deps_cfg = apple_common.multi_arch_split,
            extra_linkopts = [
                "-framework",
                "XCTest",
            ],
            product_type = apple_product_type.ui_test_bundle,
            requires_signing_for_device = False,
            rpaths = [
                # Test binaries live in
                # Application.app/Contents/PlugIns/Test.xctest/Contents/MacOS/Test
                # Frameworks are packaged in Application.app/Contents/Frameworks and in
                # Application.app/Contents/PlugIns/Test.xctest/Contents/Frameworks
                "@executable_path/../Frameworks",
                "@loader_path/../Frameworks",
            ],
            rule_transition = transition_support.apple_rule_transition,
        ),
        # macos_unit_test
        apple_product_type.unit_test_bundle: _describe_rule_type(
            allowed_device_families = ["mac"],
            binary_type = "loadable_bundle",
            bundle_extension = ".xctest",
            bundle_locations = _DEFAULT_MACOS_BUNDLE_LOCATIONS,
            default_infoplist = "@build_bazel_rules_apple//apple/testing:DefaultTestBundlePlist",
            default_test_runner = "@build_bazel_rules_apple//apple/testing/default_runner:macos_default_runner",
            deps_cfg = apple_common.multi_arch_split,
            extra_linkopts = [
                "-framework",
                "XCTest",
            ],
            product_type = apple_product_type.unit_test_bundle,
            requires_signing_for_device = False,
            rpaths = [
                # Test binaries live in
                # Application.app/Contents/PlugIns/Test.xctest/Contents/MacOS/Test
                # Frameworks are packaged in Application.app/Contents/Frameworks and in
                # Application.app/Contents/PlugIns/Test.xctest/Contents/Frameworks
                "@executable_path/../Frameworks",
                "@loader_path/../Frameworks",
            ],
            rule_transition = transition_support.apple_rule_transition,
        ),
    },
    "tvos": {
        # tvos_application
        apple_product_type.application: _describe_rule_type(
            allowed_device_families = ["tv"],
            allows_locale_trimming = True,
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
            rpaths = [
                # Application binaries live in Application.app/Application
                # Frameworks are packaged in Application.app/Frameworks
                "@executable_path/Frameworks",
            ],
            rule_transition = transition_support.apple_rule_transition,
        ),
        # tvos_extension
        apple_product_type.app_extension: _describe_rule_type(
            allowed_device_families = ["tv"],
            allows_locale_trimming = True,
            bundle_extension = ".appex",
            deps_cfg = apple_common.multi_arch_split,
            extra_linkopts = [
                "-e",
                "_TVExtensionMain",
                "-fapplication-extension",
                "-framework",
                "TVServices",
            ],
            product_type = apple_product_type.app_extension,
            rpaths = [
                # Extension binaries live in Application.app/PlugIns/Extension.appex/Extension
                # Frameworks are packaged in Application.app/Frameworks
                "@executable_path/../../Frameworks",
            ],
            rule_transition = transition_support.apple_rule_transition,
        ),
        # tvos_framework
        apple_product_type.framework: _describe_rule_type(
            allowed_device_families = ["tv"],
            bundle_extension = ".framework",
            binary_type = "dylib",
            deps_cfg = apple_common.multi_arch_split,
            product_type = apple_product_type.framework,
            rpaths = [
                # Framework binaries live in
                # Application.app/Frameworks/Framework.framework/Framework
                # Frameworks are packaged in Application.app/Frameworks
                "@executable_path/Frameworks",
            ],
            skip_signing = True,
            rule_transition = transition_support.apple_rule_transition,
        ),
        # tvos_static_framework
        apple_product_type.static_framework: _describe_rule_type(
            allowed_device_families = ["tv"],
            bundle_extension = ".framework",
            has_infoplist = False,
            product_type = apple_product_type.static_framework,
            requires_bundle_id = False,
            requires_provisioning_profile = False,
            skip_signing = True,
            rule_transition = transition_support.apple_rule_transition,
        ),
        # tvos_ui_test
        apple_product_type.ui_test_bundle: _describe_rule_type(
            allowed_device_families = ["tv"],
            binary_type = "loadable_bundle",
            bundle_extension = ".xctest",
            default_infoplist = "@build_bazel_rules_apple//apple/testing:DefaultTestBundlePlist",
            default_test_runner = "@build_bazel_rules_apple//apple/testing/default_runner:tvos_default_runner",
            deps_cfg = apple_common.multi_arch_split,
            extra_linkopts = [
                "-framework",
                "XCTest",
            ],
            product_type = apple_product_type.ui_test_bundle,
            requires_signing_for_device = False,
            rpaths = [
                # Test binaries live in Application.app/PlugIns/Test.xctest/Test
                # Frameworks are packaged in Application.app/Frameworks and in
                # Application.app/PlugIns/Test.xctest/Frameworks
                "@executable_path/Frameworks",
                "@loader_path/Frameworks",
            ],
            skip_simulator_signing_allowed = False,
            rule_transition = transition_support.apple_rule_transition,
        ),
        # tvos_unit_test
        apple_product_type.unit_test_bundle: _describe_rule_type(
            allowed_device_families = ["tv"],
            binary_type = "loadable_bundle",
            bundle_extension = ".xctest",
            default_infoplist = "@build_bazel_rules_apple//apple/testing:DefaultTestBundlePlist",
            default_test_runner = "@build_bazel_rules_apple//apple/testing/default_runner:tvos_default_runner",
            deps_cfg = apple_common.multi_arch_split,
            extra_linkopts = [
                "-framework",
                "XCTest",
            ],
            product_type = apple_product_type.unit_test_bundle,
            requires_signing_for_device = False,
            rpaths = [
                # Test binaries live in Application.app/PlugIns/Test.xctest/Test
                # Frameworks are packaged in Application.app/Frameworks and in
                # Application.app/PlugIns/Test.xctest/Frameworks
                "@executable_path/Frameworks",
                "@loader_path/Frameworks",
            ],
            skip_simulator_signing_allowed = False,
            rule_transition = transition_support.apple_rule_transition,
        ),
    },
    "watchos": {
        # watchos_application
        apple_product_type.watch2_application: _describe_rule_type(
            allowed_device_families = ["watch"],
            allows_locale_trimming = True,
            app_icon_parent_extension = ".xcassets",
            app_icon_extension = ".appiconset",
            bundle_extension = ".app",
            product_type = apple_product_type.watch2_application,
            requires_deps = False,
            requires_pkginfo = True,
            rule_transition = transition_support.apple_rule_transition,
            stub_binary_path = "Library/Application Support/WatchKit/WK",
        ),
        # watchos_extension
        apple_product_type.watch2_extension: _describe_rule_type(
            allowed_device_families = ["watch"],
            allows_locale_trimming = True,
            bundle_extension = ".appex",
            deps_cfg = apple_common.multi_arch_split,
            extra_linkopts = [
                "-fapplication-extension",
            ],
            product_type = apple_product_type.watch2_extension,
            rpaths = [
                # Extension binaries live in Application.app/PlugIns/Extension.appex/Extension
                # Frameworks are packaged in Application.app/Frameworks
                "@executable_path/../../Frameworks",
            ],
            rule_transition = transition_support.apple_rule_transition,
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

    # Check the attribute explicitly instead of using platform_support, since that creates a
    # cyclical dependency on this file.
    platform_type = getattr(apple_common.platform_type, ctx.attr.platform_type)
    product_type = ctx.attr._product_type
    return _rule_descriptor_no_ctx(str(platform_type), product_type)

rule_support = struct(
    rule_descriptor = _rule_descriptor,
    rule_descriptor_no_ctx = _rule_descriptor_no_ctx,
)
