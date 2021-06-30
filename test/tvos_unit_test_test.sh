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

# Integration tests for bundling simple iOS Unit tests.

set -eu

function set_up() {
  mkdir -p app
}

function tear_down() {
  rm -rf app
}

# Creates common source, targets, and basic plist for iOS applications and
# tests.
function create_common_files() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:tvos.bzl",
     "tvos_application",
     "tvos_unit_test",
    )
load("@build_bazel_rules_swift//swift:swift.bzl",
     "swift_library"
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

  cat > app/TestInfo.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "BNDL";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
}
EOF
}

# Usage: create_minimal_tvos_application_with_tests [test_bundle_id] [test_linkopts]
#
# Creates a minimal tvOS application target along with a minimal Unit Test
# target. The optional test_bundle_id parameter may be passed to override the
# default test bundle identifier. The second optional test_linkopts parameter
# may be passed to override the default test linkopts.
function create_minimal_tvos_application_with_tests() {
  if [[ ! -f app/BUILD ]]; then
    fail "create_common_files must be called first."
  fi

  test_bundle_id="\"${1:-}\""
  test_linkopts=${2:-}

  cat >> app/BUILD <<EOF
tvos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":lib"],
)

tvos_unit_test(
    name = "unit_tests",
    deps = [":unit_test_lib"],
    minimum_os_version = "9.0",
    test_host = ":app",
EOF

  if [[ -n "$test_bundle_id" ]]; then
  cat >> app/BUILD <<EOF
    bundle_id = $test_bundle_id,
EOF
  fi

  if [[ -n "$test_linkopts" ]]; then
  cat >> app/BUILD <<EOF
    linkopts = $test_linkopts,
EOF
  fi

  cat >> app/BUILD <<EOF
)
EOF
}

# Creates a minimal Unit Test target with the default test host.
function create_minimal_tvos_unit_test() {
  if [[ ! -f app/BUILD ]]; then
    fail "create_common_files must be called first."
  fi

  cat >> app/BUILD <<EOF
tvos_unit_test(
    name = "unit_tests",
    minimum_os_version = "9.0",
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

tvos_unit_test(
    name = "unit_tests",
    deps = [":unit_test_lib"],
    minimum_os_version = "9.0",
    test_host = ":app",
    runner = ":DummyTestRunner",
)
EOF
}

# Tests that tests can override the bundle id.
function test_bundle_id_override() {
  create_common_files
  create_minimal_tvos_application_with_tests "my.test.bundle.id"
  create_dump_plist "//app:unit_tests" "unit_tests.xctest/Info.plist" \
      CFBundleIdentifier

  do_build tvos --tvos_minimum_os=9.0 //app:dump_plist || fail "Should build"

  assert_equals "my.test.bundle.id" "$(cat "test-bin/app/CFBundleIdentifier")"
}

# Tests that tests can't reuse the test host's bundle id.
function test_bundle_id_same_as_test_host_error() {
  create_common_files
  create_minimal_tvos_application_with_tests "my.bundle.id"

  ! do_build tvos --tvos_minimum_os=9.0 //app:unit_tests || fail "Should build"
  expect_log "can't be the same as the test host's bundle identifier"
}

# Tests that the tests can be built without a host.
function test_builds_with_no_host() {
  create_common_files
  create_minimal_tvos_unit_test

  do_build tvos --tvos_minimum_os=9.0 //app:unit_tests || fail "Should build"
}

# Tests that the test runner script gets created correctly.
function test_runner_script_contains_expected_values() {
  create_common_files
  create_test_with_minimal_test_runner_rule
  do_build tvos --tvos_minimum_os=9.0 //app:unit_tests || fail "Should build"

  assert_contains "TEST_HOST=app/app.ipa" "test-bin/app/unit_tests"
  assert_contains "TEST_BUNDLE=app/unit_tests.zip" "test-bin/app/unit_tests"
  assert_contains "TEST_TYPE=XCTEST" "test-bin/app/unit_tests"
}

# Tests that tvos_unit_test targets build if transitively depending on swift.
function test_unit_test_depending_on_swift() {
  create_common_files

  cat > app/DepLib.m <<EOF
int dep() {
  return 0;
}
EOF

  cat > app/AppDelegate.swift <<EOF
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?
}
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

  cat >> app/BUILD <<EOF
tvos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":lib"],
)

