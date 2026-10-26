# Copyright 2026 The Bazel Authors. All rights reserved.
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

"""Starlark tests for `.strings` and `.stringsdict` processing via `plisttool`."""

load(
    "@bazel_skylib//lib:unittest.bzl",
    "analysistest",
)
load(
    "//apple/build_settings:build_settings.bzl",
    "build_settings_labels",
)
load(
    "//apple/internal/aspects:resource_aspect.bzl",
    "apple_resource_aspect",
)
load(
    "//test/starlark_tests/rules:analysis_target_actions_test.bzl",
    "make_analysis_target_actions_test",
)
load(
    "//test/starlark_tests/rules:plisttool_action_test.bzl",
    "make_plisttool_action_test",
)

visibility("private")

def _bundle_inputs_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    bundle_actions = [
        a
        for a in target_under_test.actions
        if a.mnemonic in ("BundleApp", "BundleTreeApp")
    ]
    if not bundle_actions:
        analysistest.fail(env, "No BundleApp or BundleTreeApp action found on target.")
        return analysistest.end(env)

    input_short_paths = [f.short_path for f in bundle_actions[0].inputs.to_list()]
    for expected_suffix in ctx.attr.expected_input_suffixes:
        if not any([p.endswith(expected_suffix) for p in input_short_paths]):
            analysistest.fail(
                env,
                "Expected BundleApp input ending with '{}', but inputs were: {}".format(
                    expected_suffix,
                    input_short_paths,
                ),
            )

    for unexpected_suffix in ctx.attr.unexpected_input_suffixes:
        if any([p.endswith(unexpected_suffix) for p in input_short_paths]):
            analysistest.fail(
                env,
                "Expected BundleApp inputs not to contain suffix '{}', but inputs were: {}".format(
                    unexpected_suffix,
                    input_short_paths,
                ),
            )

    return analysistest.end(env)

def _make_bundle_inputs_test(config_settings = {}):
    return analysistest.make(
        _bundle_inputs_test_impl,
        attrs = {
            "expected_input_suffixes": attr.string_list(),
            "unexpected_input_suffixes": attr.string_list(),
        },
        config_settings = config_settings,
    )

_compile_strings_opt_plisttool_test = make_plisttool_action_test(
    config_settings = {
        build_settings_labels.compile_strings_with_plisttool: True,
        "//command_line_option:compilation_mode": "opt",
    },
)

_validate_strings_non_opt_plisttool_test = make_plisttool_action_test(
    config_settings = {
        build_settings_labels.validate_strings_with_plisttool: True,
        "//command_line_option:compilation_mode": "fastbuild",
    },
)

_validate_strings_opt_plisttool_test = make_plisttool_action_test(
    config_settings = {
        build_settings_labels.validate_strings_with_plisttool: True,
        "//command_line_option:compilation_mode": "opt",
    },
)

_aspect_compile_strings_opt_plisttool_test = make_plisttool_action_test(
    config_settings = {
        build_settings_labels.compile_strings_with_plisttool: True,
        "//command_line_option:compilation_mode": "opt",
        "//command_line_option:platforms": "//buildenv/platforms/apple:darwin_arm64",
    },
    extra_target_under_test_aspects = [apple_resource_aspect],
)

_aspect_validate_strings_non_opt_plisttool_test = make_plisttool_action_test(
    config_settings = {
        build_settings_labels.validate_strings_with_plisttool: True,
        "//command_line_option:compilation_mode": "fastbuild",
        "//command_line_option:platforms": "//buildenv/platforms/apple:darwin_arm64",
    },
    extra_target_under_test_aspects = [apple_resource_aspect],
)

_validate_strings_warnings_as_errors_plisttool_test = make_plisttool_action_test(
    config_settings = {
        build_settings_labels.validate_strings_with_plisttool: True,
        build_settings_labels.warnings_as_errors: True,
        "//command_line_option:compilation_mode": "fastbuild",
    },
)

_validate_strings_force_mac_plisttool_test = make_plisttool_action_test(
    config_settings = {
        build_settings_labels.force_plisttool_on_mac: True,
        build_settings_labels.validate_strings_with_plisttool: True,
        "//command_line_option:compilation_mode": "fastbuild",
    },
)

