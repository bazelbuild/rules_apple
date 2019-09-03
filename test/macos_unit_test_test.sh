#!/bin/bash

# Copyright 2017 The Bazel Authors. All rights reserved.
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

# Integration tests for bundling simple macOS Unit tests.

set -eu

function set_up() {
  mkdir -p app
}

function tear_down() {
  rm -rf app
}

# Creates common source, targets, and basic plist for macOS applications and
# tests.
function create_common_files() {
  cat > app/BUILD <<EOF
load(
    "@build_bazel_rules_apple//apple:macos.bzl",
    "macos_application",
    "macos_unit_test",
)

objc_library(
    name = "lib",
    srcs = ["main.m"],
)

objc_library(
    name = "unit_test_lib",
    srcs = ["UnitTest.m"],
)
EOF

  cat > app/main.m <<EOF
int main(int argc, char **argv) {
  return 0;
}
EOF

  cat > app/UnitTest.m <<EOF
#import <XCTest/XCTest.h>
@interface UnitTest: XCTestCase
@end

@implementation UnitTest
- (void)testAssertNil { XCTAssertNil(nil); }
@end
EOF

  cat > app/Info.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
}
EOF
}

# Usage: create_minimal_macos_application_with_tests [test_bundle_id]
#
# Creates a minimal macOS application target along with a minimal Unit Test
# target. The optional test_bundle_id parameter may be passed to override the
# default test bundle identifier.
function create_minimal_macos_application_with_tests() {
  if [[ ! -f app/BUILD ]]; then
    fail "create_common_files must be called first."
  fi

  test_bundle_id="\"${1:-}\""

  cat >> app/BUILD <<EOF
macos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    infoplists = ["Info.plist"],
    minimum_os_version = "10.11",
    deps = [":lib"],
)

macos_unit_test(
    name = "unit_tests",
    deps = [":unit_test_lib"],
    minimum_os_version = "10.11",
    test_host = ":app",
EOF

  if [[ -n "$test_bundle_id" ]]; then
  cat >> app/BUILD <<EOF
    bundle_id = $test_bundle_id,
EOF
  fi

  cat >> app/BUILD <<EOF
)
EOF
}

# Creates a minimal Unit Test target with no test host.
function create_minimal_macos_unit_test() {
  if [[ ! -f app/BUILD ]]; then
    fail "create_common_files must be called first."
  fi

  cat >> app/BUILD <<EOF
macos_unit_test(
    name = "unit_tests",
    bundle_id = "my.bundle.idTests",
    minimum_os_version = "10.11",
    deps = [":unit_test_lib"],
)
EOF
}

# Creates a minimal runner rule that just prints out the variables passed.
function create_test_with_minimal_test_runner_rule() {
  if [[ ! -f app/BUILD ]]; then
    fail "create_common_files must be called first."
  fi

  cat >> app/BUILD <<EOF
macos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    infoplists = ["Info.plist"],
    minimum_os_version = "10.11",
    deps = [":lib"],
)

load(
    "@build_bazel_rules_apple//test/testdata/rules:dummy_test_runner.bzl",
    "dummy_test_runner",
)

dummy_test_runner(
    name = "DummyTestRunner",
)

macos_unit_test(
    name = "unit_tests",
    deps = [":unit_test_lib"],
    minimum_os_version = "10.11",
    test_host = ":app",
    runner = ":DummyTestRunner",
)
EOF
}

# Tests that tests can override the bundle id.
function test_bundle_id_override() {
  create_common_files
  create_minimal_macos_application_with_tests "my.test.bundle.id"
  create_dump_plist "//app:unit_tests" "unit_tests.xctest/Contents/Info.plist" \
      CFBundleIdentifier

  do_build macos //app:dump_plist || fail "Should build"

  assert_equals "my.test.bundle.id" "$(cat "test-bin/app/CFBundleIdentifier")"
}

# Tests that tests can't reuse the test host's bundle id.
function test_bundle_id_same_as_test_host_error() {
  create_common_files
  create_minimal_macos_application_with_tests "my.bundle.id"

  ! do_build macos //app:unit_tests || fail "Should build"
  expect_log "can't be the same as the test host's bundle identifier"
}

# Tests that the tests can be built with no host.
function test_builds_with_no_host() {
  create_common_files
  create_minimal_macos_unit_test

  do_build macos //app:unit_tests || fail "Should build"
}

# Tests that the test runner script gets created correctly.
function test_runner_script_contains_expected_values() {
  create_common_files
  create_test_with_minimal_test_runner_rule
  do_build macos //app:unit_tests || fail "Should build"

  assert_contains "TEST_HOST=app/app.zip" "test-bin/app/unit_tests"
  assert_contains "TEST_BUNDLE=app/unit_tests.zip" "test-bin/app/unit_tests"
  assert_contains "TEST_TYPE=XCTEST" "test-bin/app/unit_tests"
}

run_suite "macos_unit_test bundling tests"
