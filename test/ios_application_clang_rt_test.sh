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
  rm -rf app
  mkdir -p app
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
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing.mobileprovision",
    deps = [":lib"],
)
EOF
}

# Tests that ASAN libraries and packaged into the IPA when enabled.
function test_asan_bundle() {
  create_common_files
  create_minimal_ios_application

  do_build ios --define=apple_bundle_clang_rt=1 \
      --experimental_objc_crosstool=all \
      --features=asan \
      //app:app || fail "Should build"

  if is_device_build ios ; then
    assert_zip_contains "test-bin/app/app.ipa" \
        "Payload/app.app/Frameworks/libclang_rt.asan_ios_dynamic.dylib"
  else
    assert_zip_contains "test-bin/app/app.ipa" \
        "Payload/app.app/Frameworks/libclang_rt.asan_iossim_dynamic.dylib"
  fi
}

# Tests that the tool correctly fails if no runtime libraries were linked.
function test_missing_link() {
  create_common_files
  create_minimal_ios_application

  ! do_build ios --define=apple_bundle_clang_rt=1 \
      //app:app || fail "Should not build"

  expect_log "RuntimeError: Could not find clang library path."
}

run_suite "ios_application clang support tests"
