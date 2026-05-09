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

"""Starlark test rules for versiontool."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@bazel_skylib//lib:shell.bzl", "shell")

def _write_build_info(ctx):
    build_info = ctx.actions.declare_file("{}_build_info".format(ctx.label.name))
    ctx.actions.write(
        output = build_info,
        content = "BUILD_EMBED_LABEL {}\n".format(ctx.attr.build_label),
    )
    return build_info

def _write_control(ctx, build_info):
    control = {
        "build_info_path": build_info.short_path,
        "build_label_pattern": ctx.attr.build_label_pattern,
        "build_version_pattern": ctx.attr.build_version,
        "capture_groups": ctx.attr.capture_groups,
        "short_version_string_pattern": ctx.attr.short_version_string,
    }

    if ctx.attr.fallback_build_label:
        control["fallback_build_label"] = ctx.attr.fallback_build_label

    control_file = ctx.actions.declare_file("{}_control.json".format(ctx.label.name))
    ctx.actions.write(
        output = control_file,
        content = json.encode(control),
    )
    return control_file

def _expect_value_check(key, value):
    return """if ! grep -F -- {expected} "$output" >/dev/null; then
  echo "ERROR: Expected versiontool output to contain {key}={value}."
  exit_code=1
fi
""".format(
        expected = shell.quote('"{}": "{}"'.format(key, value)),
        key = key,
        value = value,
    )

def _expect_no_value_check(key, value):
    return """if grep -F -- {not_expected} "$output" >/dev/null; then
  echo "ERROR: Expected versiontool output not to contain {key}={value}."
  exit_code=1
fi
""".format(
        not_expected = shell.quote('"{}": "{}"'.format(key, value)),
        key = key,
        value = value,
    )

def _versiontool_contents_test_impl(ctx):
    build_info = _write_build_info(ctx)
    control_file = _write_control(ctx, build_info)

    output_script = ctx.actions.declare_file("{}_test_script".format(ctx.label.name))
    ctx.actions.write(
        output = output_script,
        content = """#!/usr/bin/env bash
set -euo pipefail

readonly control={control}
readonly output="$TEST_TMPDIR/versiontool_output.json"

{versiontool} "$control" "$output"

exit_code=0
{expected_checks}
{not_expected_checks}
if [[ "$exit_code" -eq 1 ]]; then
  echo "Actual versiontool output was:"
  cat "$output"
fi

exit "$exit_code"
""".format(
            control = shell.quote(control_file.short_path),
            expected_checks = "\n".join([
                _expect_value_check(key, value)
                for key, value in ctx.attr.expected_values.items()
            ]),
            not_expected_checks = "\n".join([
                _expect_no_value_check(key, value)
                for key, value in ctx.attr.not_expected_values.items()
            ]),
            versiontool = shell.quote(ctx.executable._versiontool.short_path),
        ),
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = output_script,
            runfiles = ctx.runfiles(
                files = [
                    build_info,
                    control_file,
                    ctx.executable._versiontool,
                ],
            ).merge(ctx.attr._versiontool[DefaultInfo].default_runfiles),
        ),
    ]

def _versiontool_error_test_impl(ctx):
    build_info = _write_build_info(ctx)
    control_file = _write_control(ctx, build_info)

    output_script = ctx.actions.declare_file("{}_test_script".format(ctx.label.name))
    ctx.actions.write(
        output = output_script,
        content = """#!/usr/bin/env bash
set -euo pipefail

readonly control={control}
readonly expected_error={expected_error}
readonly output="$TEST_TMPDIR/versiontool_output.json"
readonly stderr="$TEST_TMPDIR/versiontool.stderr"
readonly stdout="$TEST_TMPDIR/versiontool.stdout"

set +e
{versiontool} "$control" "$output" >"$stdout" 2>"$stderr"
readonly status=$?
set -e

if [[ "$status" -eq 0 ]]; then
  echo "Expected versiontool to fail, but it succeeded."
  cat "$stdout"
  exit 1
fi

if ! grep -F -- "$expected_error" "$stderr" >/dev/null; then
  echo "Expected versiontool stderr to contain:"
  echo "$expected_error"
  echo
  echo "Actual stderr:"
  cat "$stderr"
  exit 1
fi
""".format(
            control = shell.quote(control_file.short_path),
            expected_error = shell.quote(ctx.attr.expected_error),
            versiontool = shell.quote(ctx.executable._versiontool.short_path),
        ),
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = output_script,
            runfiles = ctx.runfiles(
                files = [
                    build_info,
                    control_file,
                    ctx.executable._versiontool,
                ],
            ).merge(ctx.attr._versiontool[DefaultInfo].default_runfiles),
        ),
    ]

_VERSIONTOOL_TEST_ATTRS = {
    "build_label": attr.string(mandatory = True),
    "build_label_pattern": attr.string(mandatory = True),
    "build_version": attr.string(mandatory = True),
    "capture_groups": attr.string_dict(mandatory = True),
    "fallback_build_label": attr.string(),
    "short_version_string": attr.string(),
    "_versiontool": attr.label(
        default = "//tools/versiontool:versiontool",
        executable = True,
        cfg = "exec",
    ),
}

versiontool_contents_test = rule(
    implementation = _versiontool_contents_test_impl,
    attrs = dicts.add(
        _VERSIONTOOL_TEST_ATTRS,
        {
            "expected_values": attr.string_dict(mandatory = True),
            "not_expected_values": attr.string_dict(),
        },
    ),
    test = True,
)

versiontool_error_test = rule(
    implementation = _versiontool_error_test_impl,
    attrs = dicts.add(
        _VERSIONTOOL_TEST_ATTRS,
        {
            "expected_error": attr.string(mandatory = True),
        },
    ),
    test = True,
)
