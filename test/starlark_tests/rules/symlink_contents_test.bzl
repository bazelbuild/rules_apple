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

"""Rules for testing symbolic links in archive or directory artifact outputs.

Since the contents of archives and directory artifacts are not known at analysis
time, this rule generates a shell script that inspects the output (extracting it
first if it is an archive) and verifies that each expected symlink exists and
points to the expected target.
"""

load(
    "@build_bazel_rules_apple//test/starlark_tests/rules:apple_verification_test.bzl",
    "apple_verification_transition",
)

visibility("//test/starlark_tests/...")

def _symlink_contents_test_impl(ctx):
    target_under_test = ctx.attr.target_under_test[0]
    output_file_suffix = ctx.attr.output_file

    if not ctx.attr.expected_symlinks:
        fail("expected_symlinks must not be empty.")

    matched_output = None
    for output in target_under_test[DefaultInfo].files.to_list():
        if output.short_path.endswith(output_file_suffix):
            if matched_output:
                fail(("Target {} had multiple outputs whose paths end in " +
                      "'{}'; use additional path segments to distinguish " +
                      "them.").format(
                    target_under_test.label,
                    output_file_suffix,
                ))
            matched_output = output

    if not matched_output:
        fail(("Target {} did not output a file or directory whose path ends " +
              "in '{}'.").format(target_under_test.label, output_file_suffix))

    output_short_path = matched_output.short_path
    generated_script = [
        "#!/usr/bin/env bash",
        "set -euo pipefail",
        "",
        "output_path=\"{}\"".format(output_short_path),
        "if [[ -d \"${output_path}\" ]]; then",
        "  root_dir=\"${output_path}\"",
        "else",
        "  root_dir=\"$(mktemp -d \"${TMPDIR:-/tmp}/symlink_test_dir.XXXXXX\")\"",
        "  trap 'rm -rf \"${root_dir}\"' ERR EXIT",
        "  unzip -qq \"${output_path}\" -d \"${root_dir}\"",
        "fi",
        "",
        "function check_symlink() {",
        "  local rel_path=\"$1\"",
        "  local expected_target=\"$2\"",
        "  local full_path=\"${root_dir}/${rel_path}\"",
        "  if [[ ! -L \"${full_path}\" ]]; then",
        "    if [[ -e \"${full_path}\" ]]; then",
        "      echo \"ERROR: Expected '${rel_path}' to be a symlink in " +
        "'${output_path}', but it is a regular file or directory.\"",
        "    else",
        "      echo \"ERROR: Expected symlink '${rel_path}' did not exist in " +
        "output '${output_path}'.\"",
        "    fi",
        "    return 1",
        "  fi",
        "  local actual_target",
        "  actual_target=\"$(readlink \"${full_path}\")\"",
        "  if [[ \"${actual_target}\" != \"${expected_target}\" && " +
        "\"${actual_target}\" != \"${expected_target}/\" ]]; then",
        "    echo \"ERROR: Expected symlink '${rel_path}' in '${output_path}' " +
        "to point to '${expected_target}', but it pointed to '${actual_target}'.\"",
        "    return 1",
        "  fi",
        "  if [[ ! -e \"${full_path}\" ]]; then",
        "    echo \"ERROR: Symlink '${rel_path}' in '${output_path}' points " +
        "to '${actual_target}', which does not exist.\"",
        "    return 1",
        "  fi",
        "  return 0",
        "}",
        "",
        "failed=0",
    ]
    for symlink_path, expected_target in ctx.attr.expected_symlinks.items():
        generated_script.append(
            "check_symlink \"{symlink_path}\" \"{expected_target}\" || failed=1".format(
                symlink_path = symlink_path,
                expected_target = expected_target,
            ),
        )

    generated_script.append("exit ${failed}")

    output_script = ctx.actions.declare_file(
        "{}_test_script".format(ctx.label.name),
    )
    ctx.actions.write(
        output = output_script,
        content = "\n".join(generated_script),
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = output_script,
            runfiles = ctx.runfiles(files = [matched_output]),
        ),
    ]

symlink_contents_test = rule(
    attrs = {
        "apple_generate_dsym": attr.bool(
            default = False,
            doc = """
If true, generates .dSYM debug symbol bundles for the target(s) under test.
""",
        ),
        "build_settings": attr.string_dict(
            mandatory = False,
            doc = "Build settings for target under test.",
        ),
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
        "expected_symlinks": attr.string_dict(
            mandatory = True,
            doc = """\
A dictionary where each key is the relative path of a symlink expected to exist
within the archive or directory output, and the corresponding value is the
expected target path that the symlink points to.
""",
        ),
        "output_file": attr.string(
            mandatory = True,
            doc = """\
The path suffix of an archive (such as `.zip` or `.ipa`) or directory (tree
artifact) output by the target under test to inspect.
""",
        ),
        "target_under_test": attr.label(
            cfg = apple_verification_transition,
            doc = "The target whose outputs are to be verified.",
            mandatory = True,
        ),
    },
    implementation = _symlink_contents_test_impl,
    test = True,
)
