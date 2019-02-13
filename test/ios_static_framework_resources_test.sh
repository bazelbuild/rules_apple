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

# Creates the targets for a minimal static framework.
function create_minimal_ios_static_framework() {
  local exclude_resources="$1"; shift
  local include_headers="$1"; shift
  cat > sdk/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_static_framework")

ios_static_framework(
    name = "sdk",
    minimum_os_version = "7.0",
    deps = [":framework_lib"],
    avoid_deps = [":framework_dependent_lib"],
EOF
  if [[ "$include_headers" = "True" ]]; then
    echo "    hdrs = [\"Framework.h\"],"  >> sdk/BUILD
  fi
  echo "    exclude_resources = $exclude_resources" >> sdk/BUILD

  cat >> sdk/BUILD <<EOF
)

objc_library(
    name = "framework_lib",
    srcs = [
        "Framework.h",
        "Framework.m",
    ],
    deps = [":framework_dependent_lib"],
    alwayslink = 1,
    data = [
        "@build_bazel_rules_apple//test/testdata/resources:assets_ios",
        "@build_bazel_rules_apple//test/testdata/resources:unversioned_datamodel",
        "@build_bazel_rules_apple//test/testdata/resources:versioned_datamodel",
        "@build_bazel_rules_apple//test/testdata/resources:storyboard_ios.storyboard",
        "@build_bazel_rules_apple//test/testdata/resources:nonlocalized.strings",
        "@build_bazel_rules_apple//test/testdata/resources:view_ios.xib",
    ],
)

objc_library(
    name = "framework_dependent_lib",
    srcs = ["FrameworkDependent.m"],
    data = [
        "@build_bazel_rules_apple//test/testdata/resources:view_ios.xib",
    ],
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

  cat > sdk/FrameworkDependent.m <<EOF
#import <Foundation/Foundation.h>

void frameworkDependent() {
  NSLog(@"frameworkDependent() called");
}
EOF
}

# Tests that the SDK's .framework bundle contains the expected files.
function test_sdk_contains_expected_files() {
  create_minimal_ios_static_framework True True
  do_build ios //sdk:sdk || fail "Should build"

  assert_zip_contains "test-bin/sdk/sdk.zip" "sdk.framework/sdk"
  assert_zip_not_contains "test-bin/sdk/sdk.zip" "sdk.framework/Info.plist"
  assert_zip_contains "test-bin/sdk/sdk.zip" "sdk.framework/Headers/Framework.h"
  assert_zip_contains "test-bin/sdk/sdk.zip" "sdk.framework/Modules/module.modulemap"

  # Verify asset catalogs.
  assert_zip_not_contains "test-bin/sdk/sdk.zip" "sdk.framework/Assets.car"

  # Verify Core Data models.
  assert_zip_not_contains "test-bin/sdk/sdk.zip" \
      "sdk.framework/unversioned_datamodel.mom"
  assert_zip_not_contains "test-bin/sdk/sdk.zip" \
      "sdk.framework/versioned_datamodel.momd/v1.mom"
  assert_zip_not_contains "test-bin/sdk/sdk.zip" \
      "sdk.framework/versioned_datamodel.momd/v2.mom"
  assert_zip_not_contains "test-bin/sdk/sdk.zip" \
      "sdk.framework/versioned_datamodel.momd/VersionInfo.plist"

  # Verify compiled storyboards.
  assert_zip_not_contains "test-bin/sdk/sdk.zip" \
      "sdk.framework/storyboard_ios.storyboardc/"

  # Verify strings.
  assert_zip_not_contains "test-bin/sdk/sdk.zip" \
      "sdk.framework/nonlocalized.strings"

  # Verify compiled NIBs.
  assert_zip_not_contains "test-bin/sdk/sdk.zip" \
      "sdk.framework/view_ios~iphone.nib/"
}

# Tests that the SDK's .framework bundle does not contain headers when not needed.
function test_sdk_does_not_contain_headers() {
  create_minimal_ios_static_framework True False
  do_build ios //sdk:sdk || fail "Should build"

  assert_zip_contains "test-bin/sdk/sdk.zip" "sdk.framework/sdk"
  assert_zip_not_contains "test-bin/sdk/sdk.zip" "sdk.framework/Info.plist"
  assert_zip_not_contains "test-bin/sdk/sdk.zip" "sdk.framework/Headers/Framework.h"
  assert_zip_not_contains "test-bin/sdk/sdk.zip" "sdk.framework/Modules/module.modulemap"

  # Verify asset catalogs.
  assert_zip_not_contains "test-bin/sdk/sdk.zip" "sdk.framework/Assets.car"

  # Verify Core Data models.
  assert_zip_not_contains "test-bin/sdk/sdk.zip" \
      "sdk.framework/unversioned_datamodel.mom"
  assert_zip_not_contains "test-bin/sdk/sdk.zip" \
      "sdk.framework/versioned_datamodel.momd/v1.mom"
  assert_zip_not_contains "test-bin/sdk/sdk.zip" \
      "sdk.framework/versioned_datamodel.momd/v2.mom"
  assert_zip_not_contains "test-bin/sdk/sdk.zip" \
      "sdk.framework/versioned_datamodel.momd/VersionInfo.plist"

  # Verify compiled storyboards.
  assert_zip_not_contains "test-bin/sdk/sdk.zip" \
      "sdk.framework/storyboard_ios.storyboardc/"

  # Verify strings.
  assert_zip_not_contains "test-bin/sdk/sdk.zip" \
      "sdk.framework/nonlocalized.strings"

  # Verify compiled NIBs.
  assert_zip_not_contains "test-bin/sdk/sdk.zip" \
      "sdk.framework/view_ios~iphone.nib/"
}


# Tests that the SDK's .framework bundle contains the expected files when
# "exclude_resources = False". The "not_contains" resource tests become
# "contains".
function test_sdk_contains_expected_files_without_excluding_resources() {
  create_minimal_ios_static_framework False True
  do_build ios //sdk:sdk || fail "Should build"

  assert_zip_contains "test-bin/sdk/sdk.zip" "sdk.framework/sdk"
  assert_zip_not_contains "test-bin/sdk/sdk.zip" "sdk.framework/Info.plist"
  assert_zip_contains "test-bin/sdk/sdk.zip" "sdk.framework/Headers/Framework.h"
  assert_zip_contains "test-bin/sdk/sdk.zip" "sdk.framework/Modules/module.modulemap"

  # Verify asset catalogs.
  assert_zip_contains "test-bin/sdk/sdk.zip" "sdk.framework/Assets.car"
  # Verify that one of the image names shows up in the asset catalog. (The file
  # format is a black box to us, but we can at a minimum grep the name out
  # because it's visible in the raw bytes).
  unzip_single_file "test-bin/sdk/sdk.zip" "sdk.framework/Assets.car" | \
      grep "star_iphone" > /dev/null || \
      fail "Did not find star_iphone in Assets.car"

  # Verify Core Data models.
  assert_zip_contains "test-bin/sdk/sdk.zip" \
      "sdk.framework/unversioned_datamodel.mom"
  assert_zip_contains "test-bin/sdk/sdk.zip" \
      "sdk.framework/versioned_datamodel.momd/v1.mom"
  assert_zip_contains "test-bin/sdk/sdk.zip" \
      "sdk.framework/versioned_datamodel.momd/v2.mom"
  assert_zip_contains "test-bin/sdk/sdk.zip" \
      "sdk.framework/versioned_datamodel.momd/VersionInfo.plist"

  # Verify compiled storyboards.
  assert_zip_contains "test-bin/sdk/sdk.zip" \
      "sdk.framework/storyboard_ios.storyboardc/"

  # Verify strings.
  assert_zip_contains "test-bin/sdk/sdk.zip" \
      "sdk.framework/nonlocalized.strings"

  # Verify compiled NIBs.
  assert_zip_contains "test-bin/sdk/sdk.zip" \
      "sdk.framework/view_ios~iphone.nib/"
}

run_suite "ios_static_framework bundling resource tests"
