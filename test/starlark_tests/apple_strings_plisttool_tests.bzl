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

"""Starlark tests for plist, `.strings`, and `.stringsdict` processing via `plisttool`."""

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
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "archive_contents_test",
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

def _control_keys_sorted_test_impl(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    actions = [a for a in target_under_test.actions if a.mnemonic == ctx.attr.target_mnemonic]
    if not actions:
        analysistest.fail(env, "No action found with mnemonic {}".format(ctx.attr.target_mnemonic))
        return analysistest.end(env)

    json_str = actions[0].argv[-1]
    if json_str.startswith("'") and json_str.endswith("'"):
        json_str = json_str[1:-1].replace("'\\''", "'")

    actual_keys = list(json.decode(json_str).keys())
    if actual_keys != sorted(actual_keys):
        analysistest.fail(
            env,
            "Expected plisttool control JSON keys to be sorted, but got: {}".format(actual_keys),
        )
    return analysistest.end(env)

_compile_opt_default_plisttool_test = make_plisttool_action_test(
    config_settings = {
        "//command_line_option:compilation_mode": "opt",
    },
)

_compile_opt_no_encoder_plisttool_test = make_plisttool_action_test(
    config_settings = {
        build_settings_labels.use_property_list_encoder: False,
        "//command_line_option:compilation_mode": "opt",
    },
)

_validate_strings_non_opt_plisttool_test = make_plisttool_action_test(
    config_settings = {
        build_settings_labels.use_property_list_encoder: False,
        build_settings_labels.validate_strings_with_plisttool: True,
        "//command_line_option:compilation_mode": "fastbuild",
    },
)

_validate_strings_non_opt_property_list_encoder_test = make_plisttool_action_test(
    config_settings = {
        build_settings_labels.use_property_list_encoder: True,
        build_settings_labels.validate_strings_with_plisttool: True,
        "//command_line_option:compilation_mode": "fastbuild",
    },
)

_validate_strings_opt_plisttool_test = make_plisttool_action_test(
    config_settings = {
        build_settings_labels.use_property_list_encoder: False,
        build_settings_labels.validate_strings_with_plisttool: True,
        "//command_line_option:compilation_mode": "opt",
    },
)

_validate_strings_opt_property_list_encoder_test = make_plisttool_action_test(
    config_settings = {
        build_settings_labels.use_property_list_encoder: True,
        build_settings_labels.validate_strings_with_plisttool: True,
        "//command_line_option:compilation_mode": "opt",
    },
)

_aspect_compile_opt_default_plisttool_test = make_plisttool_action_test(
    config_settings = {
        "//command_line_option:compilation_mode": "opt",
        "//command_line_option:platforms": "//buildenv/platforms/apple:darwin_arm64",
    },
    extra_target_under_test_aspects = [apple_resource_aspect],
)

_aspect_compile_opt_no_encoder_plisttool_test = make_plisttool_action_test(
    config_settings = {
        build_settings_labels.use_property_list_encoder: False,
        "//command_line_option:compilation_mode": "opt",
        "//command_line_option:platforms": "//buildenv/platforms/apple:darwin_arm64",
    },
    extra_target_under_test_aspects = [apple_resource_aspect],
)

_aspect_validate_strings_opt_plisttool_test = make_plisttool_action_test(
    config_settings = {
        build_settings_labels.validate_strings_with_plisttool: True,
        "//command_line_option:compilation_mode": "opt",
        "//command_line_option:platforms": "//buildenv/platforms/apple:darwin_arm64",
    },
    extra_target_under_test_aspects = [apple_resource_aspect],
)

_aspect_validate_strings_non_opt_plisttool_test = make_plisttool_action_test(
    config_settings = {
        build_settings_labels.use_property_list_encoder: False,
        build_settings_labels.validate_strings_with_plisttool: True,
        "//command_line_option:compilation_mode": "fastbuild",
        "//command_line_option:platforms": "//buildenv/platforms/apple:darwin_arm64",
    },
    extra_target_under_test_aspects = [apple_resource_aspect],
)

_use_property_list_encoder_plisttool_test = make_plisttool_action_test(
    config_settings = {
        build_settings_labels.use_property_list_encoder: True,
    },
)

_use_property_list_encoder_control_keys_sorted_test = analysistest.make(
    _control_keys_sorted_test_impl,
    attrs = {
        "target_mnemonic": attr.string(mandatory = True),
    },
    config_settings = {
        build_settings_labels.use_property_list_encoder: True,
    },
)

_opt_control_keys_sorted_test = analysistest.make(
    _control_keys_sorted_test_impl,
    attrs = {
        "target_mnemonic": attr.string(mandatory = True),
    },
    config_settings = {
        "//command_line_option:compilation_mode": "opt",
    },
)

_aspect_use_property_list_encoder_plisttool_test = make_plisttool_action_test(
    config_settings = {
        build_settings_labels.use_property_list_encoder: True,
        "//command_line_option:platforms": "//buildenv/platforms/apple:darwin_arm64",
    },
    extra_target_under_test_aspects = [apple_resource_aspect],
)

_disable_property_list_encoder_plisttool_test = make_plisttool_action_test(
    config_settings = {
        build_settings_labels.use_property_list_encoder: False,
    },
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

_compile_opt_force_mac_plisttool_test = make_plisttool_action_test(
    config_settings = {
        build_settings_labels.force_plisttool_on_mac: True,
        "//command_line_option:compilation_mode": "opt",
    },
)

_flags_off_non_opt_actions_test = make_analysis_target_actions_test(
    config_settings = {
        build_settings_labels.validate_strings_with_plisttool: False,
        "//command_line_option:compilation_mode": "fastbuild",
        "//command_line_option:macos_cpus": "arm64",
    },
)

_flags_on_non_opt_actions_test = make_analysis_target_actions_test(
    config_settings = {
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
        "//command_line_option:compilation_mode": "opt",
    },
)

def apple_strings_plisttool_test_suite(name):
    """Test suite for plist and strings validation and compilation via plisttool.

    Args:
      name: the base name to be used in things created by this macro
    """

    # Default opt: .strings uses CompileStrings with plisttool on Linux without validation.
    _compile_opt_default_plisttool_test(
        name = "{}_opt_compile_strings_default_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_strings",
        target_mnemonic = "CompileStrings",
        expected_control_dict = json.encode({
            "binary": True,
            "individual_plist": "*/nonlocalized.strings",
            "output": "*/nonlocalized.strings",
            "use_property_list_encoder": True,
            "target": "//test/starlark_tests/targets_under_test/ios:app_with_top_level_strings",
        }),
        unexpected_control_keys = [
            "copy_input_on_success",
            "validate_strings",
        ],
        not_expected_execution_requirements = ["requires-darwin"],
        assert_output_bundled = True,
        tags = [name],
    )

    # Default opt: .stringsdict uses CompilePlist with plisttool on Linux without validation.
    _compile_opt_default_plisttool_test(
        name = "{}_opt_compile_stringsdict_default_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_stringsdict",
        target_mnemonic = "CompilePlist",
        expected_control_dict = json.encode({
            "binary": True,
            "individual_plist": "*/files.stringsdict",
            "output": "*/files.stringsdict",
            "use_property_list_encoder": True,
            "target": "//test/starlark_tests/targets_under_test/ios:app_with_top_level_stringsdict",
        }),
        unexpected_control_keys = [
            "copy_input_on_success",
            "validate_strings",
        ],
        not_expected_execution_requirements = ["requires-darwin"],
        assert_output_bundled = True,
        tags = [name],
    )

    # Default opt: resource .plist uses CompilePlist with plisttool on Linux.
    _compile_opt_default_plisttool_test(
        name = "{}_opt_compile_plist_default_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_plist",
        target_mnemonic = "CompilePlist",
        expected_control_dict = json.encode({
            "binary": True,
            "individual_plist": "*/nonlocalized.plist",
            "output": "*/nonlocalized.plist",
            "use_property_list_encoder": True,
            "target": "//test/starlark_tests/targets_under_test/ios:app_with_top_level_plist",
        }),
        unexpected_control_keys = [
            "copy_input_on_success",
            "validate_strings",
        ],
        not_expected_execution_requirements = ["requires-darwin"],
        assert_output_bundled = True,
        tags = [name],
    )

    # Default opt via apple_resource_aspect on objc_library: .strings uses CompileStrings on Linux
    # without validation, and resource .plist uses CompilePlist on Linux.
    _aspect_compile_opt_default_plisttool_test(
        name = "{}_aspect_opt_compile_strings_default_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:objc_lib_with_invalid_escape_strings",
        target_mnemonic = "CompileStrings",
        expected_control_dict = json.encode({
            "binary": True,
            "individual_plist": "*/invalid_escape.strings",
            "output": "*/objc_lib_with_invalid_escape_strings-intermediates/invalid_escape.strings",
            "use_property_list_encoder": True,
            "target": "//test/starlark_tests/targets_under_test/ios:objc_lib_with_invalid_escape_strings",
        }),
        unexpected_control_keys = [
            "copy_input_on_success",
            "validate_strings",
        ],
        not_expected_execution_requirements = ["requires-darwin"],
        tags = [name],
    )

    _aspect_compile_opt_default_plisttool_test(
        name = "{}_aspect_opt_compile_plist_default_action_test".format(name),
        target_under_test = "//test/starlark_tests/resources:another_plist_lib",
        target_mnemonic = "CompilePlist",
        expected_control_dict = json.encode({
            "binary": True,
            "individual_plist": "*/Another.plist",
            "output": "*/another_plist_lib-intermediates/Another.plist",
            "use_property_list_encoder": True,
            "target": "//test/starlark_tests/resources:another_plist_lib",
        }),
        unexpected_control_keys = [
            "copy_input_on_success",
            "validate_strings",
        ],
        not_expected_execution_requirements = ["requires-darwin"],
        tags = [name],
    )

    # Opt + use_property_list_encoder=False: omits use_property_list_encoder on CompileStrings,
    # .stringsdict CompilePlist, resource .plist CompilePlist, and aspect CompileStrings.
    _compile_opt_no_encoder_plisttool_test(
        name = "{}_opt_compile_strings_no_encoder_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_strings",
        target_mnemonic = "CompileStrings",
        expected_control_dict = json.encode({
            "binary": True,
            "individual_plist": "*/nonlocalized.strings",
            "output": "*/nonlocalized.strings",
            "target": "//test/starlark_tests/targets_under_test/ios:app_with_top_level_strings",
        }),
        unexpected_control_keys = [
            "copy_input_on_success",
            "use_property_list_encoder",
            "validate_strings",
        ],
        not_expected_execution_requirements = ["requires-darwin"],
        assert_output_bundled = True,
        tags = [name],
    )

    _compile_opt_no_encoder_plisttool_test(
        name = "{}_opt_compile_stringsdict_no_encoder_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_stringsdict",
        target_mnemonic = "CompilePlist",
        expected_control_dict = json.encode({
            "binary": True,
            "individual_plist": "*/files.stringsdict",
            "output": "*/files.stringsdict",
            "target": "//test/starlark_tests/targets_under_test/ios:app_with_top_level_stringsdict",
        }),
        unexpected_control_keys = [
            "copy_input_on_success",
            "use_property_list_encoder",
            "validate_strings",
        ],
        not_expected_execution_requirements = ["requires-darwin"],
        assert_output_bundled = True,
        tags = [name],
    )

    _compile_opt_no_encoder_plisttool_test(
        name = "{}_opt_compile_plist_no_encoder_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_plist",
        target_mnemonic = "CompilePlist",
        expected_control_dict = json.encode({
            "binary": True,
            "individual_plist": "*/nonlocalized.plist",
            "output": "*/nonlocalized.plist",
            "target": "//test/starlark_tests/targets_under_test/ios:app_with_top_level_plist",
        }),
        unexpected_control_keys = [
            "copy_input_on_success",
            "use_property_list_encoder",
            "validate_strings",
        ],
        not_expected_execution_requirements = ["requires-darwin"],
        assert_output_bundled = True,
        tags = [name],
    )

    _aspect_compile_opt_no_encoder_plisttool_test(
        name = "{}_aspect_opt_compile_strings_no_encoder_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:objc_lib_with_invalid_escape_strings",
        target_mnemonic = "CompileStrings",
        expected_control_dict = json.encode({
            "binary": True,
            "individual_plist": "*/invalid_escape.strings",
            "output": "*/objc_lib_with_invalid_escape_strings-intermediates/invalid_escape.strings",
            "target": "//test/starlark_tests/targets_under_test/ios:objc_lib_with_invalid_escape_strings",
        }),
        unexpected_control_keys = [
            "copy_input_on_success",
            "use_property_list_encoder",
            "validate_strings",
        ],
        not_expected_execution_requirements = ["requires-darwin"],
        tags = [name],
    )

    # Opt + validate_strings_with_plisttool=True: individual .strings, .stringsdict, .plist, and
    # aspect .strings do not enable validate_strings in opt builds (individual strings validation is
    # restricted to non-opt builds).
    _validate_strings_opt_property_list_encoder_test(
        name = "{}_opt_strings_not_validated_with_validate_strings_enabled_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_strings",
        target_mnemonic = "CompileStrings",
        expected_control_dict = json.encode({
            "binary": True,
            "individual_plist": "*/nonlocalized.strings",
            "output": "*/nonlocalized.strings",
            "use_property_list_encoder": True,
            "target": "//test/starlark_tests/targets_under_test/ios:app_with_top_level_strings",
        }),
        unexpected_control_keys = [
            "copy_input_on_success",
            "validate_strings",
        ],
        not_expected_execution_requirements = ["requires-darwin"],
        assert_output_bundled = True,
        tags = [name],
    )

    _validate_strings_opt_property_list_encoder_test(
        name = "{}_opt_stringsdict_not_validated_with_validate_strings_enabled_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_stringsdict",
        target_mnemonic = "CompilePlist",
        expected_control_dict = json.encode({
            "binary": True,
            "individual_plist": "*/files.stringsdict",
            "output": "*/files.stringsdict",
            "use_property_list_encoder": True,
            "target": "//test/starlark_tests/targets_under_test/ios:app_with_top_level_stringsdict",
        }),
        unexpected_control_keys = [
            "copy_input_on_success",
            "validate_strings",
        ],
        not_expected_execution_requirements = ["requires-darwin"],
        assert_output_bundled = True,
        tags = [name],
    )

    _validate_strings_opt_property_list_encoder_test(
        name = "{}_opt_plist_not_validated_with_validate_strings_enabled_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_plist",
        target_mnemonic = "CompilePlist",
        expected_control_dict = json.encode({
            "binary": True,
            "individual_plist": "*/nonlocalized.plist",
            "output": "*/nonlocalized.plist",
            "use_property_list_encoder": True,
            "target": "//test/starlark_tests/targets_under_test/ios:app_with_top_level_plist",
        }),
        unexpected_control_keys = [
            "copy_input_on_success",
            "validate_strings",
        ],
        not_expected_execution_requirements = ["requires-darwin"],
        assert_output_bundled = True,
        tags = [name],
    )

    _aspect_validate_strings_opt_plisttool_test(
        name = "{}_aspect_opt_strings_not_validated_with_validate_strings_enabled_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:objc_lib_with_invalid_escape_strings",
        target_mnemonic = "CompileStrings",
        expected_control_dict = json.encode({
            "binary": True,
            "individual_plist": "*/invalid_escape.strings",
            "output": "*/objc_lib_with_invalid_escape_strings-intermediates/invalid_escape.strings",
            "use_property_list_encoder": True,
            "target": "//test/starlark_tests/targets_under_test/ios:objc_lib_with_invalid_escape_strings",
        }),
        unexpected_control_keys = [
            "copy_input_on_success",
            "validate_strings",
        ],
        not_expected_execution_requirements = ["requires-darwin"],
        tags = [name],
    )

    _aspect_validate_strings_opt_plisttool_test(
        name = "{}_aspect_opt_plist_not_validated_with_validate_strings_enabled_action_test".format(name),
        target_under_test = "//test/starlark_tests/resources:another_plist_lib",
        target_mnemonic = "CompilePlist",
        expected_control_dict = json.encode({
            "binary": True,
            "individual_plist": "*/Another.plist",
            "output": "*/another_plist_lib-intermediates/Another.plist",
            "use_property_list_encoder": True,
            "target": "//test/starlark_tests/resources:another_plist_lib",
        }),
        unexpected_control_keys = [
            "copy_input_on_success",
            "validate_strings",
        ],
        not_expected_execution_requirements = ["requires-darwin"],
        tags = [name],
    )

    # Top-level plisttool control JSON keys are sorted for CompileStrings and CompilePlist in opt.
    _opt_control_keys_sorted_test(
        name = "{}_opt_compile_strings_sorted_keys_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_strings",
        target_mnemonic = "CompileStrings",
        tags = [name],
    )

    _opt_control_keys_sorted_test(
        name = "{}_opt_compile_plist_sorted_keys_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_plist",
        target_mnemonic = "CompilePlist",
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
        unexpected_control_keys = ["use_property_list_encoder"],
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
        unexpected_control_keys = ["use_property_list_encoder"],
        not_expected_execution_requirements = ["requires-darwin"],
        assert_output_bundled = True,
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

    # MergeStrings in non-opt with validate_strings_with_plisttool=True: binary output on Linux,
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
        unexpected_control_keys = ["use_property_list_encoder"],
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
        unexpected_control_keys = ["use_property_list_encoder"],
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

    # force_plisttool_on_mac=True routes non-opt ValidateStrings, opt CompileStrings, and opt
    # CompilePlist to the Mac.
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

    _compile_opt_force_mac_plisttool_test(
        name = "{}_force_plisttool_on_mac_routes_opt_compile_strings_to_mac_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_strings",
        target_mnemonic = "CompileStrings",
        expected_control_dict = json.encode({
            "binary": True,
            "individual_plist": "*/nonlocalized.strings",
            "output": "*/nonlocalized.strings",
            "use_property_list_encoder": True,
        }),
        expected_execution_requirements = {"requires-darwin": ""},
        tags = [name],
    )

    _compile_opt_force_mac_plisttool_test(
        name = "{}_force_plisttool_on_mac_routes_opt_compile_plist_to_mac_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_plist",
        target_mnemonic = "CompilePlist",
        expected_control_dict = json.encode({
            "binary": True,
            "individual_plist": "*/nonlocalized.plist",
            "output": "*/nonlocalized.plist",
            "use_property_list_encoder": True,
        }),
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
        unexpected_control_keys = ["use_property_list_encoder"],
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

    # use_property_list_encoder=True is omitted when binary=False (non-opt ValidateStrings).
    _validate_strings_non_opt_property_list_encoder_test(
        name = "{}_non_opt_validate_strings_omits_use_property_list_encoder_action_test".format(name),
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
        unexpected_control_keys = ["use_property_list_encoder"],
        not_expected_execution_requirements = ["requires-darwin"],
        assert_output_bundled = True,
        tags = [name],
    )

    # use_property_list_encoder=True injects use_property_list_encoder into CompileRootInfoPlist
    # (binary=True).
    _use_property_list_encoder_plisttool_test(
        name = "{}_root_infoplist_use_property_list_encoder_enabled_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app-with-hyphen",
        target_mnemonic = "CompileRootInfoPlist",
        expected_control_dict = json.encode({
            "binary": True,
            "use_property_list_encoder": True,
            "target": "//test/starlark_tests/targets_under_test/ios:app-with-hyphen",
        }),
        tags = [name],
    )

    # Injecting use_property_list_encoder keeps top-level plisttool control JSON keys sorted.
    _use_property_list_encoder_control_keys_sorted_test(
        name = "{}_root_infoplist_use_property_list_encoder_sorted_keys_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app-with-hyphen",
        target_mnemonic = "CompileRootInfoPlist",
        tags = [name],
    )

    # use_property_list_encoder=False omits use_property_list_encoder from CompileRootInfoPlist.
    _disable_property_list_encoder_plisttool_test(
        name = "{}_root_infoplist_use_property_list_encoder_disabled_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app-with-hyphen",
        target_mnemonic = "CompileRootInfoPlist",
        expected_control_dict = json.encode({
            "binary": True,
            "target": "//test/starlark_tests/targets_under_test/ios:app-with-hyphen",
        }),
        unexpected_control_keys = ["use_property_list_encoder"],
        tags = [name],
    )

    # use_property_list_encoder=True omits use_property_list_encoder from ProcessEntitlementsFiles
    # (binary omitted from control struct).
    _use_property_list_encoder_plisttool_test(
        name = "{}_entitlements_omits_use_property_list_encoder_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app-with-hyphen",
        target_mnemonic = "ProcessEntitlementsFiles",
        expected_control_dict = json.encode({
            "target": "//test/starlark_tests/targets_under_test/ios:app-with-hyphen",
        }),
        unexpected_control_keys = [
            "binary",
            "use_property_list_encoder",
        ],
        tags = [name],
    )

    # use_property_list_encoder=True omits use_property_list_encoder from
    # CreateXCFrameworkRootInfoPlist (binary=False).
    _use_property_list_encoder_plisttool_test(
        name = "{}_xcframework_root_infoplist_omits_use_property_list_encoder_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework",
        target_mnemonic = "CreateXCFrameworkRootInfoPlist",
        expected_control_dict = json.encode({
            "binary": False,
            "target": "//test/starlark_tests/targets_under_test/apple:ios_dynamic_xcframework",
        }),
        unexpected_control_keys = ["use_property_list_encoder"],
        tags = [name],
    )

    # use_property_list_encoder=True injects use_property_list_encoder into CompileInfoPlist
    # (merge_resource_infoplists on apple_resource_bundle, binary=True).
    _aspect_use_property_list_encoder_plisttool_test(
        name = "{}_resource_bundle_infoplist_use_property_list_encoder_enabled_action_test".format(name),
        target_under_test = "//test/starlark_tests/resources:bundle_library_ios",
        target_mnemonic = "CompileInfoPlist",
        expected_control_dict = json.encode({
            "binary": True,
            "output": "*/bundle_library_ios.bundle/Info.plist",
            "use_property_list_encoder": True,
        }),
        tags = [name],
    )

    # use_property_list_encoder=True omits use_property_list_encoder from ExtensionPointFormatXML
    # (extract_extension_points, binary=False).
    _use_property_list_encoder_plisttool_test(
        name = "{}_extension_point_xml_omits_use_property_list_encoder_action_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_enhanced_security_extension",
        target_mnemonic = "ExtensionPointFormatXML",
        expected_control_dict = json.encode({
            "binary": False,
            "output": "*/hinted_enhanced_security_extension_point.appexpt",
            "target": "//test/starlark_tests/targets_under_test/ios:app_with_enhanced_security_extension",
        }),
        unexpected_control_keys = ["use_property_list_encoder"],
        tags = [name],
    )

    # End-to-end execution tests in opt mode: Linux plisttool produces valid binary plists for
    # .strings, .stringsdict, resource .plist, and unvalidated invalid-escape .strings.
    archive_contents_test(
        name = "{}_opt_compiled_strings_archive_contents_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        is_binary_plist = [
            "$BUNDLE_ROOT/nonlocalized.strings",
        ],
        plist_test_file = "$BUNDLE_ROOT/nonlocalized.strings",
        plist_test_values = {
            "nonlocalized_string": "I'm the same in every language!",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_strings",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_opt_compiled_stringsdict_archive_contents_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        is_binary_plist = [
            "$BUNDLE_ROOT/en.lproj/files.stringsdict",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_stringsdict",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_opt_compiled_plist_archive_contents_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        is_binary_plist = [
            "$BUNDLE_ROOT/nonlocalized.plist",
        ],
        plist_test_file = "$BUNDLE_ROOT/nonlocalized.plist",
        plist_test_values = {
            "SomeKey": "Somevalue",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_top_level_plist",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_opt_compiled_array_root_plist_archive_contents_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        is_binary_plist = [
            "$BUNDLE_ROOT/array_root.plist",
        ],
        plist_test_file = "$BUNDLE_ROOT/array_root.plist",
        plist_test_values = {
            "0": "first_item",
            "1": "second_item",
        },
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_array_root_plist",
        tags = [name],
    )

    # With validate_strings_with_plisttool=False (default), malformed OpenStep \U escapes still
    # compile to a binary plist in opt mode (CoreFoundation decodes `\U` with no hex digits as
    # U+0000, so PlistBuddy truncates the C-string value when printing).
    archive_contents_test(
        name = "{}_opt_unvalidated_invalid_escape_strings_archive_contents_test".format(name),
        build_type = "device",
        compilation_mode = "opt",
        is_binary_plist = [
            "$BUNDLE_ROOT/invalid_escape.strings",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:app_with_invalid_escape_strings_in_lib",
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
