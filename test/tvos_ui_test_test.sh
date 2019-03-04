#!/bin/bash

# Copyright 2019 The Bazel Authors. All rights reserved.
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

# Integration tests for bundling simple tvOS UI tests.

set -eu

function set_up() {
  mkdir -p app
}

function tear_down() {
  rm -rf app
}

# Creates common source, targets, and basic plist for tvOS applications and
# tests.
function create_common_files() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:tvos.bzl",
     "tvos_application",
     "tvos_ui_test",
    )

objc_library(
    name = "lib",
    srcs = ["main.m"],
)

objc_library(
    name = "ui_test_lib",
    srcs = ["UITest.m"],
)
EOF

  cat > app/main.m <<EOF
int main(int argc, char **argv) {
  return 0;
}
EOF

  cat > app/UITest.m <<EOF
#import <XCTest/XCTest.h>
@interface UITest: XCTestCase
@end

@implementation UITest
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

# Usage: create_minimal_tvos_application_with_tests [test_bundle_id]
#
# Creates a minimal tvOS application target along with a minimal UI Test
# target. The optional test_bundle_id parameter may be passed to override the
# default test bundle identifier.
function create_minimal_tvos_application_with_tests() {
  if [[ ! -f app/BUILD ]]; then
    fail "create_common_files must be called first."
  fi

  test_bundle_id="\"${1:-}\""

  cat >> app/BUILD <<EOF
tvos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":lib"],
)

tvos_ui_test(
    name = "ui_tests",
    deps = [":ui_test_lib"],
    minimum_os_version = "9.0",
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

# Creates a minimal UI Test target with no test host.
function create_tvos_ui_test_without_test_host() {
  if [[ ! -f app/BUILD ]]; then
    fail "create_common_files must be called first."
  fi

  cat >> app/BUILD <<EOF
tvos_ui_test(
    name = "ui_tests",
    deps = [":ui_test_lib"],
)
EOF
}

# Creates a minimal runner rule that just prints out the variables passed.
function create_test_with_minimal_test_runner_rule() {
  if [[ ! -f app/BUILD ]]; then
    fail "create_common_files must be called first."
  fi

  cat >> app/BUILD <<EOF
tvos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":lib"],
)

load(
    "@build_bazel_rules_apple//test/testdata/rules:dummy_test_runner.bzl",
    "dummy_test_runner",
)

dummy_test_runner(
    name = "DummyTestRunner",
)

tvos_ui_test(
    name = "ui_tests",
    deps = [":ui_test_lib"],
    minimum_os_version = "9.0",
    test_host = ":app",
    runner = ":DummyTestRunner",
)
EOF
}

# Tests that the Info.plist in the packaged test has the correct content.
function test_plist_contents() {
  create_common_files
  create_minimal_tvos_application_with_tests
  create_dump_plist "//app:ui_tests_test_bundle.zip" "ui_tests.xctest/Info.plist" \
      BuildMachineOSBuild \
      CFBundleExecutable \
      CFBundleIdentifier \
      CFBundleName \
      CFBundleSupportedPlatforms:0 \
      DTCompiler \
      DTPlatformBuild \
      DTPlatformName \
      DTPlatformVersion \
      DTSDKBuild \
      DTSDKName \
      DTXcode \
      DTXcodeBuild \
      MinimumOSVersion \
      UIDeviceFamily:0
  do_build tvos --tvos_minimum_os=9.0 //app:dump_plist || fail "Should build"

  # Verify the values injected by the Skylark rule.
  assert_equals "ui_tests" "$(cat "test-genfiles/app/CFBundleExecutable")"

  # When not providing a bundle_id, it uses the test host's and appends "Tests"
  assert_equals "my.bundle.idTests" "$(cat "test-genfiles/app/CFBundleIdentifier")"
  assert_equals "ui_tests" "$(cat "test-genfiles/app/CFBundleName")"
  assert_equals "9.0" "$(cat "test-genfiles/app/MinimumOSVersion")"
  assert_equals "3" "$(cat "test-genfiles/app/UIDeviceFamily.0")"

  if is_device_build tvos ; then
    assert_equals "AppleTVOS" \
        "$(cat "test-genfiles/app/CFBundleSupportedPlatforms.0")"
    assert_equals "appletvos" \
        "$(cat "test-genfiles/app/DTPlatformName")"
    assert_contains "appletvos.*" \
        "test-genfiles/app/DTSDKName"
  else
    assert_equals "AppleTVSimulator" \
        "$(cat "test-genfiles/app/CFBundleSupportedPlatforms.0")"
    assert_equals "appletvsimulator" \
        "$(cat "test-genfiles/app/DTPlatformName")"
    assert_contains "appletvsimulator.*" "test-genfiles/app/DTSDKName"
  fi

  # Verify the values injected by the environment_plist script. Some of these
  # are dependent on the version of Xcode being used, and since we don't want to
  # force a particular version to always be present, we just make sure that
  # *something* is getting into the plist.
  assert_not_equals "" "$(cat "test-genfiles/app/DTPlatformBuild")"
  assert_not_equals "" "$(cat "test-genfiles/app/DTSDKBuild")"
  assert_not_equals "" "$(cat "test-genfiles/app/DTPlatformVersion")"
  assert_not_equals "" "$(cat "test-genfiles/app/DTXcode")"
  assert_not_equals "" "$(cat "test-genfiles/app/DTXcodeBuild")"
  assert_equals "com.apple.compilers.llvm.clang.1_0" \
      "$(cat "test-genfiles/app/DTCompiler")"
  assert_not_equals "" "$(cat "test-genfiles/app/BuildMachineOSBuild")"
}