objc_library(
    name = "unit_test_lib_with_swift",
    srcs = ["UnitTest.m"],
    deps = [":swiftlib"],
)

swift_library(
    name = "swiftlib",
    srcs = ["AppDelegate.swift"],
)

tvos_unit_test(
    name = "unit_tests",
    deps = [":unit_test_lib_with_swift"],
    minimum_os_version = "9.0",
    test_host = ":app",
)
EOF

  do_build tvos --tvos_minimum_os=9.0 //app:unit_tests || fail "Should build"
}

function test_logic_unit_test_packages_dynamic_framework_targets {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:apple.bzl",
     "apple_dynamic_framework_import")
load("@build_bazel_rules_apple//apple:tvos.bzl",
     "tvos_unit_test",
    )

apple_dynamic_framework_import(
    name = "my_framework",
    framework_imports = ["my_framework.framework/my_framework"],
)

objc_library(
    name = "test_lib",
    srcs = [
        "Tests.m",
    ],
    deps = [":my_framework"],
)

tvos_unit_test(
    name = "test",
    infoplists = ["TestInfo.plist"],
    minimum_os_version = "9.0",
    deps = [":test_lib"],
)
EOF

  mkdir -p app/my_framework.framework
  cp $(rlocation build_bazel_rules_apple/test/testdata/binaries/empty_tvos_dylib_lipobin) \
      app/my_framework.framework/my_framework

  cat > app/my_framework.framework/Info.plist <<EOF
Dummy plist
EOF

  cat > app/Info.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1";
  CFBundleVersion = "1.0";
}
EOF

  cat > app/TestInfo.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "BNDL";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
}
EOF

  cat > app/Tests.m <<EOF
#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

@interface Tests: XCTestCase
@end

@implementation Tests

- (void)testSomething {
  XCTAssertTrue(true);
}

@end
EOF

  do_build tvos //app:test.zip || fail "Should build"

  assert_zip_contains "test-bin/app/test.zip" \
      "test.xctest/Frameworks/my_framework.framework/my_framework"

}

function test_logic_unit_test_packages_apple_framework_import_targets {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:tvos.bzl",
     "tvos_unit_test",
    )
load("@build_bazel_rules_apple//apple:apple.bzl",
     "apple_dynamic_framework_import",
    )

apple_dynamic_framework_import(
    name = "my_framework",
    framework_imports = ["my_framework.framework/my_framework"],
)

objc_library(
    name = "test_lib",
    srcs = [
        "Tests.m",
    ],
    deps = [":my_framework"],
)

tvos_unit_test(
    name = "test",
    infoplists = ["TestInfo.plist"],
    minimum_os_version = "9.0",
    deps = [":test_lib"],
)
EOF

  mkdir -p app/my_framework.framework
  cp $(rlocation build_bazel_rules_apple/test/testdata/binaries/empty_tvos_dylib_lipobin) \
      app/my_framework.framework/my_framework

  cat > app/my_framework.framework/Info.plist <<EOF
Dummy plist
EOF

  cat > app/Info.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1";
  CFBundleVersion = "1.0";
}
EOF

  cat > app/TestInfo.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "BNDL";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
}
EOF

  cat > app/Tests.m <<EOF
#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

@interface Tests: XCTestCase
@end

@implementation Tests

- (void)testSomething {
  XCTAssertTrue(true);
}

@end
EOF

  do_build tvos //app:test.zip || fail "Should build"

  assert_zip_contains "test-bin/app/test.zip" \
      "test.xctest/Frameworks/my_framework.framework/my_framework"

}

function test_hosted_unit_test_doesnt_package_dynamic_framework_targets {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:apple.bzl",
     "apple_dynamic_framework_import")
load("@build_bazel_rules_apple//apple:tvos.bzl",
     "tvos_unit_test",
     "tvos_application",
    )

