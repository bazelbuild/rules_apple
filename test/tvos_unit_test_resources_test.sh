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

set -eu

# Integration tests for bundling tvOS unit tests that use duplicate resources.

function set_up() {
  mkdir -p tvos
}

function tear_down() {
  rm -rf tvos
}

function create_test_files() {

  cat > tvos/BUILD <<EOF
load(
    "@build_bazel_rules_apple//apple:tvos.bzl",
    "tvos_application",
    "tvos_framework",
    "tvos_unit_test",
)
load(
    "@build_bazel_rules_apple//apple:resources.bzl",
    "apple_bundle_import",
)

apple_bundle_import(
    name = "shared_bundle",
    bundle_imports = glob(["shared.bundle/**"]),
)

apple_bundle_import(
    name = "app_bundle",
    bundle_imports = glob(["app.bundle/**"]),
)

apple_bundle_import(
    name = "test_bundle",
    bundle_imports = glob(["test.bundle/**"]),
)

objc_library(
    name = "shared_lib",
    srcs = ["shared.m"],
    data = [
        ":shared_bundle",
        "shared_unbundled.txt",
    ],
)

objc_library(
    name = "app_lib",
    srcs = ["app.m"],
    deps = [":shared_lib"],
    data = [
        ":app_bundle",
        "app_unbundled.txt",
    ],
)

objc_library(
    name = "test_lib",
    srcs = ["test.m"],
    deps = [":app_lib"],
    data = [
        ":test_bundle",
        "test_unbundled.txt",
    ],
)

objc_library(
    name = "main_lib",
    srcs = ["main.m"],
    deps = [":app_lib"],
)

tvos_framework(
    name = "framework",
    bundle_id = "com.framework",
    infoplists = ["Framework.plist"],
    minimum_os_version = "8.0",
    deps = [":shared_lib"],
)

tvos_application(
    name = "app",
    bundle_id = "com.app",
    frameworks = [":framework"],
    infoplists = ["App.plist"],
    minimum_os_version = "8.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":main_lib"],
)

tvos_unit_test(
    name = "test",
    minimum_os_version = "8.0",
    test_host = ":app",
    deps = [":test_lib"],
)
EOF

  cat > tvos/main.m << EOF
int main() {}
EOF

  cat > tvos/app.m << EOF
#import <Foundation/Foundation.h>
@interface AppClass: NSObject
@end
@implementation AppClass
@end
EOF

  cat > tvos/shared.m << EOF
#import <Foundation/Foundation.h>
@interface SharedClass: NSObject
@end
@implementation SharedClass
@end
EOF

cat > tvos/test.m << EOF
#import <XCTest/XCTest.h>
@interface TestClass: XCTestCase
@end
@implementation TestClass
- (void)testSomething {XCTAssertTrue(YES);}
@end
EOF

  cat > tvos/App.plist << EOF
{
  CFBundleDisplayName = "\${PRODUCT_NAME}";
  CFBundleExecutable = "\${EXECUTABLE_NAME}";
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleInfoDictionaryVersion = "6.0";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1.0.0";
  CFBundleVersion = "1.0.0";
}
EOF

cat > tvos/Framework.plist << EOF
{
  CFBundleDisplayName = "\${PRODUCT_NAME}";
  CFBundleExecutable = "\${EXECUTABLE_NAME}";
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleInfoDictionaryVersion = "6.0";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "FMWK";
  CFBundleShortVersionString = "1.0.0";
  CFBundleVersion = "1.0.0";
}
EOF

  touch tvos/app_unbundled.txt
  touch tvos/shared_unbundled.txt
  touch tvos/test_unbundled.txt
  mkdir -p tvos/app.bundle
  mkdir -p tvos/shared.bundle
  mkdir -p tvos/test.bundle
  touch tvos/app.bundle/app_bundled.txt
  touch tvos/shared.bundle/shared_bundled.txt
  touch tvos/test.bundle/test_bundled.txt

  cat > tvos/app.bundle/Info.plist << EOF
{
  CFBundleIdentifier = "com.app_bundle";
  CFBundleInfoDictionaryVersion = "6.0";
  CFBundleName = "app_bundle";
  CFBundlePackageType = "BNDL";
  CFBundleShortVersionString = "1.0";
  CFBundleSignature = "????";
  CFBundleVersion = "1";
}
EOF

  cat > tvos/shared.bundle/Info.plist << EOF
{
  CFBundleIdentifier = "com.shared_bundle";
  CFBundleInfoDictionaryVersion = "6.0";
  CFBundleName = "shared_bundle";
  CFBundlePackageType = "BNDL";
  CFBundleShortVersionString = "1.0";
  CFBundleSignature = "????";
  CFBundleVersion = "1";
}
EOF

  cat > tvos/test.bundle/Info.plist << EOF
{
  CFBundleIdentifier = "com.test_bundle";
  CFBundleInfoDictionaryVersion = "6.0";
  CFBundleName = "test_bundle";
  CFBundlePackageType = "BNDL";
  CFBundleShortVersionString = "1.0";
  CFBundleSignature = "????";
  CFBundleVersion = "1";
}
EOF
}

function test_resource_are_deduplicated_if_present_in_dependency() {
  create_test_files

  do_build tvos //tvos:{app,framework} || fail "Should build"

  assert_zip_contains "test-bin/tvos/framework.zip" \
      "framework.framework/shared.bundle/shared_bundled.txt"
  assert_zip_contains "test-bin/tvos/framework.zip" \
      "framework.framework/shared_unbundled.txt"

  assert_zip_contains "test-bin/tvos/app.ipa" \
      "Payload/app.app/app.bundle/app_bundled.txt"
  assert_zip_contains "test-bin/tvos/app.ipa" \
      "Payload/app.app/app_unbundled.txt"
  assert_zip_not_contains "test-bin/tvos/app.ipa" \
      "Payload/app.app/shared.bundle/shared_bundled.txt"
  assert_zip_not_contains "test-bin/tvos/app.ipa" \
      "Payload/app.app/shared_unbundled.txt"

  do_build tvos //tvos:test.zip || fail "Should build"

  assert_zip_contains "test-bin/tvos/test.zip" \
      "test.xctest/test.bundle/test_bundled.txt"
  assert_zip_contains "test-bin/tvos/test.zip" \
      "test.xctest/test_unbundled.txt"
  assert_zip_not_contains "test-bin/tvos/test.zip" \
      "test.xctest/app.bundle/app_bundled.txt"
  assert_zip_not_contains "test-bin/tvos/test.zip" \
      "test.xctest/app_unbundled.txt"
  assert_zip_not_contains "test-bin/tvos/test.zip" \
      "test.xctest/shared.bundle/shared_bundled.txt"
  assert_zip_not_contains "test-bin/tvos/test.zip" \
      "test.xctest/shared_unbundled.txt"
}


run_suite "tvos unit test resources deduplication tests"