# Tests that tests can override the bundle id.
function test_bundle_id_override() {
  create_common_files
  create_minimal_tvos_application_with_tests "my.test.bundle.id"
  create_dump_plist "//app:ui_tests_test_bundle.zip" "ui_tests.xctest/Info.plist" \
      CFBundleIdentifier

  do_build tvos --tvos_minimum_os=9.0 //app:dump_plist || fail "Should build"

  assert_equals "my.test.bundle.id" "$(cat "test-genfiles/app/CFBundleIdentifier")"
}

# Tests that tests can't reuse the test host's bundle id.
function test_bundle_id_same_as_test_host_error() {
  create_common_files
  create_minimal_tvos_application_with_tests "my.bundle.id"
  create_dump_plist "//app:ui_tests_test_bundle.zip" "ui_tests.xctest/Info.plist" \
      CFBundleIdentifier

  ! do_build tvos --tvos_minimum_os=9.0 //app:dump_plist || fail "Should build"
  expect_log "can't be the same as the test host's bundle identifier"
}

# Tests that the tests can't be built without a test host.
function test_build_fails_without_host() {
  create_common_files
  create_tvos_ui_test_without_test_host
  ! do_build tvos //app:ui_tests || fail "Should should not build"
  expect_log "missing value for mandatory attribute 'test_host'"
}

# Tests that the output contains a valid signed test bundle.
function test_bundle_is_signed() {
  create_common_files
  create_minimal_tvos_application_with_tests
  create_dump_codesign "//app:ui_tests_test_bundle.zip" "ui_tests.xctest" -vv
  do_build tvos --tvos_minimum_os=9.0 //app:dump_codesign || fail "Should build"

  assert_contains "satisfies its Designated Requirement" \
      "test-genfiles/app/codesign_output"
}

# Tests that the test runner script gets created correctly.
function test_runner_script_contains_expected_values() {
  create_common_files
  create_test_with_minimal_test_runner_rule
  do_build tvos --tvos_minimum_os=9.0 //app:ui_tests || fail "Should build"

  assert_contains "TEST_HOST=app/app.ipa" "test-bin/app/ui_tests"
  assert_contains "TEST_BUNDLE=app/ui_tests.zip" "test-bin/app/ui_tests"
  assert_contains "TEST_TYPE=XCUITEST" "test-bin/app/ui_tests"
}

# Tests that the dSYM outputs are produced when --apple_generate_dsym is
# present.
function test_dsyms_generated() {
  create_common_files
  create_minimal_tvos_application_with_tests
  do_build tvos --apple_generate_dsym //app:ui_tests || fail "Should build"

  assert_exists "test-bin/app/ui_tests.xctest.dSYM/Contents/Info.plist"

  declare -a archs=( $(current_archs tvos) )
  for arch in "${archs[@]}"; do
    assert_exists \
        "test-bin/app/ui_tests.xctest.dSYM/Contents/Resources/DWARF/ui_tests_${arch}"
  done
}

run_suite "tvos_ui_test bundling tests"
