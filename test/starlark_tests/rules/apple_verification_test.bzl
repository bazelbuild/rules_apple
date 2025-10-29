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

"""Test rule to perform generic bundle verification tests.

This rule is meant to be used only for rules_apple tests and are considered implementation details
that may change at any time. Please do not depend on this rule.
"""

load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBinaryInfo",
    "AppleBundleInfo",
)
load(
    "@build_bazel_rules_apple//apple/build_settings:build_settings.bzl",
    "build_settings_labels",
)
load(
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",  # buildifier: disable=bzl-visibility
    "apple_product_type",
)

visibility("//test/starlark_tests/...")

_CUSTOM_BUILD_SETTINGS = build_settings_labels.all_labels + [
]

_CPU_TO_PLATFORM = {
    "darwin_x86_64": "//buildenv/platforms/apple:darwin_x86_64",
    "darwin_arm64": "//buildenv/platforms/apple:darwin_arm64",
    "darwin_arm64e": "//buildenv/platforms/apple:darwin_arm64e",
    "ios_x86_64": "//buildenv/platforms/apple/simulator:ios_x86_64",
    "ios_arm64": "//buildenv/platforms/apple:ios_arm64",
    "ios_sim_arm64": "//buildenv/platforms/apple/simulator:ios_arm64",
    "ios_arm64e": "//buildenv/platforms/apple:ios_arm64e",
    "tvos_sim_arm64": "//buildenv/platforms/apple/simulator:tvos_arm64",
    "tvos_arm64": "//buildenv/platforms/apple:tvos_arm64",
    "tvos_x86_64": "//buildenv/platforms/apple/simulator:tvos_x86_64",
    "visionos_arm64": "//buildenv/platforms/apple:visionos_arm64",
    "visionos_sim_arm64": "//buildenv/platforms/apple/simulator:visionos_arm64",
    "watchos_armv7k": "//buildenv/platforms/apple:watchos_armv7k",
    "watchos_arm64": "//buildenv/platforms/apple/simulator:watchos_arm64",
    "watchos_device_arm64": "//buildenv/platforms/apple:watchos_arm64",
    "watchos_device_arm64e": "//buildenv/platforms/apple:watchos_arm64e",
    "watchos_arm64_32": "//buildenv/platforms/apple:watchos_arm64_32",
    "watchos_x86_64": "//buildenv/platforms/apple/simulator:watchos_x86_64",
}

def _apple_verification_transition_impl(settings, attr):
    """Implementation of the apple_verification_transition transition."""

    has_apple_platforms = True if getattr(attr, "apple_platforms", []) else False
    has_apple_cpus = True if getattr(attr, "cpus", {}) else False

    # Kept mutually exclusive as a preference to test new-style toolchain resolution separately from
    # old-style toolchain resolution.
    if has_apple_platforms and has_apple_cpus:
        fail("""
Internal Error: A verification test should only specify `apple_platforms` or `cpus`, but not both.
""")

    apple_cpu = getattr(attr, "apple_cpu", "darwin_x86_64")
    output_dictionary = {
        "//command_line_option:apple_platforms": [],
        "//command_line_option:platforms": _CPU_TO_PLATFORM[apple_cpu if apple_cpu else "darwin_x86_64"],
        "//command_line_option:macos_cpus": "x86_64",
        "//command_line_option:compilation_mode": attr.compilation_mode,
        "//command_line_option:apple_generate_dsym": getattr(attr, "apple_generate_dsym", "False"),
        "//command_line_option:incompatible_enable_apple_toolchain_resolution": has_apple_platforms,
    }
    if attr.build_type == "simulator":
        output_dictionary.update({
            "//command_line_option:ios_multi_cpus": "x86_64",
            "//command_line_option:tvos_cpus": "x86_64",
            "//command_line_option:watchos_cpus": "x86_64",
            "//command_line_option:visionos_cpus": "sim_arm64",
        })
    else:
        output_dictionary.update({
            "//command_line_option:ios_multi_cpus": "arm64,arm64e",
            "//command_line_option:tvos_cpus": "arm64",
            "//command_line_option:watchos_cpus": "device_arm64,arm64_32,armv7k",
            "//command_line_option:visionos_cpus": "arm64",
        })

    if has_apple_platforms:
        output_dictionary.update({
            "//command_line_option:apple_platforms": ",".join(attr.apple_platforms),
        })
    elif has_apple_cpus:
        for cpu_option, cpus in attr.cpus.items():
            command_line_option = "//command_line_option:%s" % cpu_option
            output_dictionary.update({command_line_option: ",".join(cpus)})

    # Features
    existing_features = settings.get("//command_line_option:features") or []
    if hasattr(attr, "target_features"):
        existing_features.extend(attr.target_features)
    if hasattr(attr, "sanitizer") and attr.sanitizer != "none":
        existing_features.append(attr.sanitizer)
    output_dictionary["//command_line_option:features"] = existing_features

    # Build settings
    test_build_settings = {
        build_settings_labels.signing_certificate_name: "-",
    }
    test_build_settings.update(getattr(attr, "build_settings", {}))
    for build_setting in _CUSTOM_BUILD_SETTINGS:
        if build_setting in test_build_settings:
            build_setting_value = test_build_settings[build_setting]
            build_setting_type = type(settings[build_setting])

            # The `build_settings` rule attribute requires string values. However, build
            # settings can have many types. In order to set the correct type, we inspect
            # the default value from settings, and cast accordingly.
            if build_setting_type == "bool":
                build_setting_value = build_setting_value.lower() in ("true", "yes", "1")

            output_dictionary[build_setting] = build_setting_value
        else:
            output_dictionary[build_setting] = settings[build_setting]

    return output_dictionary

