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
load("@build_bazel_rules_apple//apple:ios.bzl",
     "apple_product_type",
     "ios_application",
     "ios_unit_test",
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
}

# Usage: create_minimal_ios_application_with_tests [test_bundle_id]
#
# Creates a minimal iOS application target along with a minimal Unit Test
# target. The optional test_bundle_id parameter may be passed to override the
# default test bundle identifier.
function create_minimal_ios_application_with_tests() {
  if [[ ! -f app/BUILD ]]; then
    fail "create_common_files must be called first."
  fi

  test_bundle_id="\"${1:-}\""

  cat >> app/BUILD <<EOF
ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib"],
)

ios_unit_test(
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

  cat >> app/BUILD <<EOF
)
EOF
}

# Creates a minimal Unit Test target with the default test host.
function create_minimal_ios_unit_test() {
  if [[ ! -f app/BUILD ]]; then
    fail "create_common_files must be called first."
  fi

  cat >> app/BUILD <<EOF
ios_unit_test(
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
ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":lib"],
)

load(
    "@build_bazel_rules_apple//test/testdata/rules:dummy_test_runner.bzl",
    "dummy_test_runner",
)

dummy_test_runner(
    name = "DummyTestRunner",
)

ios_unit_test(
    name = "unit_tests",
    deps = [":unit_test_lib"],
    minimum_os_version = "9.0",
    test_host = ":app",
    runner = ":DummyTestRunner",
)
EOF
}

# Tests that the Info.plist in the packaged test has the correct content.
function test_plist_contents() {
  create_common_files
  create_minimal_ios_application_with_tests
  create_dump_plist "//app:unit_tests_test_bundle.zip" "unit_tests.xctest/Info.plist" \
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
  do_build ios --ios_minimum_os=9.0 //app:dump_plist || fail "Should build"

  # Verify the values injected by the Skylark rule.
  assert_equals "unit_tests" "$(cat "test-genfiles/app/CFBundleExecutable")"

  # When not providing a bundle_id, it uses the test host's and appends "Tests"
  assert_equals "my.bundle.idTests" "$(cat "test-genfiles/app/CFBundleIdentifier")"
  assert_equals "unit_tests" "$(cat "test-genfiles/app/CFBundleName")"
  assert_equals "9.0" "$(cat "test-genfiles/app/MinimumOSVersion")"
  assert_equals "1" "$(cat "test-genfiles/app/UIDeviceFamily.0")"

  if is_device_build ios ; then
    assert_equals "iPhoneOS" \
        "$(cat "test-genfiles/app/CFBundleSupportedPlatforms.0")"
    assert_equals "iphoneos" \
        "$(cat "test-genfiles/app/DTPlatformName")"
    assert_contains "iphoneos.*" \
        "test-genfiles/app/DTSDKName"
  else
    assert_equals "iPhoneSimulator" \
        "$(cat "test-genfiles/app/CFBundleSupportedPlatforms.0")"
    assert_equals "iphonesimulator" \
        "$(cat "test-genfiles/app/DTPlatformName")"
    assert_contains "iphonesimulator.*" "test-genfiles/app/DTSDKName"
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
  create_minimal_ios_application_with_tests "my.test.bundle.id"
  create_dump_plist "//app:unit_tests_test_bundle.zip" "unit_tests.xctest/Info.plist" \
      CFBundleIdentifier

  do_build ios --ios_minimum_os=9.0 //app:dump_plist || fail "Should build"

  assert_equals "my.test.bundle.id" "$(cat "test-genfiles/app/CFBundleIdentifier")"
}

# Tests that tests can't reuse the test host's bundle id.
function test_bundle_id_same_as_test_host_error() {
  create_common_files
  create_minimal_ios_application_with_tests "my.bundle.id"
  create_dump_plist "//app:unit_tests_test_bundle.zip" "unit_tests.xctest/Info.plist" \
      CFBundleIdentifier

  ! do_build ios --ios_minimum_os=9.0 //app:dump_plist || fail "Should build"
  expect_log "can't be the same as the test host's bundle identifier"
}

# Tests that the tests can be built with a default host.
function test_builds_with_default_host() {
  if [[ "$TEST_BINARY" = *.simulator ]]; then
    # The default test host does not work for device builds as it needs a
    # provisioning profile.
    create_common_files
    create_minimal_ios_unit_test

    do_build ios --ios_minimum_os=9.0 //app:unit_tests || fail "Should build"
  else
    echo "Skipping: non simulator testing needs a signed test host."
  fi
}

# Tests that the output contains a valid signed test bundle.
function test_bundle_is_signed() {
  create_common_files
  create_minimal_ios_application_with_tests
  create_dump_codesign "//app:unit_tests_test_bundle.zip" "unit_tests.xctest" -vv
  do_build ios --ios_minimum_os=9.0 //app:dump_codesign || fail "Should build"

  assert_contains "satisfies its Designated Requirement" \
      "test-genfiles/app/codesign_output"
}