apple_dynamic_framework_import(
    name = "my_framework",
    framework_imports = ["my_framework.framework/my_framework"],
)

objc_library(
    name = "test_lib",
    srcs = [
        "Tests.m",
    ],
    deps = [":my_framework"],
)

objc_library(
    name = "main_lib",
    srcs = [
        "main.m",
    ],
    deps = [":my_framework"],
)

tvos_application(
    name = "app",
    bundle_id = "com.google.test",
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":main_lib"],
)

tvos_unit_test(
    name = "test",
    infoplists = ["TestInfo.plist"],
    minimum_os_version = "9.0",
    test_host = ":app",
    deps = [":test_lib"],
)
EOF

  mkdir -p app/my_framework.framework
  cp $(rlocation build_bazel_rules_apple/test/testdata/binaries/empty_tvos_dylib_lipobin) \
      app/my_framework.framework/my_framework

  cat > app/my_framework.framework/Info.plist <<EOF
Dummy plist
EOF

  cat > app/Info.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1";
  CFBundleVersion = "1.0";
}
EOF

  cat > app/TestInfo.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "BNDL";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
}
EOF

  cat > app/main.m <<EOF
int main() { return 0; }
EOF

  cat > app/Tests.m <<EOF
#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

@interface Tests: XCTestCase
@end

@implementation Tests

- (void)testSomething {
  XCTAssertTrue(true);
}

@end
EOF

  do_build tvos //app:app || fail "Should build"

  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/my_framework.framework/my_framework"

  do_build tvos //app:test.zip || fail "Should build"

  assert_zip_not_contains "test-bin/app/test.zip" \
      "test.xctest/Frameworks/my_framework.framework/my_framework"

}

function test_hosted_unit_test_doesnt_package_apple_framework_import_targets {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:tvos.bzl",
     "tvos_unit_test",
     "tvos_application",
    )
load("@build_bazel_rules_apple//apple:apple.bzl",
     "apple_dynamic_framework_import",
    )

apple_dynamic_framework_import(
    name = "my_framework",
    framework_imports = ["my_framework.framework/my_framework"],
)

objc_library(
    name = "test_lib",
    srcs = [
        "Tests.m",
    ],
    deps = [":my_framework"],
)

objc_library(
    name = "main_lib",
    srcs = [
        "main.m",
    ],
    deps = [":my_framework"],
)

tvos_application(
    name = "app",
    bundle_id = "com.google.test",
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":main_lib"],
)

tvos_unit_test(
    name = "test",
    infoplists = ["TestInfo.plist"],
    minimum_os_version = "9.0",
    test_host = ":app",
    deps = [":test_lib"],
)
EOF

  mkdir -p app/my_framework.framework
  cp $(rlocation build_bazel_rules_apple/test/testdata/binaries/empty_tvos_dylib_lipobin) \
      app/my_framework.framework/my_framework

  cat > app/my_framework.framework/Info.plist <<EOF
Dummy plist
EOF

  cat > app/Info.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1";
  CFBundleVersion = "1.0";
}
EOF

  cat > app/TestInfo.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "BNDL";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
}
EOF

  cat > app/main.m <<EOF
int main() { return 0; }
EOF

  cat > app/Tests.m <<EOF
#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

@interface Tests: XCTestCase
@end

@implementation Tests

- (void)testSomething {
  XCTAssertTrue(true);
}

@end
EOF

  do_build tvos //app:app || fail "Should build"

  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/my_framework.framework/my_framework"

  do_build tvos //app:test.zip || fail "Should build"

  assert_zip_not_contains "test-bin/app/test.zip" \
      "test.xctest/Frameworks/my_framework.framework/my_framework"
}

# Tests that select is usable in linkopts
function test_select_on_linkopts() {
  create_common_files
  create_minimal_tvos_application_with_tests "my.test-bundle.id" 'select({"//conditions:default":[]})'
  do_build tvos //app:unit_tests || fail "Should build"
}

run_suite "tvos_unit_test bundling tests"