_flags_off_opt_actions_test = make_analysis_target_actions_test(
    config_settings = {
        build_settings_labels.compile_strings_with_plisttool: False,
        build_settings_labels.require_pointer_authentication_attribute: True,
        "//command_line_option:compilation_mode": "opt",
        "//command_line_option:macos_cpus": "arm64",
    },
)

_flags_off_non_opt_actions_test = make_analysis_target_actions_test(
    config_settings = {
        build_settings_labels.require_pointer_authentication_attribute: True,
        build_settings_labels.validate_strings_with_plisttool: False,
        "//command_line_option:compilation_mode": "fastbuild",
        "//command_line_option:macos_cpus": "arm64",
    },
)

_flags_on_opt_actions_test = make_analysis_target_actions_test(
    config_settings = {
        build_settings_labels.compile_strings_with_plisttool: True,
        build_settings_labels.require_pointer_authentication_attribute: True,
        "//command_line_option:compilation_mode": "opt",
        "//command_line_option:macos_cpus": "arm64",
    },
)

_flags_on_non_opt_actions_test = make_analysis_target_actions_test(
    config_settings = {
        build_settings_labels.require_pointer_authentication_attribute: True,
        build_settings_labels.validate_strings_with_plisttool: True,
        "//command_line_option:compilation_mode": "fastbuild",
        "//command_line_option:macos_cpus": "arm64",
    },
)

_bundle_inputs_validate_non_opt_test = _make_bundle_inputs_test(
    config_settings = {
        build_settings_labels.validate_strings_with_plisttool: True,
        "//command_line_option:compilation_mode": "fastbuild",
    },
)

_bundle_inputs_compile_opt_test = _make_bundle_inputs_test(
    config_settings = {
        build_settings_labels.compile_strings_with_plisttool: True,
        "//command_line_option:compilation_mode": "opt",
    },
)

