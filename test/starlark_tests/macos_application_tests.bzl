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

"""macos_application Starlark tests."""

load(
    "@bazel_skylib//lib:unittest.bzl",
    "analysistest",
    "asserts",
    "unittest",
)
load(
    "//apple/build_settings:build_settings.bzl",
    "build_settings_labels",
)
load(
    "//apple/internal:entitlements_support.bzl",
    "entitlements_support",
)
load(
    "//apple/internal:secure_features_support.bzl",
    "secure_features_support",
)
load(
    "//test/starlark_tests/rules:analysis_failure_message_test.bzl",
    "analysis_failure_message_test",
    "analysis_failure_message_with_tree_artifact_outputs_test",
    "make_analysis_failure_message_test",
)
load(
    "//test/starlark_tests/rules:analysis_output_group_info_files_test.bzl",
    "analysis_output_group_info_files_test",
)
load(
    "//test/starlark_tests/rules:analysis_runfiles_test.bzl",
    "analysis_runfiles_dsym_test",
)
load(
    "//test/starlark_tests/rules:analysis_target_actions_test.bzl",
    "analysis_target_actions_test",
    "make_analysis_target_actions_test",
)
load(
    "//test/starlark_tests/rules:apple_dsym_bundle_info_test.bzl",
    "apple_dsym_bundle_info_test",
)
load(
    "//test/starlark_tests/rules:apple_verification_test.bzl",
    "apple_verification_test",
)
load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "archive_contents_test",
)
load(
    "//test/starlark_tests/rules:directory_test.bzl",
    "directory_test",
)
load(
    "//test/starlark_tests/rules:infoplist_contents_test.bzl",
    "infoplist_contents_test",
)
load(
    "//test/starlark_tests/rules:validation_action_artifact_test.bzl",
    "validation_output_contents_test",
)
load(
    ":common.bzl",
    "common",
)

visibility("private")

def _xcode_26_6_version():
    return apple_common.dotted_version("26.6")

def _xcode_27_0_version():
    return apple_common.dotted_version("27.0")

def _secure_features_entitlements_unit_test_impl(ctx):
    env = unittest.begin(ctx)
    xcode_26 = struct(xcode_version = _xcode_26_6_version)
    xcode_27 = struct(xcode_version = _xcode_27_0_version)

    asserts.equals(
        env,
        {
            "com.apple.security.hardened-process": True,
            "com.apple.security.hardened-process.enhanced-security-version-string": "1",
        },
        secure_features_support.entitlements_from_secure_features(
            rule_label = ctx.label,
            secure_features = ["apple.enable_enhanced_security"],
            xcode_version_config = xcode_26,
        ),
    )
    asserts.equals(
        env,
        {
            "com.apple.security.hardened-process": True,
            "com.apple.security.hardened-process.enhanced-security-version-string": "1",
        },
        secure_features_support.entitlements_from_secure_features(
            rule_label = ctx.label,
            secure_features = [
                "apple.adopt_guard_objects",
                "apple.enable_enhanced_security",
            ],
            xcode_version_config = xcode_26,
        ),
    )
    asserts.equals(
        env,
        {
            "com.apple.security.hardened-process": True,
            "com.apple.security.hardened-process.enhanced-security-version-string": "2",
            "com.apple.security.hardened-process.no-guard-objects": True,
        },
        secure_features_support.entitlements_from_secure_features(
            rule_label = ctx.label,
            secure_features = ["apple.enable_enhanced_security"],
            xcode_version_config = xcode_27,
        ),
    )
    asserts.equals(
        env,
        {
            "com.apple.security.hardened-process": True,
            "com.apple.security.hardened-process.enhanced-security-version-string": "2",
        },
        secure_features_support.entitlements_from_secure_features(
            rule_label = ctx.label,
            secure_features = [
                "apple.adopt_guard_objects",
                "apple.enable_enhanced_security",
            ],
            xcode_version_config = xcode_27,
        ),
    )
    asserts.equals(
        env,
        {},
        secure_features_support.entitlements_from_secure_features(
            rule_label = ctx.label,
            secure_features = ["trivial_auto_var_init"],
            xcode_version_config = xcode_27,
        ),
    )
    asserts.equals(
        env,
        {},
        secure_features_support.entitlements_from_secure_features(
            rule_label = ctx.label,
            secure_features = [],
            xcode_version_config = xcode_27,
        ),
    )
    asserts.equals(
        env,
        [
            "apple.adopt_guard_objects",
            "apple.enable_enhanced_security",
        ],
        secure_features_support.crosstool_features_from_secure_features(
            features = [],
            name = ctx.label.name,
            secure_features = [
                "apple.adopt_guard_objects",
                "apple.enable_enhanced_security",
            ],
        ),
    )

    asserts.true(
        env,
        "com.apple.security.hardened-process.no-guard-objects" in secure_features_support.ALL_SECURE_FEATURES_ENTITLEMENTS_KEYS,
    )
    return unittest.end(env)

_secure_features_entitlements_unit_test = unittest.make(
    _secure_features_entitlements_unit_test_impl,
)

analysis_failure_message_with_intel_test = make_analysis_failure_message_test(
    config_settings = {
        "//command_line_option:macos_cpus": "x86_64",
        "//command_line_option:platforms": "//buildenv/platforms/apple:darwin_x86_64",
    },
)

