# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""Starlark test rule to validate the zip file referenced from an output group."""

load(
    "@build_bazel_rules_apple//test/starlark_tests/rules:apple_verification_test.bzl",
    "apple_verification_transition",
)

def _output_group_zip_contents_test_impl(ctx):
    """Implementation of the output_group_zip_contents_test rule."""
    target_under_test = ctx.attr.target_under_test[0]

    if not OutputGroupInfo in target_under_test:
        fail(("Target %s does not provide OutputGroupInfo") % target_under_test.label)

    output_group = getattr(target_under_test[OutputGroupInfo], ctx.attr.output_group_name, None)
    if not output_group:
        fail("OutputGroupInfo does not have %s" % ctx.attr.output_group_name)

    output_group_files = output_group.to_list()
    output_group_file = ""
    for found_output_group_file in output_group_files:
        if found_output_group_file.short_path == ctx.attr.output_group_file_shortpath:
            output_group_file = found_output_group_file
    if not output_group_file:
        fail("{output_group_file_shortpath} not found; instead found {output_group_files}".format(
            output_group_file_shortpath = ctx.attr.output_group_file_shortpath,
            output_group_files = output_group_files,
        ))
    output_group_file_path = output_group_file.short_path

    test_lines = [
        "#!/bin/bash",
        "set -euo pipefail",
        "IFS=$'\n' ACTUAL_VALUES=($(unzip -Z1 {0} 2>/dev/null))".format(
            output_group_file_path,
        ),
    ]

    for value in ctx.attr.contains:
        test_lines.extend([
            "VALUE_FOUND=false",
            "for ACTUAL_VALUE in \"${ACTUAL_VALUES[@]}\"",
            "do",
            "  if [[ \"$ACTUAL_VALUE\" == \"{}\" ]]; then".format(value),
            "    VALUE_FOUND=true",
            "    break",
            "  fi",
            "done",
            "if [[ \"$VALUE_FOUND\" = false ]]; then",
            "  echo \"Expected file at \"{}\" was not found.\"".format(value),
            "  echo \"Actual files in the zip file were:\"",
            "  echo ${ACTUAL_VALUES[@]}",
            "  exit 1",
            "fi",
        ])

    test_script = ctx.actions.declare_file("{}_output_group_zip_test_script".format(ctx.label.name))
    ctx.actions.write(test_script, "\n".join(test_lines), is_executable = True)

    xcode_config = ctx.attr._xcode_config[apple_common.XcodeVersionConfig]

    return [
        testing.ExecutionInfo(xcode_config.execution_info()),
        testing.TestEnvironment(apple_common.apple_host_system_env(xcode_config)),
        DefaultInfo(
            executable = test_script,
            runfiles = ctx.runfiles(
                files = [output_group_file],
            ),
        ),
    ]

# Need a cfg for a transition on target_under_test, so can't use analysistest.make.
output_group_zip_contents_test = rule(
    _output_group_zip_contents_test_impl,
    attrs = {
        "build_type": attr.string(
            default = "simulator",
            doc = """
Type of build for the target under test. Possible values are `simulator` or `device`.
Defaults to `simulator`.
""",
            values = ["simulator", "device"],
        ),
        "compilation_mode": attr.string(
            default = "fastbuild",
            doc = """
Possible values are `fastbuild`, `dbg` or `opt`. Defaults to `fastbuild`.
https://docs.bazel.build/versions/master/user-manual.html#flag--compilation_mode
""",
            values = ["fastbuild", "opt", "dbg"],
        ),
        "target_under_test": attr.label(
            cfg = apple_verification_transition,
            doc = "Target containing a file from an output group to verify.",
            mandatory = True,
        ),
        "contains": attr.string_list(
            doc = "A list of paths expected to be found in the referenced archive.",
            mandatory = True,
        ),
        "output_group_name": attr.string(
            doc = "The name of the output group that has the archive file to verify.",
            mandatory = True,
        ),
        "output_group_file_shortpath": attr.string(
            doc = "A short path to the output group file that represents the archive to validate.",
            mandatory = True,
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
    fragments = ["apple"],
    test = True,
)