def apple_strings_plisttool_test_suite(name):
    """Test suite for strings validation and compilation via plisttool.

    Args:
      name: the base name to be used in things created by this macro
    """

    # Opt + compile_strings_with_plisttool=True: .strings uses CompileStrings with plisttool on Mac.
    _compile_strings_opt_plisttool_test(
        name = "{}_opt_compile_strings_with_plisttool_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_strings",
        target_mnemonic = "CompileStrings",
        expected_control_dict = json.encode({
            "binary": True,
            "individual_plist": "*/nonlocalized.strings",
            "output": "*/nonlocalized.strings",
            "validate_strings": True,
            "target": "//test/starlark_tests/targets_under_test/ios:app_with_top_level_strings",
        }),
        unexpected_control_keys = [
            "copy_input_on_success",
            "use_swift_plisttool",
        ],
        expected_execution_requirements = {"requires-darwin": ""},
        assert_output_bundled = True,
        tags = [name],
    )

    # Opt + compile_strings_with_plisttool=True: .stringsdict uses CompilePlist with plisttool on
    # Mac.
    _compile_strings_opt_plisttool_test(
        name = "{}_opt_compile_stringsdict_with_plisttool_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_stringsdict",
        target_mnemonic = "CompilePlist",
        expected_control_dict = json.encode({
            "binary": True,
            "individual_plist": "*/files.stringsdict",
            "output": "*/files.stringsdict",
            "validate_strings": True,
            "target": "//test/starlark_tests/targets_under_test/ios:app_with_top_level_stringsdict",
        }),
        unexpected_control_keys = [
            "copy_input_on_success",
            "use_swift_plisttool",
        ],
        expected_execution_requirements = {"requires-darwin": ""},
        assert_output_bundled = True,
        tags = [name],
    )

    # Non-opt + validate_strings_with_plisttool=True: .strings uses ValidateStrings on Linux and
    # bundles output.
    _validate_strings_non_opt_plisttool_test(
        name = "{}_non_opt_validate_strings_with_plisttool_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_strings",
        target_mnemonic = "ValidateStrings",
        expected_control_dict = json.encode({
            "binary": False,
            "copy_input_on_success": True,
            "individual_plist": "*/nonlocalized.strings",
            "output": "*/nonlocalized.strings",
            "validate_strings": True,
            "target": "//test/starlark_tests/targets_under_test/ios:app_with_top_level_strings",
        }),
        unexpected_control_keys = ["use_swift_plisttool"],
        not_expected_execution_requirements = ["requires-darwin"],
        assert_output_bundled = True,
        tags = [name],
    )

    # Non-opt + validate_strings_with_plisttool=True: .stringsdict uses ValidateStrings on Linux and
    # bundles output.
    _validate_strings_non_opt_plisttool_test(
        name = "{}_non_opt_validate_stringsdict_with_plisttool_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_stringsdict",
        target_mnemonic = "ValidateStrings",
        expected_control_dict = json.encode({
            "binary": False,
            "copy_input_on_success": True,
            "individual_plist": "*/files.stringsdict",
            "output": "*/files.stringsdict",
            "validate_strings": True,
            "target": "//test/starlark_tests/targets_under_test/ios:app_with_top_level_stringsdict",
        }),
        unexpected_control_keys = ["use_swift_plisttool"],
        not_expected_execution_requirements = ["requires-darwin"],
        assert_output_bundled = True,
        tags = [name],
    )

    # Flags off in opt: existing plutil CompileStrings shell action on Mac, no ValidateStrings.
    _flags_off_opt_actions_test(
        name = "{}_flags_off_opt_uses_plutil_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_strings",
        target_mnemonic = "CompileStrings",
        expected_argv = ["plutil -convert binary1"],
        expected_execution_requirements = {"requires-darwin": ""},
        not_expected_mnemonic = ["ValidateStrings"],
        tags = [name],
    )

    # Flags off in non-opt: neither ValidateStrings nor CompileStrings is registered.
    _flags_off_non_opt_actions_test(
        name = "{}_flags_off_non_opt_no_strings_actions_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_strings",
        target_mnemonic = "BundleApp",
        not_expected_mnemonic = [
            "CompileStrings",
            "ValidateStrings",
        ],
        tags = [name],
    )

    # .plist files stay on compile_plist (plutil) in opt even when
    # compile_strings_with_plisttool=True.
    _flags_on_opt_actions_test(
        name = "{}_plist_in_opt_still_uses_plutil_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_plist",
        target_mnemonic = "CompilePlist",
        expected_argv = ["plutil -convert binary1"],
        expected_execution_requirements = {"requires-darwin": ""},
        not_expected_mnemonic = ["ValidateStrings"],
        tags = [name],
    )

    # .plist files are copied as-is in non-opt even when validate_strings_with_plisttool=True.
    _flags_on_non_opt_actions_test(
        name = "{}_plist_in_non_opt_not_validated_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_plist",
        target_mnemonic = "BundleApp",
        not_expected_mnemonic = [
            "CompilePlist",
            "ValidateStrings",
        ],
        tags = [name],
    )

    # MergeStrings in non-opt with validate_strings_with_plisttool=True: XML output on Linux,
    # validated.
    _validate_strings_non_opt_plisttool_test(
        name = "{}_merge_strings_non_opt_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_mergeable_strings",
        target_mnemonic = "MergeStrings",
        expected_control_dict = json.encode({
            "binary": True,
            "plists": ["*"],
            "skip_substitutions": True,
            "validate_strings": True,
            "target": "//test/starlark_tests/targets_under_test/ios:app_with_mergeable_strings",
        }),
        unexpected_control_keys = ["use_swift_plisttool"],
        not_expected_execution_requirements = ["requires-darwin"],
        assert_output_bundled = True,
        tags = [name],
    )

    # MergeStrings in opt with validate_strings_with_plisttool=True: binary output on Linux,
    # validated.
    _validate_strings_opt_plisttool_test(
        name = "{}_merge_strings_opt_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_mergeable_strings",
        target_mnemonic = "MergeStrings",
        expected_control_dict = json.encode({
            "binary": True,
            "plists": ["*"],
            "skip_substitutions": True,
            "validate_strings": True,
            "target": "//test/starlark_tests/targets_under_test/ios:app_with_mergeable_strings",
        }),
        unexpected_control_keys = ["use_swift_plisttool"],
        not_expected_execution_requirements = ["requires-darwin"],
        assert_output_bundled = True,
        tags = [name],
    )

    # warnings_as_errors=True doesn't affect targets that aren't on the strings validation
    # allowlist.
    _validate_strings_warnings_as_errors_plisttool_test(
        name = "{}_warnings_as_errors_validates_non_exempt_target_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_strings",
        target_mnemonic = "ValidateStrings",
        expected_control_dict = json.encode({
            "binary": False,
            "copy_input_on_success": True,
            "validate_strings": True,
        }),
        tags = [name],
    )

    # force_plisttool_on_mac=True routes non-opt ValidateStrings to the Mac.
    _validate_strings_force_mac_plisttool_test(
        name = "{}_force_plisttool_on_mac_routes_validate_strings_to_mac_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_strings",
        target_mnemonic = "ValidateStrings",
        expected_control_dict = json.encode({
            "binary": False,
            "copy_input_on_success": True,
            "validate_strings": True,
        }),
        expected_execution_requirements = {"requires-darwin": ""},
        tags = [name],
    )

    # Aspect path (apple_resource_aspect on objc_library) in opt with
    # compile_strings_with_plisttool=True.
    _aspect_compile_strings_opt_plisttool_test(
        name = "{}_aspect_opt_compile_strings_with_plisttool_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:objc_lib_with_invalid_escape_strings",
        target_mnemonic = "CompileStrings",
        expected_control_dict = json.encode({
            "binary": True,
            "individual_plist": "*/invalid_escape.strings",
            "output": "*/objc_lib_with_invalid_escape_strings-intermediates/invalid_escape.strings",
            "validate_strings": True,
            "target": "//test/starlark_tests/targets_under_test/ios:objc_lib_with_invalid_escape_strings",
        }),
        unexpected_control_keys = [
            "copy_input_on_success",
            "use_swift_plisttool",
        ],
        expected_execution_requirements = {"requires-darwin": ""},
        tags = [name],
    )

    # Aspect path (apple_resource_aspect on objc_library) in non-opt with
    # validate_strings_with_plisttool=True.
    _aspect_validate_strings_non_opt_plisttool_test(
        name = "{}_aspect_non_opt_validate_strings_with_plisttool_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:objc_lib_with_invalid_escape_strings",
        target_mnemonic = "ValidateStrings",
        expected_control_dict = json.encode({
            "binary": False,
            "copy_input_on_success": True,
            "individual_plist": "*/invalid_escape.strings",
            "output": "*/objc_lib_with_invalid_escape_strings-intermediates/invalid_escape.strings",
            "validate_strings": True,
            "target": "//test/starlark_tests/targets_under_test/ios:objc_lib_with_invalid_escape_strings",
        }),
        unexpected_control_keys = ["use_swift_plisttool"],
        not_expected_execution_requirements = ["requires-darwin"],
        tags = [name],
    )

    # Top-level app depending on objc_library with strings in `data` bundles the aspect-validated
    # output in non-opt.
    _bundle_inputs_validate_non_opt_test(
        name = "{}_aspect_non_opt_output_bundled_in_app_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_invalid_escape_strings_in_lib",
        expected_input_suffixes = [
            "objc_lib_with_invalid_escape_strings-intermediates/invalid_escape.strings",
        ],
        unexpected_input_suffixes = [
            "targets_under_test/ios/invalid_escape.strings",
        ],
        tags = [name],
    )

    # Top-level app depending on objc_library with strings in `data` bundles the aspect-compiled
    # output in opt.
    _bundle_inputs_compile_opt_test(
        name = "{}_aspect_opt_output_bundled_in_app_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_invalid_escape_strings_in_lib",
        expected_input_suffixes = [
            "objc_lib_with_invalid_escape_strings-intermediates/invalid_escape.strings",
        ],
        unexpected_input_suffixes = [
            "targets_under_test/ios/invalid_escape.strings",
        ],
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
