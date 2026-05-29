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

"""Starlark test rule for expected provisioning profile tool failures."""

load(
    "@bazel_skylib//lib:shell.bzl",
    "shell",
)

def _provisioning_profile_tool_error_test_impl(ctx):
    profile_metadata = "__PROFILE_METADATA__"
    control = {
        "profile_metadata": profile_metadata,
        "provisioning_profile": ctx.file.provisioning_profile.short_path,
        "target": ctx.attr.target_label,
    }

    output_script = ctx.actions.declare_file("{name}_test_script".format(
        name = ctx.label.name,
    ))
    ctx.actions.write(
        output = output_script,
        # buildifier: disable=canonical-repository
        content = """#!/usr/bin/env bash
set -euo pipefail

readonly CONTROL_JSON={control_json}
readonly CONTROL="$TEST_TMPDIR/control.json"
readonly EXPECTED_ERROR={expected_error}
readonly NORMALIZED_STDERR="$TEST_TMPDIR/provisioning_profile_tool.normalized.stderr"
readonly PROFILE_METADATA="$TEST_TMPDIR/profile_metadata.plist"
readonly STDERR="$TEST_TMPDIR/provisioning_profile_tool.stderr"
readonly STDOUT="$TEST_TMPDIR/provisioning_profile_tool.stdout"

printf '%s\\n' "${{CONTROL_JSON/{profile_metadata}/$PROFILE_METADATA}}" > "$CONTROL"

set +e
{provisioning_profile_tool} "$CONTROL" >"$STDOUT" 2>"$STDERR"
readonly STATUS=$?
set -e

if [[ "$STATUS" -eq 0 ]]; then
  echo "Expected provisioning_profile_tool to fail, but it succeeded."
  cat "$STDOUT"
  exit 1
fi

sed -E 's#@@[^/"]*//#//#g' "$STDERR" > "$NORMALIZED_STDERR"
if ! grep -F -- "$EXPECTED_ERROR" "$NORMALIZED_STDERR" >/dev/null; then
  echo "Expected provisioning_profile_tool stderr to contain:"
  echo "$EXPECTED_ERROR"
  echo
  echo "Actual stderr:"
  cat "$STDERR"
  exit 1
fi
""".format(
            control_json = shell.quote(json.encode(control)),
            expected_error = shell.quote(ctx.attr.expected_error),
            profile_metadata = profile_metadata,
            provisioning_profile_tool = shell.quote(ctx.executable._provisioning_profile_tool.short_path),
        ),
        is_executable = True,
    )

    runfiles = ctx.runfiles(
        files = [
            ctx.executable._provisioning_profile_tool,
            ctx.file.provisioning_profile,
        ],
    ).merge(ctx.attr._provisioning_profile_tool[DefaultInfo].default_runfiles)

    return [DefaultInfo(executable = output_script, runfiles = runfiles)]

provisioning_profile_tool_error_test = rule(
    implementation = _provisioning_profile_tool_error_test_impl,
    attrs = {
        "expected_error": attr.string(mandatory = True),
        "provisioning_profile": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
        "target_label": attr.string(mandatory = True),
        "_provisioning_profile_tool": attr.label(
            default = "//tools/provisioning_profile_tool:provisioning_profile_tool",
            executable = True,
            cfg = "exec",
        ),
    },
    test = True,
)