analysis_target_actions_disable_legacy_signing_test = make_analysis_target_actions_test(
    config_settings = {
        "//command_line_option:features": ["disable_legacy_signing"],
        "//command_line_option:macos_cpus": "arm64",
    },
)

analysis_target_actions_disable_legacy_signing_compressed_test = make_analysis_target_actions_test(
    config_settings = {
        "//command_line_option:compilation_mode": "opt",
        "//command_line_option:features": ["disable_legacy_signing"],
        "//command_line_option:macos_cpus": "arm64",
    },
)

def _entitlements_options_action_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    actions = [a for a in target_under_test.actions if a.mnemonic == "ProcessEntitlementsFiles"]
    if not actions:
        analysistest.fail(env, "No ProcessEntitlementsFiles action found on target.")
        return analysistest.end(env)

    json_str = actions[0].argv[-1]
    if json_str.startswith("'") and json_str.endswith("'"):
        json_str = json_str[1:-1].replace("'\\''", "'")

    entitlements_options = json.decode(json_str).get("entitlements_options", {})
    expected = ctx.attr.expected_validate_macos_application_identifier
    if expected == "omitted":
        asserts.false(
            env,
            "validate_macos_application_identifier" in entitlements_options,
        )
    else:
        asserts.true(
            env,
            "validate_macos_application_identifier" in entitlements_options,
        )
        asserts.equals(
            env,
            expected == "true",
            entitlements_options.get("validate_macos_application_identifier"),
        )
    return analysistest.end(env)

def _make_entitlements_options_action_test(config_settings = {}):
    return analysistest.make(
        _entitlements_options_action_test_impl,
        attrs = {
            "expected_validate_macos_application_identifier": attr.string(
                mandatory = True,
                values = ["true", "false", "omitted"],
            ),
        },
        config_settings = config_settings,
    )

entitlements_options_action_test = _make_entitlements_options_action_test()

entitlements_options_disable_validate_macos_application_identifier_action_test = _make_entitlements_options_action_test(
    config_settings = {
        build_settings_labels.validate_macos_application_identifier: False,
    },
)

def _validate_macos_application_identifier_unit_test_impl(ctx):
    env = unittest.begin(ctx)
    enabled_settings = struct(validate_macos_application_identifier = True)
    disabled_settings = struct(validate_macos_application_identifier = False)
    macos_prereqs = struct(platform_type = "macos")
    ios_prereqs = struct(platform_type = "ios")

    asserts.true(
        env,
        entitlements_support.should_validate_macos_application_identifier(
            build_settings = enabled_settings,
            platform_prerequisites = macos_prereqs,
            rule_label = Label("//test/starlark_tests/targets_under_test/macos:app"),
        ),
    )
    asserts.false(
        env,
        entitlements_support.should_validate_macos_application_identifier(
            build_settings = disabled_settings,
            platform_prerequisites = macos_prereqs,
            rule_label = Label("//test/starlark_tests/targets_under_test/macos:app"),
        ),
    )
    asserts.false(
        env,
        entitlements_support.should_validate_macos_application_identifier(
            build_settings = enabled_settings,
            platform_prerequisites = ios_prereqs,
            rule_label = Label("//test/starlark_tests/targets_under_test/ios:app"),
        ),
    )

    return unittest.end(env)

_validate_macos_application_identifier_unit_test = unittest.make(
    _validate_macos_application_identifier_unit_test_impl,
)

analysis_target_actions_macos_signing_test = make_analysis_target_actions_test(
    config_settings = {
        build_settings_labels.force_codesigningtool_on_mac: True,
        build_settings_labels.signing_certificate_name: "",
        "//command_line_option:macos_cpus": "arm64",
    },
)

analysis_target_actions_tree_artifacts_macos_signing_test = make_analysis_target_actions_test(
    config_settings = {
        build_settings_labels.force_codesigningtool_on_mac: True,
        build_settings_labels.signing_certificate_name: "",
        build_settings_labels.use_tree_artifacts_outputs: True,
        "//command_line_option:macos_cpus": "arm64",
    },
)

analysis_target_actions_xplat_codesigning_test = make_analysis_target_actions_test(
    config_settings = {
        build_settings_labels.force_codesigningtool_on_mac: False,
        build_settings_labels.signing_certificate_name: "",
        "//command_line_option:macos_cpus": "arm64",
    },
)

analysis_target_actions_tree_artifacts_xplat_codesigning_test = make_analysis_target_actions_test(
    config_settings = {
        build_settings_labels.force_codesigningtool_on_mac: False,
        build_settings_labels.signing_certificate_name: "",
        build_settings_labels.use_tree_artifacts_outputs: True,
        "//command_line_option:macos_cpus": "arm64",
    },
)

analysis_target_actions_xplat_imported_framework_processor_test = make_analysis_target_actions_test(
    config_settings = {
        build_settings_labels.force_codesigningtool_on_mac: False,
        build_settings_labels.force_imported_dynamic_framework_processor_on_mac: False,
        build_settings_labels.signing_certificate_name: "",
        "//command_line_option:macos_cpus": "arm64",
    },
)

