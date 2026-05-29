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

"""Starlark test rule for expected plisttool failures."""

load(
    "@bazel_skylib//lib:shell.bzl",
    "shell",
)
load(
    "//apple:providers.bzl",
    "AppleBundleInfo",
)
load(
    "//test/starlark_tests/rules:apple_verification_test.bzl",
    "apple_verification_transition",
)

def _normalized_label(label):
    label = str(label)
    if label.startswith("@"):
        return "//" + label.split("//", 1)[1]
    return label

def _plisttool_error_test_impl(ctx):
    input_plists = ctx.files.plists
    child_infoplists = []
    child_plists = {}
    child_labels = {}
    for child in ctx.attr.child_bundles:
        infoplist = child[AppleBundleInfo].infoplist
        label = str(child.label)
        child_infoplists.append(infoplist)
        child_plists[label] = infoplist.short_path
        child_labels[_normalized_label(child.label)] = label

    info_plist_options = {}
    if ctx.attr.version_keys_required:
        info_plist_options["version_keys_required"] = True
    if child_plists:
        info_plist_options["child_plists"] = child_plists
    if ctx.attr.child_plist_required_values:
        required_values = {}
        for child_label, values in ctx.attr.child_plist_required_values.items():
            canonical_child_label = child_labels.get(child_label)
            if not canonical_child_label:
                fail("{} must be listed in child_bundles".format(child_label))

            parsed_values = []
            for value in values:
                parts = value.split("=", 1)
                if len(parts) != 2:
                    fail(
                        "child_plist_required_values entries must be in the form " +
                        "`key:path=value`, got {}".format(value),
                    )
                parsed_values.append([parts[0].split(":"), parts[1]])
            required_values[canonical_child_label] = parsed_values
        info_plist_options["child_plist_required_values"] = required_values

    plists = [plist.short_path for plist in input_plists]
    if ctx.attr.plist_values:
        plists.append(ctx.attr.plist_values)

    control = {
        "binary": False,
        "forced_plists": [],
        "info_plist_options": info_plist_options,
        "output": "__OUTPUT__",
        "plists": plists,
        "target": ctx.attr.target_label,
        "variable_substitutions": ctx.attr.variable_substitutions,
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
readonly NORMALIZED_STDERR="$TEST_TMPDIR/plisttool.normalized.stderr"
readonly OUTPUT_PLIST="$TEST_TMPDIR/plisttool_output.plist"
readonly STDERR="$TEST_TMPDIR/plisttool.stderr"
readonly STDOUT="$TEST_TMPDIR/plisttool.stdout"

printf '%s\\n' "${{CONTROL_JSON/__OUTPUT__/$OUTPUT_PLIST}}" > "$CONTROL"

set +e
{plisttool} "$CONTROL" >"$STDOUT" 2>"$STDERR"
readonly STATUS=$?
set -e

if [[ "$STATUS" -eq 0 ]]; then
  echo "Expected plisttool to fail, but it succeeded."
  cat "$STDOUT"
  exit 1
fi

sed -E 's#@@[^/"]*//#//#g' "$STDERR" > "$NORMALIZED_STDERR"
if ! grep -F -- "$EXPECTED_ERROR" "$NORMALIZED_STDERR" >/dev/null; then
  echo "Expected plisttool stderr to contain:"
  echo "$EXPECTED_ERROR"
  echo
  echo "Actual stderr:"
  cat "$STDERR"
  exit 1
fi
""".format(
            control_json = shell.quote(json.encode(control)),
            expected_error = shell.quote(ctx.attr.expected_error),
            plisttool = shell.quote(ctx.executable._plisttool.short_path),
        ),
        is_executable = True,
    )

    runfiles = ctx.runfiles(
        files = [ctx.executable._plisttool] +
                input_plists + child_infoplists,
    ).merge(ctx.attr._plisttool[DefaultInfo].default_runfiles)

    return [DefaultInfo(executable = output_script, runfiles = runfiles)]

plisttool_error_test = rule(
    implementation = _plisttool_error_test_impl,
    attrs = {
        "child_bundles": attr.label_list(
            cfg = apple_verification_transition,
            providers = [[AppleBundleInfo]],
        ),
        "child_plist_required_values": attr.string_list_dict(
            doc = """
Mapping of child bundle labels to required child plist values. Values are encoded as
`Key:Path=ExpectedValue`.
""",
        ),
        "build_type": attr.string(
            default = "simulator",
            values = ["simulator", "device"],
        ),
        "compilation_mode": attr.string(
            default = "fastbuild",
            values = ["fastbuild", "opt", "dbg"],
        ),
        "expected_error": attr.string(
            mandatory = True,
        ),
        "plists": attr.label_list(
            allow_files = [".plist"],
            mandatory = True,
        ),
        "plist_values": attr.string_dict(),
        "target_label": attr.string(mandatory = True),
        "variable_substitutions": attr.string_dict(),
        "version_keys_required": attr.bool(),
        "_plisttool": attr.label(
            default = "//tools/plisttool:plisttool",
            executable = True,
            cfg = "exec",
        ),
    },
    test = True,
)
