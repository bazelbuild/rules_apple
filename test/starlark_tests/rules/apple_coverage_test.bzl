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

"""Test rule for running Apple tests under Bazel coverage settings."""

load("@bazel_skylib//lib:shell.bzl", "shell")
load(
    "//apple/build_settings:build_settings.bzl",
    "build_settings_labels",
)

def _ios_coverage_transition_impl(settings, attr):
    build_settings = {
        build_settings_labels.signing_certificate_name: "-",
    }

    features = list(settings.get("//command_line_option:features") or [])
    features.extend([
        "llvm_coverage_map_format",
        "-gcc_coverage_map_format",
    ])

    output = {
        "//command_line_option:collect_code_coverage": True,
        "//command_line_option:features": features,
        "//command_line_option:ios_simulator_device": attr.ios_simulator_device,
        "//command_line_option:instrumentation_filter": attr.instrumentation_filter,
    }

    for build_setting in build_settings_labels.all_labels:
        output[build_setting] = build_settings.get(build_setting, settings[build_setting])

    return output

_ios_coverage_transition = transition(
    implementation = _ios_coverage_transition_impl,
    inputs = [
        "//command_line_option:features",
    ] + build_settings_labels.all_labels,
    outputs = [
        "//command_line_option:collect_code_coverage",
        "//command_line_option:features",
        "//command_line_option:ios_simulator_device",
        "//command_line_option:instrumentation_filter",
    ] + build_settings_labels.all_labels,
)

def _write_lines(ctx, suffix, values):
    output = ctx.actions.declare_file("%s_%s" % (ctx.label.name, suffix))
    ctx.actions.write(
        output = output,
        content = "\n".join(values) + ("\n" if values else ""),
    )
    return output

def local_test_1(_os, _input_size):
    return {"local_test": 1}

def _apple_coverage_test_impl(ctx):
    target_under_test = ctx.attr.target_under_test[0]
    target_default_info = target_under_test[DefaultInfo]
    target_executable = target_default_info.files_to_run.executable

    if RunEnvironmentInfo not in target_under_test:
        fail("Target under test does not provide RunEnvironmentInfo: %s" % target_under_test.label)

    run_environment = target_under_test[RunEnvironmentInfo]
    coverage_env = []
    for key, value in sorted(run_environment.environment.items()):
        coverage_env.append("%s=%s" % (key, value))

    coverage_env_file = _write_lines(ctx, "coverage_env", coverage_env)
    coverage_manifest = _write_lines(ctx, "coverage_manifest", ctx.attr.coverage_manifest)
    expected_coverage_file = _write_lines(ctx, "expected_coverage", ctx.attr.expected_coverage)
    expected_json_file = _write_lines(ctx, "expected_json", ctx.attr.expected_json)
    expected_source_files = _write_lines(
        ctx,
        "expected_source_files",
        ctx.attr.expected_source_files,
    )

    script = ctx.actions.declare_file("%s_test_script" % ctx.label.name)

    ctx.actions.expand_template(
        template = ctx.file._runner_script,
        output = script,
        substitutions = {
            "%{coverage_env_file}s": shell.quote(coverage_env_file.short_path),
            "%{coverage_manifest}s": shell.quote(coverage_manifest.short_path),
            "%{expected_coverage_file}s": shell.quote(expected_coverage_file.short_path),
            "%{expected_json_file}s": shell.quote(expected_json_file.short_path),
            "%{expected_source_files}s": shell.quote(expected_source_files.short_path),
            "%{produce_json}s": shell.quote("1" if ctx.attr.produce_json else "0"),
            "%{test_executable}s": shell.quote(target_executable.short_path),
        },
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [
        coverage_env_file,
        expected_coverage_file,
        expected_json_file,
        expected_source_files,
        coverage_manifest,
        target_executable,
    ])
    runfiles = runfiles.merge(target_default_info.default_runfiles)

    return [
        DefaultInfo(
            executable = script,
            runfiles = runfiles,
        ),
        testing.ExecutionInfo({"requires-darwin": ""}),
    ]

apple_coverage_test = rule(
    implementation = _apple_coverage_test_impl,
    attrs = {
        "coverage_manifest": attr.string_list(
            mandatory = True,
            doc = "Repo-relative source paths to pass to llvm-cov.",
        ),
        "expected_coverage": attr.string_list(
            doc = "Literal strings expected in coverage.dat.",
        ),
        "expected_json": attr.string_list(
            doc = "Literal strings expected in coverage.json.",
        ),
        "expected_source_files": attr.string_list(
            doc = "Exact repo-relative SF entries expected in coverage.dat.",
        ),
        "instrumentation_filter": attr.string(
            default = "//test/starlark_tests/targets_under_test/ios[/:]",
            doc = "Instrumentation filter to apply to the target under test.",
        ),
        "ios_simulator_device": attr.string(
            default = "iPhone 16",
            doc = "Simulator device to bake into the generated iOS test runner.",
        ),
        "produce_json": attr.bool(
            default = False,
            doc = "Whether to request JSON coverage output from the Apple test runner.",
        ),
        "target_under_test": attr.label(
            cfg = _ios_coverage_transition,
            executable = True,
            mandatory = True,
            doc = "Apple test target to run under coverage settings.",
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
        "_runner_script": attr.label(
            default = ":apple_coverage_test_runner.sh",
            allow_single_file = True,
        ),
    },
    test = True,
)
