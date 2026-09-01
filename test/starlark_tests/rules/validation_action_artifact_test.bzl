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

"""Test rules for validating validation action artifacts."""

load("@build_bazel_apple_support//lib:apple_support.bzl", "apple_support")
load(
    "@build_bazel_rules_apple//test/starlark_tests/rules:apple_verification_test.bzl",
    "apple_verification_transition",
)

visibility("//test/starlark_tests/...")

def _validation_output_contents_test_impl(ctx):
    """Implementation of validation_output_contents_test."""
    target = ctx.attr.target_under_test[0]
    if OutputGroupInfo not in target:
        fail("Target %s does not provide OutputGroupInfo" % target.label)

    validation_group = getattr(target[OutputGroupInfo], "_validation", None)
    if not validation_group:
        fail("Target %s does not have _validation in OutputGroupInfo" % target.label)

    validation_files = validation_group.to_list()
    target_filename = ctx.attr.validation_file_name
    matching_files_by_short_path = {}
    for f in validation_files:
        if f.basename == target_filename or f.short_path.endswith("/" + target_filename):
            matching_files_by_short_path[f.short_path] = f

    matching_files = matching_files_by_short_path.values()

    if not matching_files:
        fail("Could not find validation file '%s' in _validation outputs: %s" % (
            target_filename,
            [f.short_path for f in validation_files],
        ))
    if len(matching_files) > 1:
        fail("Target %s had multiple _validation outputs matching '%s': %s; use additional path segments to distinguish them." % (
            target.label,
            target_filename,
            [f.short_path for f in matching_files],
        ))

    matching_file = matching_files[0]

    env = {
        "VALIDATION_FILE": matching_file.short_path,
        "ALLOW_EMPTY": "true" if ctx.attr.allow_empty else "false",
    }

    env_lists = {
        "EXPECTED_CONTENTS": ctx.attr.expected_contents,
        "NOT_EXPECTED_CONTENTS": ctx.attr.not_expected_contents,
    }

    env["APPLE_TEST_ENV_KEYS"] = " ".join(env_lists.keys())
    for key, values in env_lists.items():
        for num, value in enumerate(values):
            env["APPLE_TEST_ENV_{}_{}".format(key, num)] = value

    output_script = ctx.actions.declare_file("{}_test_script".format(ctx.label.name))
    ctx.actions.symlink(
        output = output_script,
        target_file = ctx.file._verifier_script,
        is_executable = True,
    )

    runfiles_files = (
        [output_script, ctx.file._verifier_script, matching_file] +
        ctx.attr._test_deps.files.to_list()
    )

    return [
        testing.TestEnvironment(env),
        DefaultInfo(
            executable = output_script,
            runfiles = ctx.runfiles(
                files = runfiles_files,
            ),
        ),
    ]

validation_output_contents_test = rule(
    implementation = _validation_output_contents_test_impl,
    test = True,
    attrs = apple_support.action_required_attrs() | {
        "build_type": attr.string(
            default = "simulator",
            doc = "Type of build for the target under test. Possible values are `simulator` or `device`.",
            values = ["simulator", "device"],
        ),
        "compilation_mode": attr.string(
            default = "fastbuild",
            doc = "Possible values are `fastbuild`, `dbg` or `opt`. Defaults to `fastbuild`.",
            values = ["fastbuild", "opt", "dbg"],
        ),
        "allow_empty": attr.bool(
            default = False,
            doc = "Whether the validation file is allowed to be empty (e.g. for marker validation actions).",
        ),
        "expected_contents": attr.string_list(
            default = [],
            doc = "Strings expected to be present in the validation file.",
        ),
        "not_expected_contents": attr.string_list(
            default = [],
            doc = "Strings expected NOT to be present in the validation file.",
        ),
        "target_under_test": attr.label(
            cfg = apple_verification_transition,
            mandatory = True,
            doc = "Target providing OutputGroupInfo with _validation output group.",
        ),
        "validation_file_name": attr.string(
            mandatory = True,
            doc = "Filename or path suffix of the validation file in _validation to inspect.",
        ),
        "_test_deps": attr.label(
            default = Label("@build_bazel_rules_apple//test:apple_verification_test_deps"),
        ),
        "_verifier_script": attr.label(
            allow_single_file = True,
            default = Label("@build_bazel_rules_apple//test/starlark_tests:verifier_scripts/validation_output_contents_verifier.sh"),
        ),
    },
    doc = "Verifies that a validation action in _validation was executed and produced the expected content.",
)
