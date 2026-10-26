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

"""Starlark test rule for the coverage environment and runfiles of Apple test rules."""

load(
    "@bazel_skylib//lib:unittest.bzl",
    "analysistest",
    "asserts",
    "unittest",
)

visibility("//test/starlark_tests/...")

_TEST_BINARIES_KEY = "TEST_BINARIES_FOR_LLVM_COV"

def _apple_test_coverage_test_impl(ctx):
    """Checks the coverage environment and runfiles of an Apple test target."""
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)

    test_environment = target_under_test[RunEnvironmentInfo].environment
    if _TEST_BINARIES_KEY not in test_environment:
        unittest.fail(env, "Expected \"{}\" in the test environment, instead found:\n{}".format(
            _TEST_BINARIES_KEY,
            "\n".join(sorted(test_environment.keys())),
        ))
        return analysistest.end(env)

    # The order of the binaries is not significant to `collect_coverage.sh`.
    covered_binaries = sorted(test_environment[_TEST_BINARIES_KEY].split(";"))
    asserts.equals(
        env,
        sorted(ctx.attr.expected_covered_binaries),
        covered_binaries,
        "Unexpected \"{}\" value.".format(_TEST_BINARIES_KEY),
    )

    for key in ctx.attr.not_expected_env_keys:
        if key in test_environment:
            unittest.fail(env, "\"{}\" was unexpectedly found in the test environment.".format(key))

    runfiles = [
        f.short_path
        for f in target_under_test[DefaultInfo].default_runfiles.files.to_list()
    ]

    # `collect_coverage.sh` resolves each covered binary relative to the runfiles directory.
    for covered_binary in covered_binaries:
        if covered_binary not in runfiles:
            unittest.fail(env, "Covered binary \"{}\" not in the test's runfiles.".format(
                covered_binary,
            ))

    for not_expected_runfile in ctx.attr.not_expected_runfiles:
        if not_expected_runfile in runfiles:
            unittest.fail(env, "\"{}\" was unexpectedly found in the test's runfiles.".format(
                not_expected_runfile,
            ))

    return analysistest.end(env)

apple_test_coverage_test = analysistest.make(
    _apple_test_coverage_test_impl,
    attrs = {
        "expected_covered_binaries": attr.string_list(
            mandatory = True,
            doc = """
The short paths of the binaries expected in `TEST_BINARIES_FOR_LLVM_COV`, in any order. Each one is
also expected to be in the test's runfiles.
""",
        ),
        "not_expected_env_keys": attr.string_list(
            doc = "Environment variables that must not be set on the test action.",
        ),
        "not_expected_runfiles": attr.string_list(
            doc = "The short paths of files that must not be in the test's runfiles.",
        ),
    },
    config_settings = {
        "//command_line_option:collect_code_coverage": True,
    },
)