# Tests that the test runner script gets created correctly.
function test_runner_script_contains_expected_values() {
  create_common_files
  create_test_with_minimal_test_runner_rule
  do_build ios --ios_minimum_os=9.0 //app:unit_tests || fail "Should build"

  assert_contains "TEST_HOST=app/app.ipa" "test-bin/app/unit_tests"
  assert_contains "TEST_BUNDLE=app/unit_tests.zip" "test-bin/app/unit_tests"
  assert_contains "TEST_TYPE=XCTEST" "test-bin/app/unit_tests"
}

# Tests that ios_unit_test targets build if transitively depending on swift.
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
ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
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

ios_unit_test(
    name = "unit_tests",
    deps = [":unit_test_lib_with_swift"],
    minimum_os_version = "9.0",
    test_host = ":app",
)
EOF

  do_build ios --ios_minimum_os=9.0 //app:unit_tests || fail "Should build"
}

# Tests that the dSYM outputs are produced when --apple_generate_dsym is
# present.
function test_dsyms_generated() {
  create_common_files
  create_minimal_ios_application_with_tests
  do_build ios --apple_generate_dsym //app:unit_tests || fail "Should build"

  assert_exists "test-bin/app/unit_tests.xctest.dSYM/Contents/Info.plist"

  declare -a archs=( $(current_archs ios) )
  for arch in "${archs[@]}"; do
    assert_exists \
        "test-bin/app/unit_tests.xctest.dSYM/Contents/Resources/DWARF/unit_tests_${arch}"
  done
}

function test_logic_unit_test_packages_objc_framework_targets {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_unit_test",
    )

objc_framework(
    name = "my_framework",
    framework_imports = ["my_framework.framework/my_framework"],
    is_dynamic = 1,
)

objc_library(
    name = "test_lib",
    srcs = [
        "Tests.m",
    ],
    deps = [":my_framework"],
)

ios_unit_test(
    name = "test",
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    deps = [":test_lib"],
)
EOF

  mkdir -p app/my_framework.framework
  cp $(rlocation build_bazel_rules_apple/test/testdata/binaries/empty_dylib_lipobin) \
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

  do_build ios //app:test || fail "Should build"

  assert_zip_contains "test-bin/app/test.zip" \
      "test.xctest/Frameworks/my_framework.framework/my_framework"

}

function test_logic_unit_test_packages_apple_framework_import_targets {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_unit_test",
    )
load("@build_bazel_rules_apple//apple:apple.bzl",
     "apple_framework_import",
    )

apple_framework_import(
    name = "my_framework",
    framework_imports = ["my_framework.framework/my_framework"],
    is_dynamic = 1,
)

objc_library(
    name = "test_lib",
    srcs = [
        "Tests.m",
    ],
    deps = [":my_framework"],
)

ios_unit_test(
    name = "test",
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    deps = [":test_lib"],
)
EOF

  mkdir -p app/my_framework.framework
  cp $(rlocation build_bazel_rules_apple/test/testdata/binaries/empty_dylib_lipobin) \
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

  do_build ios //app:test --define=apple.experimental.bundling=1 \
      || fail "Should build"

  assert_zip_contains "test-bin/app/test.zip" \
      "test.xctest/Frameworks/my_framework.framework/my_framework"

}

function test_hosted_unit_test_doesnt_package_objc_framework_targets {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_unit_test",
     "ios_application",
    )

objc_framework(
    name = "my_framework",
    framework_imports = ["my_framework.framework/my_framework"],
    is_dynamic = 1,
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

ios_application(
    name = "app",
    bundle_id = "com.google.test",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":main_lib"],
)

ios_unit_test(
    name = "test",
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    test_host = ":app",
    deps = [":test_lib"],
)
EOF

  mkdir -p app/my_framework.framework
  cp $(rlocation build_bazel_rules_apple/test/testdata/binaries/empty_dylib_lipobin) \
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

  do_build ios //app:test || fail "Should build"

  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/my_framework.framework/my_framework"
  assert_zip_not_contains "test-bin/app/test.zip" \
      "test.xctest/Frameworks/my_framework.framework/my_framework"

}

function test_hosted_unit_test_doesnt_package_apple_framework_import_targets {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl",
     "ios_unit_test",
     "ios_application",
    )
load("@build_bazel_rules_apple//apple:apple.bzl",
     "apple_framework_import",
    )

apple_framework_import(
    name = "my_framework",
    framework_imports = ["my_framework.framework/my_framework"],
    is_dynamic = 1,
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

ios_application(
    name = "app",
    bundle_id = "com.google.test",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":main_lib"],
)

ios_unit_test(
    name = "test",
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    test_host = ":app",
    deps = [":test_lib"],
)
EOF

  mkdir -p app/my_framework.framework
  cp $(rlocation build_bazel_rules_apple/test/testdata/binaries/empty_dylib_lipobin) \
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

  do_build ios //app:test --define=apple.experimental.bundling=1 \
      || fail "Should build"

  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/Frameworks/my_framework.framework/my_framework"
  assert_zip_not_contains "test-bin/app/test.zip" \
      "test.xctest/Frameworks/my_framework.framework/my_framework"

}

run_suite "ios_unit_test bundling tests"
