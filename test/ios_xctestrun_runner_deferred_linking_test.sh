#!/bin/bash

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

# Integration tests for linking iOS test bundles in the test action with the
# `apple.defer_test_bundle_linking` feature and the iOS xctestrun runner.

function set_up() {
  mkdir -p ios
}

function tear_down() {
  rm -rf ios
}

function create_tests() {
  cat > ios/BUILD <<EOF
load("@rules_apple//apple:ios.bzl", "ios_application", "ios_unit_test")
load(
    "@rules_apple//apple/testing/default_runner:ios_xctestrun_runner.bzl",
    "ios_xctestrun_runner",
)
load("@rules_cc//cc:objc_library.bzl", "objc_library")
load("@rules_swift//swift:swift.bzl", "swift_library")

# Uses the simulator device from the ios_simulator_device build setting.
ios_xctestrun_runner(
    name = "sim_runner",
)

objc_library(
    name = "app_lib",
    srcs = ["main.m"],
)

ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    minimum_os_version = "15.0",
    provisioning_profile = "@rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":app_lib"],
)

objc_library(
    name = "pass_test_lib",
    srcs = ["pass_unit_test.m"],
    testonly = True,
)

ios_unit_test(
    name = "PassingUnitTest",
    minimum_os_version = "15.0",
    runner = ":sim_runner",
    deps = [":pass_test_lib"],
)

objc_library(
    name = "fail_test_lib",
    srcs = ["fail_unit_test.m"],
    testonly = True,
)

ios_unit_test(
    name = "FailingUnitTest",
    minimum_os_version = "15.0",
    runner = ":sim_runner",
    deps = [":fail_test_lib"],
)

swift_library(
    name = "swift_test_lib",
    srcs = ["pass_unit_test.swift"],
    testonly = True,
)

ios_unit_test(
    name = "PassingSwiftUnitTestWithHost",
    minimum_os_version = "15.0",
    runner = ":sim_runner",
    test_host = ":app",
    deps = [":swift_test_lib"],
)
EOF

  # iOS 27 requires apps to adopt the scene lifecycle.
  cat > ios/main.m <<EOF
#import <UIKit/UIKit.h>

@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>
@property(nonatomic, strong) UIWindow *window;
@end

@implementation SceneDelegate
- (void)scene:(UIScene *)scene
    willConnectToSession:(UISceneSession *)session
                 options:(UISceneConnectionOptions *)connectionOptions {
  self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
  self.window.rootViewController = [[UIViewController alloc] init];
  [self.window makeKeyAndVisible];
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation AppDelegate
- (UISceneConfiguration *)application:(UIApplication *)application
    configurationForConnectingSceneSession:(UISceneSession *)session
                                   options:(UISceneConnectionOptions *)options {
  UISceneConfiguration *configuration =
      [[UISceneConfiguration alloc] initWithName:@"Default" sessionRole:session.role];
  configuration.delegateClass = [SceneDelegate class];
  return configuration;
}
@end

int main(int argc, char * argv[]) {
  @autoreleasepool {
    return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
  }
}
EOF

  cat > ios/Info.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1.0";
  CFBundleVersion = "1.0";
  UIApplicationSceneManifest = {
    UIApplicationSupportsMultipleScenes = NO;
  };
}
EOF

  cat > ios/pass_unit_test.m <<EOF
#import <XCTest/XCTest.h>

@interface PassingUnitTest : XCTestCase
@end

@implementation PassingUnitTest
- (void)testPass {
  XCTAssertEqual(1, 1, @"should pass");
}

- (void)testPass2 {
  XCTAssertEqual(1, 1, @"should pass");
}
@end
EOF

  cat > ios/fail_unit_test.m <<EOF
#import <XCTest/XCTest.h>

@interface FailingUnitTest : XCTestCase
@end

@implementation FailingUnitTest
- (void)testFail {
  XCTAssertEqual(0, 1, @"should fail");
}
@end
EOF

  cat > ios/pass_unit_test.swift <<EOF
import XCTest

class PassingSwiftUnitTest: XCTestCase {
  func testPass() throws {
    XCTAssertEqual(1, 1, "should pass")
  }
}
EOF
}

function do_ios_test() {
  do_test ios "--test_output=all" "--spawn_strategy=local" \
    "--features=apple.defer_test_bundle_linking" "$@"
}

function test_deferred_linking_pass() {
  create_tests
  do_ios_test //ios:PassingUnitTest || fail "should pass"

  expect_log "Linked test bundle binary 'PassingUnitTest'"
  expect_log "Test Suite 'PassingUnitTest' passed"
  expect_log "Executed 2 tests, with 0 failures"

  # The test bundle in the output tree doesn't contain the binary.
  local archive
  archive="$(find test-bin/ios -name PassingUnitTest.zip | head -1)"
  [[ -n "$archive" ]] || fail "Could not find the test bundle archive"
  unzip -l "$archive" > "$TEST_TMPDIR/archive_contents.txt" ||
    fail "Could not list the test bundle archive"
  assert_contains "PassingUnitTest.xctest/Info.plist" "$TEST_TMPDIR/archive_contents.txt"
  assert_not_contains "PassingUnitTest.xctest/PassingUnitTest$" "$TEST_TMPDIR/archive_contents.txt"
}

function test_deferred_linking_fail() {
  create_tests
  ! do_ios_test //ios:FailingUnitTest || fail "should fail"

  expect_log "Linked test bundle binary 'FailingUnitTest'"
  expect_log "Test Suite 'FailingUnitTest' failed"
  expect_log "Executed 1 test, with 1 failure"
}

function test_deferred_linking_swift_with_host_pass() {
  create_tests
  do_ios_test //ios:PassingSwiftUnitTestWithHost || fail "should pass"

  expect_log "Linked test bundle binary 'PassingSwiftUnitTestWithHost'"
  expect_log "Test Suite 'PassingSwiftUnitTest' passed"
  expect_log "Executed 1 test, with 0 failures"
}

function test_deferred_linking_coverage() {
  create_tests
  do_coverage ios "--test_output=all" "--spawn_strategy=local" \
    "--experimental_use_llvm_covmap" \
    "--features=apple.defer_test_bundle_linking" \
    //ios:PassingUnitTest || fail "should pass"

  expect_log "Linked test bundle binary 'PassingUnitTest'"
  assert_contains "SF:ios/pass_unit_test.m" \
    "test-testlogs/ios/PassingUnitTest/coverage.dat"
}

run_suite "ios_xctestrun_runner deferred linking tests"
