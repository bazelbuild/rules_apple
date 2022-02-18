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
    "@build_bazel_rules_apple//apple/internal:apple_product_type.bzl",
    "apple_product_type",
)  # buildifier: disable=bzl-visibility
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBinaryInfo",
    "AppleBundleInfo",
)
load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

def _apple_verification_transition_impl(settings, attr):
    """Implementation of the apple_verification_transition transition."""

    # This was added because this transition is also used by
    # `infoplist_contents_test` and has no "macos_cpus" attribute.
    macos_cpus = "x86_64"
    if hasattr(attr, "macos_cpus"):
        macos_cpus = ",".join(attr.macos_cpus)

    output_dictionary = {
        "//command_line_option:ios_signing_cert_name": "-",
        "//command_line_option:macos_cpus": macos_cpus,
        "//command_line_option:compilation_mode": attr.compilation_mode,
        "//command_line_option:apple_bitcode": attr.apple_bitcode,
        "//command_line_option:apple_generate_dsym": attr.apple_generate_dsym,
    }
    if attr.build_type == "simulator":
        output_dictionary.update({
            "//command_line_option:ios_multi_cpus": "x86_64",
            "//command_line_option:tvos_cpus": "x86_64",
            "//command_line_option:watchos_cpus": "i386",
        })
    else:
        output_dictionary.update({
            "//command_line_option:ios_multi_cpus": "arm64,armv7",
            "//command_line_option:tvos_cpus": "arm64",
            "//command_line_option:watchos_cpus": "armv7k",
        })
    existing_features = settings.get("//command_line_option:features") or []
    if hasattr(attr, "target_features"):
        existing_features.extend(attr.target_features)
    if hasattr(attr, "sanitizer") and attr.sanitizer != "none":
        existing_features.append(attr.sanitizer)
    output_dictionary["//command_line_option:features"] = existing_features
    return output_dictionary

apple_verification_transition = transition(
    implementation = _apple_verification_transition_impl,
    inputs = [
        "//command_line_option:features",
    ],
    outputs = [
        "//command_line_option:ios_signing_cert_name",
        "//command_line_option:ios_multi_cpus",
        "//command_line_option:macos_cpus",
        "//command_line_option:tvos_cpus",
        "//command_line_option:watchos_cpus",
        "//command_line_option:compilation_mode",
        "//command_line_option:features",
        "//command_line_option:apple_bitcode",
        "//command_line_option:apple_generate_dsym",
    ],
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
        ]:
            archive_relative_bundle = paths.join("Payload", bundle_with_extension)
        else:
            archive_relative_bundle = bundle_with_extension

        if bundle_info.platform_type == "macos":
            archive_relative_contents = paths.join(archive_relative_bundle, "Contents")
            archive_relative_binary = paths.join(
                archive_relative_contents,
                "MacOS",
                bundle_info.executable_name,
            )
            archive_relative_resources = paths.join(archive_relative_contents, "Resources")
        else:
            archive_relative_contents = archive_relative_bundle
            archive_relative_binary = paths.join(
                archive_relative_bundle,
                bundle_info.executable_name,
            )
            archive_relative_resources = archive_relative_bundle

        archive_short_path = archive.short_path
        output_to_verify = archive
        standalone_binary_short_path = ""
    elif AppleBinaryInfo in target_under_test:
        output_to_verify = target_under_test[AppleBinaryInfo].binary
        standalone_binary_short_path = target_under_test[AppleBinaryInfo].binary.short_path
        archive_short_path = ""
        archive_relative_binary = ""
        archive_relative_bundle = ""
        archive_relative_contents = ""
        archive_relative_resources = ""
    else:
        fail(("Target %s does not provide AppleBundleInfo or AppleBinaryInfo") %
             target_under_test.label)

    source_dependencies = ""
    for dep in ctx.attr._test_deps.files.to_list():
        source_dependencies += "source {}\n".format(dep.short_path)

    output_script = ctx.actions.declare_file("{}_test_script".format(ctx.label.name))
    ctx.actions.expand_template(
        template = ctx.file._runner_script,
        output = output_script,
        substitutions = {
            "%{archive}s": archive_short_path,
            "%{dependencies}s": source_dependencies,
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
        testing.TestEnvironment(dicts.add(
            apple_common.apple_host_system_env(xcode_config),
            test_env,
        )),
        DefaultInfo(
            executable = output_script,
            runfiles = ctx.runfiles(
                files = [output_to_verify, ctx.file.verifier_script] +
                        ctx.attr._test_deps.files.to_list(),
            ),
        ),
        target_under_test[OutputGroupInfo],
    ]

apple_verification_test = rule(
    implementation = _apple_verification_test_impl,
    attrs = {
        "apple_bitcode": attr.string(
            mandatory = False,
            default = "none",
            values = ["none", "embedded_markers", "embedded"],
            doc = """
The Bitcode mode to use for compilation steps. Possible values are `none`,
`embedded_markers`, or `embedded`. Defaults to `none`.
""",
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
        "apple_generate_dsym": attr.bool(
            default = False,
            doc = """
If true, generates .dSYM debug symbol bundles for the target(s) under test.
""",
        ),
        "macos_cpus": attr.string_list(
            doc = """
List of MacOS CPU's to use for test under target.
https://docs.bazel.build/versions/main/command-line-reference.html#flag--macos_cpus
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
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
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
