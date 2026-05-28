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

load(
    "//test/starlark_tests/rules:apple_coverage_test.bzl",
    "apple_coverage_test",
)

_COVERAGE_APP = "test/starlark_tests/targets_under_test/ios/CoverageApp.swift"
_COVERAGE_MAIN = "test/starlark_tests/targets_under_test/ios/CoverageMain.m"
_COVERAGE_SHARED_LOGIC = "test/starlark_tests/targets_under_test/ios/CoverageSharedLogic.m"
_COVERAGE_SHARED_SYMBOL = "CoverageSharedLogic.m:-[SharedLogic doSomething]"

def ios_coverage_test_suite(name):
    """Test suite for iOS coverage.

    Args:
      name: the base name to be used in things created by this macro
    """
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