apple_verification_transition = transition(
    implementation = _apple_verification_transition_impl,
    inputs = [
        "//command_line_option:features",
    ] + _CUSTOM_BUILD_SETTINGS,
    outputs = [
        "//command_line_option:platforms",
        "//command_line_option:ios_multi_cpus",
        "//command_line_option:macos_cpus",
        "//command_line_option:tvos_cpus",
        "//command_line_option:visionos_cpus",
        "//command_line_option:watchos_cpus",
        "//command_line_option:compilation_mode",
        "//command_line_option:features",
        "//command_line_option:apple_generate_dsym",
        "//command_line_option:apple_platforms",
        "//command_line_option:incompatible_enable_apple_toolchain_resolution",
    ] + _CUSTOM_BUILD_SETTINGS,
)

def _apple_verification_test_impl(ctx):
    """Implementation of the apple_verification_test rule."""

    # Should be using split_attr instead, but it has been disabled due to
    # https://github.com/bazelbuild/bazel/issues/8633
    target_under_test = ctx.attr.target_under_test[0]
    if AppleBundleInfo in target_under_test:
        bundle_info = target_under_test[AppleBundleInfo]
        archive = bundle_info.archive

        bundle_with_extension = bundle_info.bundle_name + bundle_info.bundle_extension

        if bundle_info.platform_type in [
            "ios",
            "tvos",
        ] and bundle_info.product_type in [
            apple_product_type.application,
            apple_product_type.app_clip,
            apple_product_type.messages_application,
        ] and not archive.is_directory:
            archive_relative_bundle = paths.join("Payload", bundle_with_extension)
        else:
            archive_relative_bundle = bundle_with_extension

        if bundle_info.platform_type == "macos":
            archive_relative_contents = paths.join(archive_relative_bundle, "Contents")
            archive_relative_binary = paths.join(
                archive_relative_contents,
                "MacOS",
                bundle_info.bundle_name,
            )
            archive_relative_resources = paths.join(archive_relative_contents, "Resources")
        else:
            archive_relative_contents = archive_relative_bundle
            archive_relative_binary = paths.join(archive_relative_bundle, bundle_info.bundle_name)
            archive_relative_resources = archive_relative_bundle

        archive_short_path = archive.short_path
        bundle_id = getattr(bundle_info, "bundle_id", None)
        output_to_verify = archive
        standalone_binary_short_path = ""
    elif AppleBinaryInfo in target_under_test:
        binary_info = target_under_test[AppleBinaryInfo]

        archive_short_path = ""
        archive_relative_binary = ""
        archive_relative_bundle = ""
        archive_relative_contents = ""
        archive_relative_resources = ""
        bundle_id = getattr(binary_info, "bundle_id", None)
        output_to_verify = binary_info.binary
        standalone_binary_short_path = binary_info.binary.short_path
    else:
        fail(("Target %s does not provide AppleBundleInfo or AppleBinaryInfo") %
             target_under_test.label)

    output_script = ctx.actions.declare_file("{}_test_script".format(ctx.label.name))
    ctx.actions.expand_template(
        template = ctx.file._runner_script,
        output = output_script,
        substitutions = {
            "%{archive}s": archive_short_path,
            "%{standalone_binary}s": standalone_binary_short_path,
            "%{archive_relative_binary}s": archive_relative_binary,
            "%{archive_relative_bundle}s": archive_relative_bundle,
            "%{archive_relative_contents}s": archive_relative_contents,
            "%{archive_relative_resources}s": archive_relative_resources,
            "%{verifier_script}s": ctx.file.verifier_script.short_path,
        },
        is_executable = True,
    )

    # Extra test environment to set during the test.
    test_env = {
        "BUILD_TYPE": ctx.attr.build_type,
        "BUNDLE_ID": bundle_id if bundle_id else "",
    }

    # Create APPLE_TEST_ENV_# environmental variables for each `env` attribute that are transformed
    # into bash arrays. This allows us to not need any extra sentinal/delimiter characters in the
    # values.
    test_env["APPLE_TEST_ENV_KEYS"] = " ".join(ctx.attr.env.keys())
    for key in ctx.attr.env:
        for num, value in enumerate(ctx.attr.env[key]):
            test_env["APPLE_TEST_ENV_{}_{}".format(key, num)] = value

    xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]

    return [
        testing.ExecutionInfo(xcode_config.execution_info()),
        testing.TestEnvironment(
            apple_common.apple_host_system_env(xcode_config) |
            test_env,
        ),
        DefaultInfo(
            executable = output_script,
            runfiles = ctx.runfiles(
                files = [output_to_verify, ctx.file.verifier_script] +
                        ctx.attr._test_deps.files.to_list(),
            ),
        ),
        target_under_test[OutputGroupInfo],
    ]

