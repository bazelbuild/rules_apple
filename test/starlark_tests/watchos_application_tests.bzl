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

"""watchos_application Starlark tests."""

load(
    "//test/starlark_tests/rules:analysis_failure_message_test.bzl",
    "analysis_failure_message_test",
)
load(
    "//test/starlark_tests/rules:analysis_target_actions_test.bzl",
    "analysis_target_actions_test",
    "make_analysis_target_actions_test",
)
load(
    "//test/starlark_tests/rules:analysis_target_outputs_test.bzl",
    "analysis_target_tree_artifacts_outputs_test",
)
load(
    "//test/starlark_tests/rules:apple_verification_test.bzl",
    "apple_verification_test",
)
load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "archive_contents_test",
    "binary_contents_test",
)
load(
    "//test/starlark_tests/rules:infoplist_contents_test.bzl",
    "infoplist_contents_test",
)
load(
    "//test/starlark_tests/rules:output_group_zip_contents_test.bzl",
    "output_group_zip_contents_test",
)
load(
    "//test/starlark_tests/rules:plisttool_error_test.bzl",
    "plisttool_error_test",
)
load(
    "//test/starlark_tests/rules:provisioning_profile_tool_error_test.bzl",
    "provisioning_profile_tool_error_test",
)
load(
    ":common.bzl",
    "common",
)

_WATCH_APP_PLIST_SUBSTITUTIONS = {
    "BUNDLE_NAME": "app.app",
    "DEVELOPMENT_LANGUAGE": "en",
    "EXECUTABLE_NAME": "app",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.google.example",
    "PRODUCT_BUNDLE_PACKAGE_TYPE": "APPL",
    "PRODUCT_NAME": "app",
    "TARGET_NAME": "app",
}

_COMPANION_APP_PLIST_SUBSTITUTIONS = {
    "BUNDLE_NAME": "app_companion.app",
    "DEVELOPMENT_LANGUAGE": "en",
    "EXECUTABLE_NAME": "app_companion",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.google",
    "PRODUCT_BUNDLE_PACKAGE_TYPE": "APPL",
    "PRODUCT_NAME": "app_companion",
    "TARGET_NAME": "app_companion",
}

_OTHER_COMPANION_APP_PLIST_SUBSTITUTIONS = dict(
    _COMPANION_APP_PLIST_SUBSTITUTIONS,
    PRODUCT_BUNDLE_IDENTIFIER = "com.other",
)

_analysis_watchos_strip_enabled_opt_test = make_analysis_target_actions_test(
    config_settings = {
        "//command_line_option:compilation_mode": "opt",
        "//command_line_option:watchos_cpus": "x86_64",
        "//command_line_option:objc_enable_binary_stripping": True,
    },
)

_analysis_watchos_strip_disabled_opt_test = make_analysis_target_actions_test(
    config_settings = {
        "//command_line_option:compilation_mode": "opt",
        "//command_line_option:watchos_cpus": "x86_64",
        "//command_line_option:objc_enable_binary_stripping": False,
    },
)

_analysis_watchos_strip_disabled_dbg_test = make_analysis_target_actions_test(
    config_settings = {
        "//command_line_option:compilation_mode": "dbg",
        "//command_line_option:watchos_cpus": "x86_64",
        "//command_line_option:objc_enable_binary_stripping": True,
    },
)

