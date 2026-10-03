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

"""iOS coverage Starlark tests."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load(
    "//test/starlark_tests/rules:apple_coverage_test.bzl",
    "apple_coverage_test",
)

_COVERAGE_APP = "test/starlark_tests/targets_under_test/ios/CoverageApp.swift"
_COVERAGE_MAIN = "test/starlark_tests/targets_under_test/ios/CoverageMain.m"
_COVERAGE_SHARED_LOGIC = "test/starlark_tests/targets_under_test/ios/CoverageSharedLogic.m"
_COVERAGE_SHARED_SYMBOL = "CoverageSharedLogic.m:-[SharedLogic doSomething]"

def _covered_binaries_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    execution_environment = target[RunEnvironmentInfo].environment
    asserts.equals(env, "1" if ctx.attr.expect_lcov else None, execution_environment.get("APPLE_COVERAGE"))
    binaries = execution_environment.get("TEST_BINARIES_FOR_LLVM_COV")
    if ctx.attr.expect_binaries:
        asserts.true(env, binaries != None, "Covered binaries must be exported")
        if binaries:
            binary_paths = binaries.split(";")

            # Hosted tests must export both the test binary and its host binary.
            asserts.equals(env, 2, len(binary_paths))
            runfiles = [f.short_path for f in target[DefaultInfo].default_runfiles.files.to_list()]
            for binary in binary_paths:
                asserts.true(env, binary in runfiles, "Missing covered binary in runfiles: " + binary)
    else:
        asserts.equals(env, None, binaries)
    return analysistest.end(env)

_covered_binaries_test = analysistest.make(
    _covered_binaries_test_impl,
    attrs = {
        "expect_binaries": attr.bool(),
        "expect_lcov": attr.bool(),
    },
    config_settings = {"//command_line_option:collect_code_coverage": True},
)

_covered_binaries_without_instrumentation_test = analysistest.make(
    _covered_binaries_test_impl,
    attrs = {
        "expect_binaries": attr.bool(),
        "expect_lcov": attr.bool(),
    },
    config_settings = {"//command_line_option:collect_code_coverage": False},
)

def ios_coverage_test_suite(name):
    """Test suite for iOS coverage.

    Args:
      name: the base name to be used in things created by this macro
    """
    for suffix, fixture, expect_binaries, expect_lcov in [
        ("export_only", "coverage_export_only_test", True, False),
        ("export_disabled", "coverage_export_disabled_test", False, False),
        ("default_lcov", "coverage_hosted_test", True, True),
        ("export_with_lcov", "coverage_export_with_lcov_test", True, True),
    ]:
        _covered_binaries_test(
            name = "{}_{}_environment_test".format(name, suffix),
            target_under_test = "//test/starlark_tests/targets_under_test/ios:" + fixture,
            expect_binaries = expect_binaries,
            expect_lcov = expect_lcov,
            tags = [name],
        )

    _covered_binaries_without_instrumentation_test(
        name = "{}_export_without_instrumentation_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/ios:coverage_export_only_test",
        tags = [name],
    )

    apple_coverage_test(
        name = "{}_standalone_unit_test_coverage".format(name),
        coverage_manifest = [_COVERAGE_SHARED_LOGIC],
        expected_coverage = [_COVERAGE_SHARED_SYMBOL],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:coverage_standalone_test",
        tags = [name],
    )

    apple_coverage_test(
        name = "{}_standalone_unit_test_coverage_new_runner".format(name),
        coverage_manifest = [_COVERAGE_SHARED_LOGIC],
        expected_coverage = [_COVERAGE_SHARED_SYMBOL],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:coverage_standalone_test_new_runner",
        tags = [name, "exclusive"],
    )

    apple_coverage_test(
        name = "{}_standalone_unit_test_coverage_json".format(name),
        coverage_manifest = [_COVERAGE_SHARED_LOGIC],
        expected_json = [
            "\"name\":\"{}\"".format(_COVERAGE_SHARED_SYMBOL),
        ],
        produce_json = True,
        target_under_test = "//test/starlark_tests/targets_under_test/ios:coverage_standalone_test",
        tags = [name],
    )

    apple_coverage_test(
        name = "{}_standalone_unit_test_coverage_manifest".format(name),
        coverage_manifest = [_COVERAGE_SHARED_LOGIC],
        expected_coverage = [_COVERAGE_SHARED_SYMBOL],
        expected_source_files = [_COVERAGE_SHARED_LOGIC],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:coverage_manifest_test",
        tags = [name],
    )

    apple_coverage_test(
        name = "{}_standalone_unit_test_coverage_manifest_new_runner".format(name),
        coverage_manifest = [_COVERAGE_SHARED_LOGIC],
        expected_coverage = [_COVERAGE_SHARED_SYMBOL],
        expected_source_files = [_COVERAGE_SHARED_LOGIC],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:coverage_manifest_test_new_runner",
        tags = [name],
    )

    apple_coverage_test(
        name = "{}_hosted_unit_test_coverage".format(name),
        coverage_manifest = [
            _COVERAGE_MAIN,
            _COVERAGE_SHARED_LOGIC,
        ],
        expected_coverage = [
            _COVERAGE_SHARED_SYMBOL,
            # Validate coverage for the hosting binary is included.
            ",coverageFoo",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:coverage_hosted_test",
        tags = [name, "exclusive"],
    )

    apple_coverage_test(
        name = "{}_ui_test_coverage_new_runner".format(name),
        coverage_manifest = [_COVERAGE_APP],
        expected_coverage = [
            "CoverageApp.swift",
            "DA:5,1",
        ],
        target_under_test = "//test/starlark_tests/targets_under_test/ios:coverage_ui_test_new_runner",
        tags = [name, "exclusive"],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