# Need a cfg for a transition on target_under_test, so can't use analysistest.make.
apple_verification_test = rule(
    implementation = _apple_verification_test_impl,
    attrs = {
        "apple_cpu": attr.string(
            doc = """
A string to indicate what should be the value of the Apple --cpu flag. Defaults to `darwin_x86_64`.
""",
        ),
        "apple_generate_dsym": attr.bool(
            default = False,
            doc = """
If true, generates .dSYM debug symbol bundles for the target(s) under test.
""",
        ),
        "apple_platforms": attr.string_list(
            doc = """
List of strings representing Apple platform definitions to resolve. When set, this opts into
toolchain resolution to select the Apple SDK for Apple rules (Starlark and native). Currently it is
considered to be an error if this is set with `cpus` as both opt into different means of toolchain
resolution.
""",
        ),
        "build_settings": attr.string_dict(
            mandatory = False,
            doc = "Build settings for target under test.",
        ),
        "build_type": attr.string(
            mandatory = True,
            values = ["simulator", "device"],
            doc = """
Type of build for the target under test. Possible values are `simulator` or `device`.
""",
        ),
        "compilation_mode": attr.string(
            values = ["fastbuild", "opt", "dbg"],
            doc = """
Possible values are `fastbuild`, `dbg` or `opt`. Defaults to `fastbuild`.
https://docs.bazel.build/versions/master/user-manual.html#flag--compilation_mode
""",
            default = "fastbuild",
        ),
        "cpus": attr.string_list_dict(
            doc = """
Dictionary of command line options cpu flags (e.g. ios_multi_cpus, macos_cpus) and the list of
cpu's to use for test under target (e.g. {'ios_multi_cpus': ['arm64', 'x86_64']}) Currently it is
considered to be an error if this is set with `apple_platforms` as both opt into different means of
toolchain resolution.
""",
        ),
        "sanitizer": attr.string(
            default = "none",
            values = ["none", "asan", "tsan", "ubsan"],
            doc = """
Possible values are `none`, `asan`, `tsan` or `ubsan`. Defaults to `none`.
Passes a sanitizer to the target under test.
""",
        ),
        "target_features": attr.string_list(
            mandatory = False,
            doc = """
List of additional features to build for the target under testing.
""",
        ),
        "target_under_test": attr.label(
            mandatory = True,
            providers = [[AppleBinaryInfo], [AppleBundleInfo]],
            doc = "The Apple binary or Apple bundle target whose contents are to be verified.",
            cfg = apple_verification_transition,
        ),
        "verifier_script": attr.label(
            mandatory = True,
            allow_single_file = [".sh"],
            doc = """
Shell script containing the verification code. This script can expect the following environment
variables to exist:

* ARCHIVE_ROOT: The path to the unzipped `.ipa` or `.zip` archive that was the output of the
  build.
* BINARY: The path to the main bundle binary.
* BUNDLE_ID: The bundle ID for the target under test.
* BUILD_TYPE: The type of build for the target under test. Can be `simulator` or `device`.
* BUNDLE_ROOT: The directory where the bundle is located.
* CONTENT_ROOT: The directory where the bundle contents are located.
* RESOURCE_ROOT: The directory where the resource files are located.
""",
        ),
        "env": attr.string_list_dict(
            doc = """
The environmental variables to pass to the verifier script. The list of strings will be transformed
into a bash array.
""",
        ),
        "_runner_script": attr.label(
            allow_single_file = True,
            default = "@build_bazel_rules_apple//test/starlark_tests:verifier_scripts/apple_verification_test_runner.sh.template",
        ),
        "_test_deps": attr.label(
            default = "@build_bazel_rules_apple//test:apple_verification_test_deps",
        ),
        "_xcode_config": attr.label(
            default = configuration_field(
                name = "xcode_config_label",
                fragment = "apple",
            ),
        ),
    },
    test = True,
    fragments = ["apple"],
)