def watchos_application_test_suite(name):
    """Test suite for watchos_application.

    Args:
      name: the base name to be used in things created by this macro
    """
    apple_verification_test(
        name = "{}_codesign_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_no_custom_fmwks_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_with_ext_with_imported_fmwk",
        verifier_script = "verifier_scripts/no_custom_fmwks_verifier.sh",
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app",
        expected_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "app",
            "CFBundleIdentifier": "com.google.example",
            "CFBundleName": "app",
            "CFBundlePackageType": "APPL",
            "CFBundleSupportedPlatforms:0": "WatchSimulator*",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "watchsimulator",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "watchsimulator*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "MinimumOSVersion": common.min_os_watchos.baseline,
            "UIDeviceFamily:0": "4",
            "WKWatchKitApp": "true",
        },
        tags = [name],
    )

    # Test missing the CFBundleVersion fails the build.
    plisttool_error_test(
        name = "{}_watch_app_missing_version_fails_test".format(name),
        target_label = "//test/starlark_tests/targets_under_test/watchos:app_missing_version",
        plists = ["//test/starlark_tests/resources:Info-extension-missing-version.plist"],
        plist_values = {
            "CFBundleIdentifier": "com.google.example",
        },
        expected_error = (
            'Target "//test/starlark_tests/targets_under_test/watchos:app_missing_version" ' +
            "is missing CFBundleVersion."
        ),
        variable_substitutions = _WATCH_APP_PLIST_SUBSTITUTIONS,
        version_keys_required = True,
        tags = [name],
    )

    # Test missing the CFBundleShortVersionString fails the build.
    plisttool_error_test(
        name = "{}_watch_app_missing_short_version_fails_test".format(name),
        target_label = "//test/starlark_tests/targets_under_test/watchos:app_missing_short_version",
        plists = ["//test/starlark_tests/resources:Info-extension-missing-short-version.plist"],
        plist_values = {
            "CFBundleIdentifier": "com.google.example",
        },
        expected_error = (
            'Target "//test/starlark_tests/targets_under_test/watchos:app_missing_short_version" ' +
            "is missing CFBundleShortVersionString."
        ),
        variable_substitutions = _WATCH_APP_PLIST_SUBSTITUTIONS,
        version_keys_required = True,
        tags = [name],
    )

    # Test that a watchOS app with a bundle_id that isn't prefixed by the iOS
    # app fails the build.
    plisttool_error_test(
        name = "{}_watch_app_mismatched_bundle_id_fails_test".format(name),
        target_label = "//test/starlark_tests/targets_under_test/watchos:app_companion_with_mismatched_watch_bundle_id",
        child_bundles = ["//test/starlark_tests/targets_under_test/watchos:app_mismatched_bundle_id"],
        plists = ["//test/starlark_tests/resources:Info.plist"],
        plist_values = {
            "CFBundleIdentifier": "com.google",
        },
        expected_error = (
            "While processing target \"{parent}\"; the CFBundleIdentifier " +
            "of the child target \"{child}\" should have \"com.google.\" " +
            "as its prefix, but found \"com.other.example\"."
        ).format(
            parent = "//test/starlark_tests/targets_under_test/watchos:app_companion_with_mismatched_watch_bundle_id",
            child = "//test/starlark_tests/targets_under_test/watchos:app_mismatched_bundle_id",
        ),
        variable_substitutions = _COMPANION_APP_PLIST_SUBSTITUTIONS,
        version_keys_required = True,
        tags = [name],
    )

    # Test that a watchOS extension with a bundle_id that isn't prefixed by the
    # watchOS app fails the build.
    plisttool_error_test(
        name = "{}_watch_ext_mismatched_bundle_id_fails_test".format(name),
        target_label = "//test/starlark_tests/targets_under_test/watchos:app_with_ext_mismatched_bundle_id",
        child_bundles = ["//test/starlark_tests/targets_under_test/watchos:ext_mismatched_bundle_id"],
        plists = ["//test/starlark_tests/resources:WatchosAppInfo.plist"],
        plist_values = {
            "CFBundleIdentifier": "com.google.example",
        },
        expected_error = (
            "While processing target \"{parent}\"; the CFBundleIdentifier " +
            "of the child target \"{child}\" should have \"com.google.example.\" " +
            "as its prefix, but found \"com.google.other\"."
        ).format(
            parent = "//test/starlark_tests/targets_under_test/watchos:app_with_ext_mismatched_bundle_id",
            child = "//test/starlark_tests/targets_under_test/watchos:ext_mismatched_bundle_id",
        ),
        variable_substitutions = _WATCH_APP_PLIST_SUBSTITUTIONS,
        version_keys_required = True,
        tags = [name],
    )

    # Test that a watchOS app with a different CFBundleShortVersionString than
    # the iOS app fails the build.
    plisttool_error_test(
        name = "{}_watch_app_mismatched_short_version_fails_test".format(name),
        target_label = "//test/starlark_tests/targets_under_test/watchos:app_companion_with_mismatched_watch_short_version",
        child_bundles = ["//test/starlark_tests/targets_under_test/watchos:app_mismatched_short_version"],
        plists = ["//test/starlark_tests/resources:Info.plist"],
        plist_values = {
            "CFBundleIdentifier": "com.google",
        },
        expected_error = (
            "While processing target \"{parent}\"; the CFBundleShortVersionString " +
            "of the child target \"{child}\" should be the same as its parent's " +
            "version string \"1.0\", but found \"1.1\"."
        ).format(
            parent = "//test/starlark_tests/targets_under_test/watchos:app_companion_with_mismatched_watch_short_version",
            child = "//test/starlark_tests/targets_under_test/watchos:app_mismatched_short_version",
        ),
        variable_substitutions = _COMPANION_APP_PLIST_SUBSTITUTIONS,
        version_keys_required = True,
        tags = [name],
    )

    # Test that a watchOS extension with a different
    # CFBundleShortVersionString than the watchOS app fails the build.
    plisttool_error_test(
        name = "{}_watch_ext_mismatched_short_version_fails_test".format(name),
        target_label = "//test/starlark_tests/targets_under_test/watchos:app_with_ext_mismatched_short_version",
        child_bundles = ["//test/starlark_tests/targets_under_test/watchos:ext_mismatched_short_version"],
        plists = ["//test/starlark_tests/resources:WatchosAppInfo.plist"],
        plist_values = {
            "CFBundleIdentifier": "com.google.example",
        },
        expected_error = (
            "While processing target \"{parent}\"; the CFBundleShortVersionString " +
            "of the child target \"{child}\" should be the same as its parent's " +
            "version string \"1.0\", but found \"1.1\"."
        ).format(
            parent = "//test/starlark_tests/targets_under_test/watchos:app_with_ext_mismatched_short_version",
            child = "//test/starlark_tests/targets_under_test/watchos:ext_mismatched_short_version",
        ),
        variable_substitutions = _WATCH_APP_PLIST_SUBSTITUTIONS,
        version_keys_required = True,
        tags = [name],
    )

    # Test that a watchOS app with a different CFBundleVersion than the iOS app
    # fails the build.
    plisttool_error_test(
        name = "{}_watch_app_mismatched_version_fails_test".format(name),
        target_label = "//test/starlark_tests/targets_under_test/watchos:app_companion_with_mismatched_watch_version",
        child_bundles = ["//test/starlark_tests/targets_under_test/watchos:app_mismatched_version"],
        plists = ["//test/starlark_tests/resources:Info.plist"],
        plist_values = {
            "CFBundleIdentifier": "com.google",
        },
        expected_error = (
            "While processing target \"{parent}\"; the CFBundleVersion of the " +
            "child target \"{child}\" should be the same as its parent's " +
            "version string \"1.0\", but found \"1.1\"."
        ).format(
            parent = "//test/starlark_tests/targets_under_test/watchos:app_companion_with_mismatched_watch_version",
            child = "//test/starlark_tests/targets_under_test/watchos:app_mismatched_version",
        ),
        variable_substitutions = _COMPANION_APP_PLIST_SUBSTITUTIONS,
        version_keys_required = True,
        tags = [name],
    )

    # Test that a watchOS extension with a different CFBundleVersion than the
    # watchOS app fails the build.
    plisttool_error_test(
        name = "{}_watch_ext_mismatched_version_fails_test".format(name),
        target_label = "//test/starlark_tests/targets_under_test/watchos:app_with_ext_mismatched_version",
        child_bundles = ["//test/starlark_tests/targets_under_test/watchos:ext_mismatched_version"],
        plists = ["//test/starlark_tests/resources:WatchosAppInfo.plist"],
        plist_values = {
            "CFBundleIdentifier": "com.google.example",
        },
        expected_error = (
            "While processing target \"{parent}\"; the CFBundleVersion of the " +
            "child target \"{child}\" should be the same as its parent's " +
            "version string \"1.0\", but found \"1.1\"."
        ).format(
            parent = "//test/starlark_tests/targets_under_test/watchos:app_with_ext_mismatched_version",
            child = "//test/starlark_tests/targets_under_test/watchos:ext_mismatched_version",
        ),
        variable_substitutions = _WATCH_APP_PLIST_SUBSTITUTIONS,
        version_keys_required = True,
        tags = [name],
    )

    # Test that a watchOS app with the wrong bundle_id for its
    # WKCompanionAppBundleIdentifier fails to build.
    plisttool_error_test(
        name = "{}_watch_app_wrong_wk_companion_identifier_fails_test".format(name),
        target_label = "//test/starlark_tests/targets_under_test/watchos:app_companion_with_wrong_wk_companion_identifier",
        child_bundles = ["//test/starlark_tests/targets_under_test/watchos:app_wrong_wk_companion_identifier"],
        child_plist_required_values = {
            "//test/starlark_tests/targets_under_test/watchos:app_wrong_wk_companion_identifier": [
                "WKCompanionAppBundleIdentifier=com.other",
            ],
        },
        plists = ["//test/starlark_tests/resources:Info.plist"],
        plist_values = {
            "CFBundleIdentifier": "com.other",
        },
        expected_error = (
            "While processing target \"{parent}\"; the Info.plist for child " +
            "target \"{child}\" has the wrong value for " +
            "\"WKCompanionAppBundleIdentifier\"; expected 'com.other', " +
            "but found 'com.google'."
        ).format(
            parent = "//test/starlark_tests/targets_under_test/watchos:app_companion_with_wrong_wk_companion_identifier",
            child = "//test/starlark_tests/targets_under_test/watchos:app_wrong_wk_companion_identifier",
        ),
        variable_substitutions = _OTHER_COMPANION_APP_PLIST_SUBSTITUTIONS,
        version_keys_required = True,
        tags = [name],
    )

    # Test that a watchOS extension with the wrong bundle_id for its
    # WKAppBundleIdentifier fails to build.
    plisttool_error_test(
        name = "{}_watch_ext_wrong_wk_app_identifier_fails_test".format(name),
        target_label = "//test/starlark_tests/targets_under_test/watchos:app_with_ext_wrong_wk_app_identifier",
        child_bundles = ["//test/starlark_tests/targets_under_test/watchos:ext_wrong_wk_app_identifier"],
        child_plist_required_values = {
            "//test/starlark_tests/targets_under_test/watchos:ext_wrong_wk_app_identifier": [
                "NSExtension:NSExtensionAttributes:WKAppBundleIdentifier=com.google.example",
            ],
        },
        plists = ["//test/starlark_tests/resources:WatchosAppInfo.plist"],
        plist_values = {
            "CFBundleIdentifier": "com.google.example",
        },
        expected_error = (
            "While processing target \"{parent}\"; the Info.plist for child " +
            "target \"{child}\" has the wrong value for " +
            "\"NSExtension:NSExtensionAttributes:WKAppBundleIdentifier\"; " +
            "expected 'com.google.example', but found " +
            "'com.bazel.app.example.watchkitapp'."
        ).format(
            parent = "//test/starlark_tests/targets_under_test/watchos:app_with_ext_wrong_wk_app_identifier",
            child = "//test/starlark_tests/targets_under_test/watchos:ext_wrong_wk_app_identifier",
        ),
        variable_substitutions = _WATCH_APP_PLIST_SUBSTITUTIONS,
        version_keys_required = True,
        tags = [name],
    )

    # Tests that failures to extract from a provisioning profile are properly
    # reported from the watchOS application profile. The fact that multiple
    # things are tried is left as an implementation detail and only the final
    # message is looked for.
    provisioning_profile_tool_error_test(
        name = "{}_provisioning_profile_extraction_failure_test".format(name),
        target_label = "//test/starlark_tests/targets_under_test/watchos:app_with_bogus_provisioning_profile",
        provisioning_profile = "//test/starlark_tests/resources:bogus.mobileprovision",
        expected_error = 'While processing target "//test/starlark_tests/targets_under_test/watchos:app_with_bogus_provisioning_profile", failed to extract from the provisioning profile "test/starlark_tests/resources/bogus.mobileprovision".',
        tags = [name, "requires-darwin"],
    )

    # Tests that strip action is registered when building in opt mode with binary stripping enabled.
    _analysis_watchos_strip_enabled_opt_test(
        name = "{}_binary_strip_action_enabled_in_opt_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:single_target_app",
        target_mnemonic = "ObjcBinarySymbolStrip",
        tags = [name],
    )

    # Tests that strip action is not registered when in opt mode but stripping is disabled.
    _analysis_watchos_strip_disabled_opt_test(
        name = "{}_binary_strip_action_disabled_without_flag_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:single_target_app",
        target_mnemonic = "ObjcLink",
        not_expected_mnemonic = ["ObjcBinarySymbolStrip"],
        tags = [name],
    )

    # Tests that strip action is not registered in dbg mode even if stripping is enabled.
    _analysis_watchos_strip_disabled_dbg_test(
        name = "{}_binary_strip_action_disabled_in_dbg_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:single_target_app",
        target_mnemonic = "ObjcLink",
        not_expected_mnemonic = ["ObjcBinarySymbolStrip"],
        tags = [name],
    )

    # Tests xcasset tool is passed the correct arguments.
    analysis_target_actions_test(
        name = "{}_xcasset_actool_argv".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app",
        target_mnemonic = "AssetCatalogCompile",
        expected_argv = [
            "xctoolrunner actool --compile",
            "--minimum-deployment-target " + common.min_os_watchos.baseline,
            "--platform watchsimulator",
        ],
        tags = [name],
    )

    # Tests that the WatchKit stub executable is bundled everywhere it's
    # supposed to be. This must be tested through the companion app since
    # the `WatchKitSupport2` directory is only added at the root of archives
    # for distribution.
    archive_contents_test(
        name = "{}_contains_stub_executable_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ipa_app_companion",
        contains = [
            "$ARCHIVE_ROOT/WatchKitSupport2/WK",
            "$BUNDLE_ROOT/Watch/app.app/_WatchKitStub/WK",
        ],
        tags = [name],
    )

    output_group_zip_contents_test(
        name = "{}_archive_watch_application_dossier_embeds_watch_dossier".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ipa_app_companion",
        output_group_name = "combined_dossier_zip",
        output_group_file_shortpath = "test/starlark_tests/targets_under_test/watchos/ipa_app_companion_dossier_with_bundle.zip",
        contains = [
            "dossier/manifest.json",
        ],
        contains_text = {
            "dossier/manifest.json": [
                "PlugIns/ext.appex",
                "Watch/app.app",
            ],
        },
        tags = [name],
    )

    # Test that the output stub binary is identified as watchOS simulator via the Mach-O load
    # command LC_VERSION_MIN_WATCHOS for the arm64 binary slice when only iOS cpus are defined, and
    # that 32-bit archs are eliminated.
    binary_contents_test(
        name = "{}_simulator_ios_cpus_intel_platform_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ipa_app_companion",
        cpus = {
            "ios_multi_cpus": ["x86_64", "sim_arm64"],
            "watchos_cpus": [""],
        },
        binary_test_file = "$BUNDLE_ROOT/Watch/app.app/_WatchKitStub/WK",
        binary_test_architecture = "x86_64",
        binary_not_contains_architectures = ["i386", "arm64e"],
        macho_load_commands_contain = ["cmd LC_VERSION_MIN_WATCHOS"],
        tags = [name],
    )

    # Test that the output application binary is identified as watchOS simulator via the Mach-O
    # load command LC_BUILD_VERSION for the arm64 binary slice when only iOS cpus are defined, and
    # that 32-bit archs are eliminated.
    binary_contents_test(
        name = "{}_simulator_ios_cpus_arm_platform_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ipa_app_companion",
        cpus = {
            "ios_multi_cpus": ["x86_64", "sim_arm64"],
            "watchos_cpus": [""],
        },
        binary_test_file = "$BUNDLE_ROOT/Watch/app.app/_WatchKitStub/WK",
        binary_test_architecture = "arm64",
        binary_not_contains_architectures = ["i386", "arm64e"],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform WATCHOSSIMULATOR"],
        tags = [name],
    )

    # Test that the output stub binary is identified as watchOS simulator via the Mach-O load
    # command LC_VERSION_MIN_WATCHOS for the arm64 binary slice when only iOS cpus are defined, and
    # that it defaults to arm64_32.
    binary_contents_test(
        name = "{}_device_ios_cpus_platform_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ipa_app_companion",
        cpus = {
            "ios_multi_cpus": ["arm64"],
            "watchos_cpus": [""],
        },
        binary_test_file = "$BUNDLE_ROOT/Watch/app.app/app",
        binary_test_architecture = "arm64_32",
        binary_not_contains_architectures = ["arm64", "arm64e"],
        macho_load_commands_contain = ["cmd LC_VERSION_MIN_WATCHOS"],
        tags = [name],
    )

    # Test that the output multi-arch stub binary is identified as watchOS simulator via the Mach-O
    # load command LC_BUILD_VERSION for the arm64 binary slice, and that 32-bit archs are
    # eliminated.
    binary_contents_test(
        name = "{}_simulator_multiarch_platform_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ipa_app_companion",
        cpus = {
            "watchos_cpus": ["x86_64", "arm64"],
        },
        binary_test_file = "$BUNDLE_ROOT/Watch/app.app/_WatchKitStub/WK",
        binary_test_architecture = "arm64",
        binary_not_contains_architectures = ["i386", "arm64e"],
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "platform WATCHOSSIMULATOR"],
        tags = [name],
    )

    # Test that the output multi-arch stub binary is identified as watchOS device via the Mach-O
    # load command LC_VERSION_MIN_WATCHOS for the arm64_32 binary slice
    binary_contents_test(
        name = "{}_device_multiarch_arm32_platform_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ipa_app_companion",
        cpus = {
            "watchos_cpus": ["arm64_32"],
        },
        binary_test_file = "$BUNDLE_ROOT/Watch/app.app/_WatchKitStub/WK",
        binary_not_contains_architectures = ["arm64", "arm64e"],
        binary_test_architecture = "arm64_32",
        macho_load_commands_contain = ["cmd LC_VERSION_MIN_WATCHOS"],
        tags = [name],
    )

    # Test that the output binary for a single arch build is identified as watchOS device via the
    # Mach-O load command LC_VERSION_MIN_WATCHOS for the arm64_32 binary slice, and that the 64-bit
    # archs are eliminated.
    binary_contents_test(
        name = "{}_device_arm64_32_platform_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ipa_app_companion",
        cpus = {
            "watchos_cpus": ["arm64_32"],
        },
        binary_test_file = "$BUNDLE_ROOT/Watch/app.app/_WatchKitStub/WK",
        binary_not_contains_architectures = ["arm64e", "arm64"],
        binary_test_architecture = "arm64_32",
        macho_load_commands_contain = ["cmd LC_VERSION_MIN_WATCHOS"],
        tags = [name],
    )

    # Tests inclusion of extensions within Watch extensions
    archive_contents_test(
        name = "{}_contains_watchos_extension_extension".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ios_watchos_with_watchos_extension",
        contains = [
            "$BUNDLE_ROOT/Watch/app.app/PlugIns/ext.appex/PlugIns/watchos_app_extension.appex/watchos_app_extension",
        ],
        tags = [name],
    )

    # Tests inclusion of extensions within Watch extensions if defined with `extensions` as opposed to `extension`
    archive_contents_test(
        name = "{}_contains_watchos_extension_extensions".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ios_watchos_with_watchos_extension_within_extensions",
        contains = [
            "$BUNDLE_ROOT/Watch/app.app/PlugIns/ext.appex/PlugIns/watchos_app_extension.appex/watchos_app_extension",
        ],
        tags = [name],
    )

    # Tests that the tsan support libraries are found in the app extension bundle of a watchOS app.
    archive_contents_test(
        name = "{}_contains_tsan_dylib_device_test".format(name),
        build_type = "simulator",
        cpus = {
            # Thread sanitizer support does not exist for the 32 bit Intel simulator; force the
            # build to be 64 bit to get around this issue.
            "watchos_cpus": ["x86_64"],
        },
        contains = [
            "$BUNDLE_ROOT/Frameworks/libclang_rt.tsan_iossim_dynamic.dylib",
            "$BUNDLE_ROOT/Watch/app.app/PlugIns/ext.appex/Frameworks/libclang_rt.tsan_watchossim_dynamic.dylib",
        ],
        sanitizer = "tsan",
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:ios_watchos_with_watchos_extension",
        tags = [name],
    )

    # Test app with App Intents generates and bundles Metadata.appintents bundle.
    archive_contents_test(
        name = "{}_contains_app_intents_metadata_bundle".format(name),
        build_type = "simulator",
        cpus = {"watchos_cpus": ["arm64"]},
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_with_app_intents",
        contains = [
            "$BUNDLE_ROOT/Metadata.appintents/extract.actionsdata",
            "$BUNDLE_ROOT/Metadata.appintents/version.json",
        ],
        tags = [name],
    )

    apple_verification_test(
        name = "{}_app_intents_metadata_json_keys_sorted_test".format(name),
        build_type = "simulator",
        cpus = {"watchos_cpus": ["arm64"]},
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_with_app_intents",
        verifier_script = "verifier_scripts/app_intents_metadata_json_sorted.sh",
        env = {
            "JSON_FILES": [
                "$BUNDLE_ROOT/Metadata.appintents/version.json",
                "$BUNDLE_ROOT/Metadata.appintents/extract.actionsdata",
            ],
        },
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_capability_set_derived_bundle_id_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_with_ext_with_capability_set_derived_bundle_id",
        expected_values = {
            "CFBundleIdentifier": "com.bazel.app.example.watchkitapp",
        },
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_test_watchos_single_target_application_required_error".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_with_ext_with_invalid_watchos_version",
        expected_error = "Error: Building an app extension-based watchOS 2 application for watchOS 9.0 or later.",
        tags = [name],
    )

    # Test that watchos_application works without explicit infoplists
    analysis_target_tree_artifacts_outputs_test(
        name = "{}_no_infoplist_builds_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_minimal_no_infoplist",
        expected_outputs = ["app_minimal_no_infoplist.app"],
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_no_infoplist_has_default_values_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/watchos:app_minimal_no_infoplist",
        expected_values = {
            "CFBundleIdentifier": "com.google.example",
            "CFBundleName": "app_minimal_no_infoplist",
            "CFBundlePackageType": "APPL",
        },
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
