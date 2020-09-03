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

# Integration tests for bundling iOS static frameworks.

set -eu

function set_up() {
  mkdir -p sdk
}

function tear_down() {
  rm -rf sdk
}

# Tests that attempting to generate dSYMs does not cause the build to fail
# (apple_static_library does not generate dSYMs, and the bundler should not
# unconditionally assume that the provider will be present).
function test_building_with_dsyms_enabled() {
  cat >> sdk/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_static_framework")

ios_static_framework(
    name = "sdk",
    minimum_os_version = "7.0",
    deps = [":framework_lib"],
)

objc_library(
    name = "framework_lib",
    srcs = [
        "Framework.h",
        "Framework.m",
    ],
    sdk_dylibs = ["libz"],
    sdk_frameworks = ["CFNetwork"],
    alwayslink = 1,
)
EOF

  cat > sdk/Framework.h <<EOF
#ifndef SDK_FRAMEWORK_H_
#define SDK_FRAMEWORK_H_

void doStuff();

#endif  // SDK_FRAMEWORK_H_
EOF

  cat > sdk/Framework.m <<EOF
#import <Foundation/Foundation.h>

void doStuff() {
  NSLog(@"Framework method called\n");
}
EOF

  do_build ios --apple_generate_dsym //sdk:sdk || fail "Should build"
}

# Tests that the bundle name can be overridden to differ from the target name.
function test_bundle_name_can_differ_from_target() {
  cat >> sdk/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_static_framework")

ios_static_framework(
    name = "sdk",
    bundle_name = "different",
    minimum_os_version = "7.0",
    deps = [":framework_lib"],
)

objc_library(
    name = "framework_lib",
    srcs = [
        "Framework.h",
        "Framework.m",
    ],
    alwayslink = 1,
)
EOF

  cat > sdk/Framework.h <<EOF
#ifndef SDK_FRAMEWORK_H_
#define SDK_FRAMEWORK_H_

void doStuff();

#endif  // SDK_FRAMEWORK_H_
EOF

  cat > sdk/Framework.m <<EOF
#import <Foundation/Foundation.h>

void doStuff() {
  NSLog(@"Framework method called\n");
}
EOF

  do_build ios //sdk:sdk || fail "Should build"

  # Both the bundle name and the executable name should correspond to
  # bundle_name.
  assert_zip_contains "test-bin/sdk/sdk.zip" "different.framework/"
  assert_zip_contains "test-bin/sdk/sdk.zip" "different.framework/different"
}

# Tests sdk_dylib and sdk_framework attributes are captured into the modulemap.
function test_sdk_attribute_support() {
  cat >> sdk/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_static_framework")

ios_static_framework(
    name = "sdk",
    minimum_os_version = "7.0",
    deps = [":framework_lib"],
)

objc_library(
    name = "framework_lib",
    srcs = [
        "Framework.h",
        "Framework.m",
    ],
    sdk_dylibs = ["libz"],
    sdk_frameworks = ["CFNetwork"],
    alwayslink = 1,
)
EOF

  cat > sdk/Framework.h <<EOF
#ifndef SDK_FRAMEWORK_H_
#define SDK_FRAMEWORK_H_

void doStuff();

#endif  // SDK_FRAMEWORK_H_
EOF

  cat > sdk/Framework.m <<EOF
#import <Foundation/Foundation.h>

void doStuff() {
  NSLog(@"Framework method called\n");
}
EOF

  do_build ios //sdk:sdk || fail "Should build"

  assert_zip_contains "test-bin/sdk/sdk.zip" \
      "sdk.framework/Modules/module.modulemap"
  unzip_single_file "test-bin/sdk/sdk.zip" \
      "sdk.framework/Modules/module.modulemap" \
    | grep -sq 'link "z"' || fail "Should have said to link libz"
  unzip_single_file "test-bin/sdk/sdk.zip" \
      "sdk.framework/Modules/module.modulemap" \
    | grep -sq 'link framework "CFNetwork"' \
    || fail "Should have said to link CFNetwork.framework"
}

run_suite "ios_static_framework bundling tests"