def macos_application_test_suite(name):
    """Test suite for macos_application.

    Args:
      name: the base name to be used in things created by this macro
    """
    apple_verification_test(
        name = "{}_codesign_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    # Verifies that a macOS app pinned to macOS by ipa_post_processor and ad-hoc signed via
    # adhoc_sign (ProcessAndSign and BundleTreeApp on Darwin when force_codesigningtool_on_mac is
    # False) passes `codesign --verify`.
    apple_verification_test(
        name = "{}_xplat_codesigning_with_post_processor_codesign_test".format(name),
        build_type = "device",
        build_settings = {
            build_settings_labels.force_codesigningtool_on_mac: "False",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/macos:macos_app_w_post_processor",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_xplat_codesigning_tree_artifact_with_post_processor_codesign_test".format(name),
        build_type = "device",
        build_settings = {
            build_settings_labels.force_codesigningtool_on_mac: "False",
            build_settings_labels.use_tree_artifacts_outputs: "True",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/macos:macos_app_w_post_processor",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    # Verifies that a macOS app with a versioned framework, ad-hoc signed on Linux via adhoc_sign
    # (ProcessAndSign on xplat), passes `codesign --verify` on macOS.
    apple_verification_test(
        name = "{}_xplat_codesigning_with_fmwk_codesign_test".format(name),
        build_type = "device",
        build_settings = {
            build_settings_labels.force_codesigningtool_on_mac: "False",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_fmwk",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_tree_artifact_codesign_test".format(name),
        build_type = "device",
        build_settings = {
            build_settings_labels.use_tree_artifacts_outputs: "True",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_imported_unversioned_fmwk_failure_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_unversioned_fmwk",
        expected_error = "Error: The contents of macOS frameworks must be defined within a Versions/A directory.",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_entitlements_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        verifier_script = "verifier_scripts/entitlements_verifier.sh",
        tags = [name],
    )

    # Verifies that XML and DER entitlements embedded on Linux via adhoc_sign (ProcessAndSign on
    # xplat) are readable via `codesign --display` on macOS.
    apple_verification_test(
        name = "{}_xplat_codesigning_entitlements_test".format(name),
        build_type = "device",
        build_settings = {
            build_settings_labels.force_codesigningtool_on_mac: "False",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        verifier_script = "verifier_scripts/entitlements_verifier.sh",
        tags = [name],
    )

    # Tests that the required Xcode 26 entitlements are added when enhanced security features are
    # assigned to a target.
    apple_verification_test(
        name = "{}_enhanced_security_features_entitlements_device_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:simple_enhanced_security_app",
        verifier_script = "verifier_scripts/entitlements_verifier.sh",
        env = {
            "ENTITLEMENTS_KEY": ["com.apple.security.hardened-process"],
        },
        tags = [name],
    )
    apple_verification_test(
        name = "{}_enhanced_security_features_xcode_entitlements_device_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:simple_enhanced_security_app",
        verifier_script = "verifier_scripts/entitlements_verifier.sh",
        env = {
            "ENTITLEMENTS_KEY": [
                "com.apple.security.hardened-process.enhanced-security-version-string",
                "com.apple.security.hardened-process.no-guard-objects",
            ],
            "ENTITLEMENT_VALUES": [
                "com.apple.security.hardened-process.enhanced-security-version-string=2",
                "com.apple.security.hardened-process.no-guard-objects=true",
            ],
        },
        tags = [
            name,
        ],
    )
    apple_verification_test(
        name = "{}_enhanced_security_adopt_guard_objects_xcode_entitlements_device_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:simple_enhanced_security_adopt_guard_objects_app",
        verifier_script = "verifier_scripts/entitlements_verifier.sh",
        env = {
            "ABSENT_ENTITLEMENT_KEYS": ["com.apple.security.hardened-process.no-guard-objects"],
            "ENTITLEMENTS_KEY": ["com.apple.security.hardened-process.enhanced-security-version-string"],
            "ENTITLEMENT_VALUES": ["com.apple.security.hardened-process.enhanced-security-version-string=2"],
        },
        tags = [
            name,
        ],
    )
    apple_verification_test(
        name = "{}_enhanced_security_without_entitlements_or_profile_device_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:simple_enhanced_security_app_without_entitlements_or_profile",
        verifier_script = "verifier_scripts/entitlements_verifier.sh",
        env = {
            "ENTITLEMENTS_KEY": [
                "com.apple.security.hardened-process",
                "com.apple.security.hardened-process.dyld-ro",
                "com.apple.security.hardened-process.enhanced-security-version-string",
                "com.apple.security.hardened-process.no-guard-objects",
            ],
            "ENTITLEMENT_VALUES": [
                "com.apple.security.hardened-process=true",
                "com.apple.security.hardened-process.dyld-ro=true",
                "com.apple.security.hardened-process.enhanced-security-version-string=2",
                "com.apple.security.hardened-process.no-guard-objects=true",
            ],
        },
        tags = [
            name,
        ],
    )
    apple_verification_test(
        name = "{}_xplat_codesigning_enhanced_security_without_entitlements_or_profile_device_test".format(name),
        build_type = "device",
        build_settings = {
            build_settings_labels.force_codesigningtool_on_mac: "False",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/macos:simple_enhanced_security_app_without_entitlements_or_profile",
        verifier_script = "verifier_scripts/entitlements_verifier.sh",
        env = {
            "ENTITLEMENTS_KEY": [
                "com.apple.security.hardened-process",
                "com.apple.security.hardened-process.dyld-ro",
                "com.apple.security.hardened-process.enhanced-security-version-string",
                "com.apple.security.hardened-process.no-guard-objects",
            ],
            "ENTITLEMENT_VALUES": [
                "com.apple.security.hardened-process=true",
                "com.apple.security.hardened-process.dyld-ro=true",
                "com.apple.security.hardened-process.enhanced-security-version-string=2",
                "com.apple.security.hardened-process.no-guard-objects=true",
            ],
        },
        tags = [
            name,
        ],
    )
    analysis_target_actions_test(
        name = "{}_enhanced_security_without_entitlements_or_profile_actions_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:simple_enhanced_security_app_without_entitlements_or_profile",
        target_mnemonic = "ProcessEntitlementsFiles",
        tags = [
            name,
        ],
    )
    analysis_target_actions_test(
        name = "{}_enhanced_security_without_entitlements_or_profile_dossier_actions_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:simple_enhanced_security_app_without_entitlements_or_profile",
        target_mnemonic = "GenerateCodesigningDossier",
        expected_argv = ["--entitlements-file-path"],
        expected_inputs = [
            "simple_enhanced_security_app_without_entitlements_or_profile_entitlements.entitlements",
        ],
        not_expected_argv = ["--provisioning-profile-path"],
        tags = [
            name,
        ],
    )
    analysis_failure_message_test(
        name = "{}_enhanced_security_adopt_guard_objects_missing_xcode_opt_in_fail_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:simple_enhanced_security_adopt_guard_objects_without_opt_in_app",
        expected_error = """
Apple enhanced security features were requested, but the build is missing the required feature \
"apple.enable_enhanced_security" that is needed to enable required entitlements in Xcode 26.0 or later.
""",
        tags = [name],
    )
    _secure_features_entitlements_unit_test(
        name = "{}_secure_features_entitlements_unit_test".format(name),
        tags = [name],
    )

    # Verifies pre-signed imported frameworks are not re-signed by ProcessAndSign.
    apple_verification_test(
        name = "{}_imported_versioned_fmwk_codesign_test".format(name),
        build_type = "device",
        build_settings = {
            build_settings_labels.force_codesigningtool_on_mac: "True",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_versioned_fmwk",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_imported_versioned_static_framework_xcframework_codesign_test".format(name),
        build_type = "device",
        build_settings = {
            build_settings_labels.force_codesigningtool_on_mac: "True",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_static_versioned_xcframework",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_imported_versioned_xcframework_codesign_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_dynamic_versioned_xcframework",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_imported_versioned_xcframework_xplat_processor_codesign_test".format(name),
        build_type = "device",
        build_settings = {
            build_settings_labels.force_imported_dynamic_framework_processor_on_mac: "False",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_dynamic_versioned_xcframework",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_imported_versioned_xcframework_xplat_processor_contents_test".format(name),
        build_type = "device",
        build_settings = {
            build_settings_labels.force_imported_dynamic_framework_processor_on_mac: "False",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_dynamic_versioned_xcframework",
        contains = [
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Resources",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Versions/A/Resources/Info.plist",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Versions/A/generated_dynamic_macos_versioned_xcframework",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Versions/Current",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/generated_dynamic_macos_versioned_xcframework",
        ],
        not_contains = [
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Headers/SharedClass.h",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Modules/module.modulemap",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Versions/A/Headers/SharedClass.h",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Versions/A/Modules/module.modulemap",
        ],
        assert_file_permissions = {
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Versions/A/Resources/Info.plist": "644",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Versions/A/generated_dynamic_macos_versioned_xcframework": "755",
        },
        is_symlink = [
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Resources",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Versions/Current",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/generated_dynamic_macos_versioned_xcframework",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_additional_contents_test".format(name),
        build_type = "device",
        contains = [
            "$CONTENT_ROOT/Additional/additional.txt",
            "$CONTENT_ROOT/Nested/non_nested.txt",
            "$CONTENT_ROOT/Nested/nested/nested.txt",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_correct_rpath_header_value_test".format(name),
        build_type = "device",
        binary_test_file = "$CONTENT_ROOT/MacOS/app",
        macho_load_commands_contain = ["path @executable_path/../Frameworks (offset 12)"],
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_resources_test".format(name),
        build_type = "device",
        contains = [
            "$CONTENT_ROOT/Resources/resource_bundle.bundle/Info.plist",
            "$CONTENT_ROOT/Resources/Another.plist",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_strings_device_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        contains = [
            "$RESOURCE_ROOT/localization.bundle/en.lproj/files.stringsdict",
            "$RESOURCE_ROOT/localization.bundle/en.lproj/greetings.strings",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_custom_linkopts_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_special_linkopts",
        binary_test_file = "$CONTENT_ROOT/MacOS/app_special_linkopts",
        compilation_mode = "opt",
        binary_test_architecture = "arm64",
        binary_contains_symbols = ["_linkopts_test_main"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_bundle_name_with_space_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_space_in_bundle_name",
        compilation_mode = "opt",
        contains = [
            "$ARCHIVE_ROOT/app with space.app",
        ],
        not_contains = [
            "$ARCHIVE_ROOT/app.app",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_additional_contents_bundling_app_with_bundles_test".format(name),
        build_type = "device",
        build_settings = {
            build_settings_labels.use_tree_artifacts_outputs: "True",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_bundling_app",
        contains = [
            "$ARCHIVE_ROOT/app_bundling_app.app/Contents/Helpers/app_basic_swift.app",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_additional_contents_bundling_app_with_zips_test".format(name),
        build_type = "device",
        build_settings = {
            build_settings_labels.use_tree_artifacts_outputs: "False",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_bundling_app",
        contains = [
            "$ARCHIVE_ROOT/app_bundling_app.app/Contents/Helpers/app_basic_swift.app",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_prebuilt_dynamic_versioned_framework_dependency_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_versioned_fmwk",
        contains = [
            "$CONTENT_ROOT/Frameworks/generated_macos_dynamic_versioned_fmwk.framework/Resources",
            "$CONTENT_ROOT/Frameworks/generated_macos_dynamic_versioned_fmwk.framework/Versions/A/Resources/Info.plist",
            "$CONTENT_ROOT/Frameworks/generated_macos_dynamic_versioned_fmwk.framework/Versions/A/generated_macos_dynamic_versioned_fmwk",
            "$CONTENT_ROOT/Frameworks/generated_macos_dynamic_versioned_fmwk.framework/Versions/Current",
            "$CONTENT_ROOT/Frameworks/generated_macos_dynamic_versioned_fmwk.framework/generated_macos_dynamic_versioned_fmwk",
        ],
        not_contains = [
            "$CONTENT_ROOT/Frameworks/generated_macos_dynamic_versioned_fmwk.framework/Headers/SharedClass.h",
            "$CONTENT_ROOT/Frameworks/generated_macos_dynamic_versioned_fmwk.framework/Modules/module.modulemap",
            "$CONTENT_ROOT/Frameworks/generated_macos_dynamic_versioned_fmwk.framework/Versions/A/Headers/SharedClass.h",
            "$CONTENT_ROOT/Frameworks/generated_macos_dynamic_versioned_fmwk.framework/Versions/A/Modules/module.modulemap",
            "$CONTENT_ROOT/Frameworks/generated_macos_dynamic_versioned_fmwk.framework/Versions/B/Headers/SharedClass.h",
            "$CONTENT_ROOT/Frameworks/generated_macos_dynamic_versioned_fmwk.framework/Versions/B/Modules/module.modulemap",
            "$CONTENT_ROOT/Frameworks/generated_macos_dynamic_versioned_fmwk.framework/Versions/B/Resources/Info.plist",
            "$CONTENT_ROOT/Frameworks/generated_macos_dynamic_versioned_fmwk.framework/Versions/B/generated_macos_dynamic_versioned_fmwk",
        ],
        assert_file_permissions = {
            "$CONTENT_ROOT/Frameworks/generated_macos_dynamic_versioned_fmwk.framework/Versions/A/Resources/Info.plist": "644",
            "$CONTENT_ROOT/Frameworks/generated_macos_dynamic_versioned_fmwk.framework/Versions/A/generated_macos_dynamic_versioned_fmwk": "755",
        },
        is_symlink = [
            "$CONTENT_ROOT/Frameworks/generated_macos_dynamic_versioned_fmwk.framework/Resources",
            "$CONTENT_ROOT/Frameworks/generated_macos_dynamic_versioned_fmwk.framework/Versions/Current",
            "$CONTENT_ROOT/Frameworks/generated_macos_dynamic_versioned_fmwk.framework/generated_macos_dynamic_versioned_fmwk",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_prebuilt_static_versioned_xcframework_dependency_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_static_versioned_xcframework",
        contains = [
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Resources",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Versions/A/Resources/Info.plist",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Versions/A/generated_static_macos_versioned_xcframework",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Versions/Current",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/generated_static_macos_versioned_xcframework",
        ],
        not_contains = [
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Headers/SharedClass.h",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Modules/module.modulemap",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Versions/A/Headers/SharedClass.h",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Versions/A/Modules/module.modulemap",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Versions/B/Headers/SharedClass.h",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Versions/B/Modules/module.modulemap",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Versions/B/Resources/Info.plist",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Versions/B/generated_static_macos_versioned_xcframework",
        ],
        assert_file_permissions = {
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Versions/A/Resources/Info.plist": "644",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Versions/A/generated_static_macos_versioned_xcframework": "755",
        },
        is_symlink = [
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Resources",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/Versions/Current",
            "$CONTENT_ROOT/Frameworks/generated_static_macos_versioned_xcframework.framework/generated_static_macos_versioned_xcframework",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_prebuilt_dynamic_versioned_xcframework_dependency_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_dynamic_versioned_xcframework",
        contains = [
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Resources",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Versions/A/Resources/Info.plist",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Versions/A/generated_dynamic_macos_versioned_xcframework",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Versions/Current",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/generated_dynamic_macos_versioned_xcframework",
        ],
        not_contains = [
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Headers/SharedClass.h",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Modules/module.modulemap",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Versions/A/Headers/SharedClass.h",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Versions/A/Modules/module.modulemap",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Versions/B/Headers/SharedClass.h",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Versions/B/Modules/module.modulemap",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Versions/B/Resources/Info.plist",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Versions/B/generated_dynamic_macos_versioned_xcframework",
        ],
        assert_file_permissions = {
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Versions/A/Resources/Info.plist": "644",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Versions/A/generated_dynamic_macos_versioned_xcframework": "755",
        },
        is_symlink = [
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Resources",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/Versions/Current",
            "$CONTENT_ROOT/Frameworks/generated_dynamic_macos_versioned_xcframework.framework/generated_dynamic_macos_versioned_xcframework",
        ],
        tags = [name],
    )

    analysis_output_group_info_files_test(
        name = "{}_dsyms_output_group_dsymutil_bundle_files_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        output_group_name = "dsyms",
        expected_outputs = [
            "app.app.dSYM",
        ],
        tags = [name],
    )
    apple_dsym_bundle_info_test(
        name = "{}_dsym_bundle_info_dsymutil_bundle_files_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        expected_direct_dsyms = [
            "app.app.dSYM",
        ],
        expected_transitive_dsyms = [
            "app.app.dSYM",
        ],
        tags = [name],
    )

    analysis_runfiles_dsym_test(
        name = "{}_runfiles_dsymutil_bundle_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        expected_runfiles = [
            "third_party/bazel_rules/rules_apple/test/starlark_tests/targets_under_test/macos/app.app.dSYM",
        ],
        tags = [name],
    )

    analysis_output_group_info_files_test(
        name = "{}_dsyms_output_group_dsymutil_bundle_files_test_with_spaces".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app with space in target name",
        output_group_name = "dsyms",
        expected_outputs = [
            "app with space in target name.app.dSYM",
        ],
        tags = [name],
    )
    apple_dsym_bundle_info_test(
        name = "{}_dsym_bundle_info_dsymutil_bundle_files_test_with_spaces".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app with space in target name",
        expected_direct_dsyms = [
            "app with space in target name.app.dSYM",
        ],
        expected_transitive_dsyms = [
            "app with space in target name.app.dSYM",
        ],
        tags = [name],
    )

    analysis_runfiles_dsym_test(
        name = "{}_runfiles_dsymutil_bundle_test_with_spaces".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app with space in target name",
        expected_runfiles = [
            "third_party/bazel_rules/rules_apple/test/starlark_tests/targets_under_test/macos/app with space in target name.app.dSYM",
        ],
        tags = [name],
    )

    analysis_output_group_info_files_test(
        name = "{}_dsyms_output_group_dsymutil_bundle_files_test_with_bundle_name_spaces".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_space_in_bundle_name",
        output_group_name = "dsyms",
        expected_outputs = [
            "app with space.app.dSYM",
        ],
        tags = [name],
    )
    apple_dsym_bundle_info_test(
        name = "{}_dsym_bundle_info_dsymutil_bundle_files_test_with_bundle_name_spaces".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_space_in_bundle_name",
        expected_direct_dsyms = [
            "app with space.app.dSYM",
        ],
        expected_transitive_dsyms = [
            "app with space.app.dSYM",
        ],
        tags = [name],
    )

    analysis_runfiles_dsym_test(
        name = "{}_runfiles_dsymutil_bundle_test_with_bundle_name_spaces".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_space_in_bundle_name",
        expected_runfiles = [
            "third_party/bazel_rules/rules_apple/test/starlark_tests/targets_under_test/macos/app with space.app.dSYM",
        ],
        tags = [name],
    )

    directory_test(
        name = "{}_dsym_directory_test".format(name),
        apple_generate_dsym = True,
        build_type = "device",
        compilation_mode = "opt",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        expected_directories = {
            "app.app.dSYM": [
                "Contents/Resources/DWARF/app_bin",
                "Contents/Info.plist",
            ],
        },
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        expected_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "app",
            "CFBundleIdentifier": "com.google.example",
            "CFBundleName": "app",
            "CFBundlePackageType": "APPL",
            "CFBundleSupportedPlatforms:0": "MacOSX",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "macosx",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "macosx*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "LSMinimumSystemVersion": common.min_os_macos.min_deployment_target,
        },
        tags = [name],
    )

    # Tests xcasset tool is passed the correct arguments.
    analysis_target_actions_test(
        name = "{}_xcasset_actool_argv".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        target_mnemonic = "AssetCatalogCompile",
        expected_argv = [
            "--compile",
            "--minimum-deployment-target " + common.min_os_macos.min_deployment_target,
            "--platform macosx",
        ],
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_multiple_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_multiple_infoplists",
        expected_values = {
            "AnotherKey": "AnotherValue",
            "CFBundleExecutable": "app_multiple_infoplists",
        },
        tags = [name],
    )

    # Verify importing versioned framework with tree artifacts enabled requires disabling legacy
    # signing.
    analysis_failure_message_with_tree_artifact_outputs_test(
        name = "{}_fails_with_imported_versioned_framework_and_tree_artifact_outputs".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_versioned_fmwk",
        expected_error = (
            "Error: \"imported_dynamic_versioned_fmwk\" does not support versioned frameworks " +
            "with the bundle outputs feature/build setting without disabling legacy signing."
        ),
        tags = [name],
    )

    # Test app with App Intents generates and bundles Metadata.appintents bundle.
    archive_contents_test(
        name = "{}_contains_app_intents_metadata_bundle".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_app_intents",
        contains = [
            "$RESOURCE_ROOT/Metadata.appintents/extract.actionsdata",
            "$RESOURCE_ROOT/Metadata.appintents/version.json",
        ],
        tags = [name],
    )

    validation_output_contents_test(
        name = "{}_app_intents_conformances_validation_execution_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_app_intents",
        validation_file_name = "app_with_app_intents_app_intents_conformances_validation.txt",
        allow_empty = True,
        tags = [name],
    )
    validation_output_contents_test(
        name = "{}_hinted_app_intent_aspect_validation_execution_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_app_intents",
        validation_file_name = "hinted_app_intent_app_intents_validation.txt",
        allow_empty = True,
        tags = [name],
    )

    # Test app with transitive App Intents generates and bundles Metadata.appintents bundle.
    archive_contents_test(
        name = "{}_with_transitive_app_intents_contains_app_intents_metadata_bundle_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_transitive_app_intents",
        contains = [
            "$RESOURCE_ROOT/Metadata.appintents/extract.actionsdata",
            "$RESOURCE_ROOT/Metadata.appintents/version.json",
        ],
        tags = [name],
    )

    validation_output_contents_test(
        name = "{}_with_transitive_app_intents_conformances_validation_execution_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_transitive_app_intents",
        validation_file_name = "app_with_transitive_app_intents_app_intents_conformances_validation.txt",
        allow_empty = True,
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_capability_set_derived_bundle_id_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_capability_set_derived_bundle_id",
        expected_values = {
            "CFBundleIdentifier": "com.bazel.app.example",
        },
        tags = [name],
    )

    archive_contents_test(
        name = "{}_is_building_apple_bundle_test".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:bundled_app_to_test_building_apple_bundle",
        binary_test_file = "$CONTENT_ROOT/MacOS/bundled_app_to_test_building_apple_bundle",
        binary_test_architecture = "arm64",
        binary_contains_symbols = ["_IsBuildingAppleBundle"],
        binary_not_contains_symbols = ["_IsNotBuildingAppleBundle"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_with_fmwk_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_fmwk",
        contains = [
            "$CONTENT_ROOT/Frameworks/fmwk.framework/Versions/A/fmwk",
            "$CONTENT_ROOT/Frameworks/fmwk.framework/Versions/A/Resources/Info.plist",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_with_ext_with_fmwk_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_ext_with_fmwk",
        contains = [
            "$CONTENT_ROOT/Frameworks/fmwk.framework/Versions/A/fmwk",
            "$CONTENT_ROOT/Frameworks/fmwk.framework/Versions/A/Resources/Info.plist",
            "$CONTENT_ROOT/PlugIns/ext_with_fmwk.appex/Contents/MacOS/ext_with_fmwk",
        ],
        not_contains = [
            "$CONTENT_ROOT/PlugIns/ext_with_fmwk.appex/Contents/Frameworks/fmwk.framework/Versions/A/fmwk",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_pkginfo_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:macos_app_fixture",
        contains = [
            "$CONTENT_ROOT/PkgInfo",
        ],
        text_test_file = "$CONTENT_ROOT/PkgInfo",
        text_test_values = [
            "^APPL????$",
        ],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_post_processor_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:macos_app_w_post_processor",
        contains = [
            "$RESOURCE_ROOT/post_processed.txt",
        ],
        text_test_file = "$RESOURCE_ROOT/post_processed.txt",
        text_test_values = [
            "^post-processed$",
        ],
        tags = [name],
    )

    analysis_failure_message_with_intel_test(
        name = "{}_x86_64_macos_27_failure_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_minimum_os_intel_deprecation",
        expected_error = "macOS 27.0 and later is Apple Silicon only, and has no Intel native counterpart.",
        tags = [
            name,
        ],
    )

    archive_contents_test(
        name = "{}_defaults_to_arm64_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_minimum_os_intel_deprecation",
        binary_test_file = "$CONTENT_ROOT/MacOS/app_minimum_os_intel_deprecation",
        binary_test_architecture = "arm64",
        cpus = {"macos_cpus": []},
        binary_contains_symbols = ["_main"],
        tags = [
            name,
        ],
    )

    analysis_target_actions_disable_legacy_signing_test(
        name = "{}_direct_bundle_archive_disable_legacy_signing_skips_process_and_sign_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        target_mnemonic = "BundleApp",
        expected_argv = ["--control_schema_version=2"],
        expected_content = ["app.zip"],
        not_expected_content = ['"compression_level"', "unprocessed_archive.zip"],
        not_expected_mnemonic = ["ProcessAndSign"],
        not_expected_execution_requirements = ["requires-darwin"],
        tags = [name],
    )

    analysis_target_actions_disable_legacy_signing_compressed_test(
        name = "{}_direct_bundle_archive_disable_legacy_signing_compressed_skips_process_and_sign_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        target_mnemonic = "BundleApp",
        expected_argv = ["--control_schema_version=2"],
        expected_content = ["app.zip", '"compression_level":6'],
        not_expected_content = ["unprocessed_archive.zip"],
        not_expected_mnemonic = ["ProcessAndSign"],
        not_expected_execution_requirements = ["requires-darwin"],
        tags = [name],
    )

    archive_contents_test(
        name = "{}_direct_bundle_archive_disable_legacy_signing_contents_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        target_features = ["disable_legacy_signing"],
        contains = [
            "$CONTENT_ROOT/Info.plist",
            "$CONTENT_ROOT/MacOS/app",
            "$CONTENT_ROOT/PkgInfo",
        ],
        tags = [name],
    )

    _validate_macos_application_identifier_unit_test(
        name = "{}_validate_macos_application_identifier_unit_test".format(name),
        tags = [name],
    )

    entitlements_options_action_test(
        name = "{}_validate_macos_application_identifier_default_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        expected_validate_macos_application_identifier = "true",
        tags = [name],
    )

    entitlements_options_disable_validate_macos_application_identifier_action_test(
        name = "{}_validate_macos_application_identifier_disabled_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        expected_validate_macos_application_identifier = "false",
        tags = [name],
    )

    entitlements_options_action_test(
        name = "{}_validate_macos_application_identifier_omitted_on_ios_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_enhanced_security_extension",
        expected_validate_macos_application_identifier = "omitted",
        tags = [name],
    )

    apple_verification_test(
        name = "{}_validate_macos_application_identifier_injects_entitlement_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        verifier_script = "verifier_scripts/entitlements_verifier.sh",
        env = {
            "ENTITLEMENTS_KEY": ["com.apple.application-identifier"],
            "ENTITLEMENT_VALUES": ["com.apple.application-identifier=FOOBARBAZ1.*"],
        },
        tags = [name],
    )

    apple_verification_test(
        name = "{}_validate_macos_application_identifier_disabled_omits_entitlement_test".format(name),
        build_type = "device",
        build_settings = {
            build_settings_labels.validate_macos_application_identifier: "False",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        verifier_script = "verifier_scripts/entitlements_verifier.sh",
        env = {
            "ABSENT_ENTITLEMENT_KEYS": ["com.apple.application-identifier"],
        },
        tags = [name],
    )

    analysis_target_actions_macos_signing_test(
        name = "{}_process_and_sign_unprovisioned_uses_codesign_when_forced_on_mac_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_fmwk",
        target_mnemonic = "ProcessAndSign",
        expected_argv = ["should_sign"],
        expected_content = ["/usr/bin/codesign"],
        not_expected_content = ["adhoc_sign"],
        expected_execution_requirements = {
            "no-sandbox": "1",
            "requires-darwin": "",
        },
        tags = [name],
    )

    analysis_target_actions_tree_artifacts_macos_signing_test(
        name = "{}_bundle_tree_app_unprovisioned_uses_codesign_when_forced_on_mac_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_icon_bundle",
        target_mnemonic = "BundleTreeApp",
        expected_content = ["/usr/bin/codesign"],
        not_expected_content = ["adhoc_sign"],
        expected_execution_requirements = {
            "no-sandbox": "1",
            "requires-darwin": "",
        },
        tags = [name],
    )

    analysis_target_actions_xplat_codesigning_test(
        name = "{}_process_and_sign_xplat_codesigning_with_post_processor_uses_adhoc_sign_on_darwin_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:macos_app_w_post_processor",
        target_mnemonic = "ProcessAndSign",
        expected_argv = ["should_sign", "should_process"],
        expected_content = ["adhoc_sign"],
        not_expected_content = ["/usr/bin/codesign"],
        expected_execution_requirements = {"requires-darwin": ""},
        not_expected_execution_requirements = [
            "no-cache",
            "no-sandbox",
        ],
        tags = [name],
    )

    analysis_target_actions_tree_artifacts_xplat_codesigning_test(
        name = "{}_bundle_tree_app_xplat_codesigning_with_post_processor_uses_adhoc_sign_on_darwin_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:macos_app_w_post_processor",
        target_mnemonic = "BundleTreeApp",
        expected_content = ["adhoc_sign"],
        not_expected_content = ["/usr/bin/codesign"],
        expected_execution_requirements = {"requires-darwin": ""},
        not_expected_execution_requirements = [
            "no-remote",
            "no-sandbox",
        ],
        tags = [name],
    )

    analysis_target_actions_xplat_codesigning_test(
        name = "{}_process_and_sign_provisioned_uses_codesign_on_darwin_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app",
        target_mnemonic = "ProcessAndSign",
        expected_argv = ["should_sign"],
        expected_content = ["/usr/bin/codesign", "--mobileprovision"],
        not_expected_content = ["adhoc_sign"],
        expected_inputs = ["_macos.provisionprofile"],
        expected_execution_requirements = {
            "no-sandbox": "1",
            "requires-darwin": "",
        },
        tags = [name],
    )

    analysis_target_actions_xplat_imported_framework_processor_test(
        name = "{}_imported_versioned_xcframework_xplat_processor_omits_darwin_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:app_with_imported_dynamic_versioned_xcframework",
        target_mnemonic = "ImportedDynamicFrameworkProcessor",
        expected_argv = ["--disable-signing"],
        not_expected_argv = ["--codesign"],
        not_expected_execution_requirements = ["requires-darwin"],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
