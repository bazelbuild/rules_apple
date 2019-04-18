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

set -eu

# Integration tests for Clang runtime support in iOS apps.

function set_up() {
  mkdir -p app
}

function tear_down() {
  rm -rf app
}

# Creates common source, targets, and basic plist for iOS applications.
function create_common_files() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_application")

objc_library(
    name = "lib",
    srcs = ["main.m"],
)
EOF

  cat > app/main.m <<EOF
int main(int argc, char **argv) {
  return 0;
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
}

# Usage: create_minimal_ios_application
#
# Creates a minimal iOS application target.
function create_minimal_ios_application() {
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
EOF
}

# Tests that ASAN libraries and packaged into the IPA when enabled.
function disabled_test_asan_bundle() {  # Blocked on b/73547309
  create_common_files
  create_minimal_ios_application

  do_build ios --features=asan \
      //app:app || fail "Should build"

  if is_device_build ios ; then
    assert_zip_contains "test-bin/app/app.ipa" \
        "Payload/app.app/Frameworks/libclang_rt.asan_ios_dynamic.dylib"
  else
    assert_zip_contains "test-bin/app/app.ipa" \
        "Payload/app.app/Frameworks/libclang_rt.asan_iossim_dynamic.dylib"
  fi
}

function disabled_test_tsan_bundle() {  # Blocked on b/73547309
  # Skip the device version as tsan is not supported on devices.
  if ! is_device_build ios ; then
    create_common_files
    create_minimal_ios_application

    do_build ios --features=tsan \
        //app:app || fail "Should build"
    assert_zip_contains "test-bin/app/app.ipa" \
        "Payload/app.app/Frameworks/libclang_rt.tsan_iossim_dynamic.dylib"
  fi
}

function disabled_test_ubsan_bundle() {  # Blocked on b/73547309
  create_common_files
  create_minimal_ios_application

  do_build ios --features=ubsan \
      //app:app || fail "Should build"

  if is_device_build ios ; then
    assert_zip_contains "test-bin/app/app.ipa" \
        "Payload/app.app/Frameworks/libclang_rt.ubsan_ios_dynamic.dylib"
  else
    assert_zip_contains "test-bin/app/app.ipa" \
        "Payload/app.app/Frameworks/libclang_rt.ubsan_iossim_dynamic.dylib"
  fi
}

function test_empty() {
  # Empty test so there is still an enabled test in here.
  # Remove after b/73547309 is fixed.
  assert_equals "abc" "abc"
}

run_suite "ios_application clang support tests"
