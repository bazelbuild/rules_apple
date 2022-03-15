#!/bin/bash

# Copyright 2022 The Bazel Authors. All rights reserved.
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

# Integration tests for testing iOS tests with code coverage enabled.

set -euo pipefail

function set_up() {
  mkdir -p app
}

function tear_down() {
  rm -rf app
}

function create_common_files() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_application", "ios_unit_test")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

objc_library(
    name = "app_lib",
    hdrs = ["main.h"],
    srcs = ["main.m"],
)

objc_library(
    name = "shared_logic",
    hdrs = ["SharedLogic.h"],
    srcs = ["SharedLogic.m"],
)

objc_library(
    name = "hosted_test_lib",
    srcs = ["HostedTest.m"],
    deps = [":app_lib", ":shared_logic"],
)

objc_library(
    name = "standalone_test_lib",
    srcs = ["StandaloneTest.m"],
    deps = [":shared_logic"],
)
EOF

  cat > app/main.h <<EOF
int foo();
EOF

  cat > app/main.m <<EOF
#import <UIKit/UIKit.h>

int foo() {
  return 1;
}

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation AppDelegate
@end

int main(int argc, char **argv) {
  return UIApplicationMain(argc, argv, nil, @"AppDelegate");
}
EOF

  cat > app/SharedLogic.h <<EOF
#import <Foundation/Foundation.h>

@interface SharedLogic: NSObject
- (void)doSomething;
@end
EOF

  cat > app/SharedLogic.m <<EOF
#import "app/SharedLogic.h"

@implementation SharedLogic
- (void)doSomething {}
@end
EOF

  cat > app/HostedTest.m <<EOF
#import <XCTest/XCTest.h>
#import "app/main.h"
#import "app/SharedLogic.h"
@interface HostedTest: XCTestCase
@end

@implementation HostedTest
- (void)testHostedAPI {
  [[SharedLogic new] doSomething];
  XCTAssertEqual(1, foo());
}
@end
EOF

  cat > app/StandaloneTest.m <<EOF
#import <XCTest/XCTest.h>
#import "app/SharedLogic.h"
@interface StandaloneTest: XCTestCase
@end

@implementation StandaloneTest
- (void)testAnything {
  [[SharedLogic new] doSomething];
  XCTAssert(true);
}
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

  cat >> app/BUILD <<EOF
ios_application(
    name = "app",
    bundle_id = "my.bundle.id",
    families = ["iphone"],
    infoplists = ["Info.plist"],
    minimum_os_version = "9.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_ios.mobileprovision",
    deps = [":app_lib"],
)

ios_unit_test(
    name = "hosted_test",
    deps = [":hosted_test_lib"],
    minimum_os_version = "9.0",
    test_host = ":app",
)

ios_unit_test(
    name = "standalone_test",
    deps = [":standalone_test_lib"],
    minimum_os_version = "9.0",
)
EOF
}

function test_standalone_unit_test_coverage() {
  create_common_files
  do_coverage ios --test_output=errors --ios_minimum_os=9.0 --experimental_use_llvm_covmap //app:standalone_test || fail "Should build"

  assert_contains "SharedLogic.m:-\[SharedLogic doSomething\]" "test-testlogs/app/standalone_test/coverage.dat"
}

function test_hosted_unit_test_coverage() {
  create_common_files
  do_coverage ios --test_output=errors --ios_minimum_os=9.0 --experimental_use_llvm_covmap //app:hosted_test || fail "Should build"

  # Validate normal coverage is included
  assert_contains "SharedLogic.m:-\[SharedLogic doSomething\]" "test-testlogs/app/hosted_test/coverage.dat"
  # Validate coverage for the hosting binary is included
  assert_contains "FN:3,foo" "test-testlogs/app/hosted_test/coverage.dat"

  # Validate that the symbol called from the hosted binary exists and is undefined
  unzip_single_file \
    "test-bin/app/hosted_test.runfiles/build_bazel_rules_apple_integration_tests/app/hosted_test.zip" \
    "hosted_test.xctest/hosted_test" \
    nm -u - | grep foo || fail "Undefined 'foo' symbol not found"
}

run_suite "ios coverage tests"
