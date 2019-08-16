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

# Integration tests for bundling simple tvOS applications.

function set_up() {
  mkdir -p app
}

function tear_down() {
  rm -rf app
}

# Creates common source, targets, and basic plist for tvOS applications.
function create_common_files() {
  cat > app/BUILD <<EOF
load("@build_bazel_rules_apple//apple:tvos.bzl", "tvos_application")

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

# Creates a minimal tvOS application target.
function create_minimal_tvos_application() {
  if [[ ! -f app/BUILD ]]; then
    fail "create_common_files must be called first."
  fi

  cat >> app/BUILD <<EOF
tvos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    infoplists = ["Info.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":lib"],
)
EOF
}

# Test missing the CFBundleVersion fails the build.
function test_missing_version_fails() {
  create_common_files
  create_minimal_tvos_application

  cat > app/Info.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleShortVersionString = "1.0";
}
EOF

  ! do_build tvos //app:app \
    || fail "Should fail build"

  expect_log 'Target "//app:app" is missing CFBundleVersion.'
}

# Test missing the CFBundleShortVersionString fails the build.
function test_missing_short_version_fails() {
  create_common_files
  create_minimal_tvos_application

  cat > app/Info.plist <<EOF
{
  CFBundleIdentifier = "\${PRODUCT_BUNDLE_IDENTIFIER}";
  CFBundleName = "\${PRODUCT_NAME}";
  CFBundlePackageType = "APPL";
  CFBundleVersion = "1.0";
}
EOF

  ! do_build tvos //app:app \
    || fail "Should fail build"

  expect_log 'Target "//app:app" is missing CFBundleShortVersionString.'
}

# Tests that the linkmap outputs are produced when --objc_generate_linkmap is
# present.
function disabled_test_linkmaps_generated() {  # Blocked on b/73547215
  create_common_files
  create_minimal_tvos_application
  do_build tvos --objc_generate_linkmap //app:app || fail "Should build"

  declare -a archs=( $(current_archs tvos) )
  for arch in "${archs[@]}"; do
    assert_exists "test-bin/app/app_${arch}.linkmap"
  done
}

# Tests that the provisioning profile is present when built for device.
function test_contains_provisioning_profile() {
  # Ignore the test for simulator builds.
  is_device_build tvos || return 0

  create_common_files
  create_minimal_tvos_application
  do_build tvos //app:app || fail "Should build"

  # Verify that the IPA contains the provisioning profile.
  assert_zip_contains "test-bin/app/app.ipa" \
      "Payload/app.app/embedded.mobileprovision"
}

# Tests that failures to extract from a provisioning profile are propertly
# reported.
function test_provisioning_profile_extraction_failure() {
  create_common_files

  cat >> app/BUILD <<EOF
tvos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    infoplists = ["Info.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "bogus.mobileprovision",
    deps = [":lib"],
)
EOF

  cat > app/bogus.mobileprovision <<EOF
BOGUS BOGUS BOGUS BOGUS BOGUS BOGUS BOGUS BOGUS BOGUS BOGUS BOGUS BOGUS BOGUS
EOF

  ! do_build tvos //app:app || fail "Should fail"
  # The fact that multiple things are tried is left as an impl detail and
  # only the final message is looked for.
  expect_log 'While processing target "//app:app_entitlements", failed to extract from the provisioning profile "app/bogus.mobileprovision".'
}

# Tests that the IPA contains bitcode symbols when bitcode is embedded.
function disabled_test_bitcode_symbol_maps_packaging() {  # Blocked on b/73546952
  # Bitcode is only availabe on device. Ignore the test for simulator builds.
  is_device_build tvos || return 0

  create_common_files
  create_minimal_tvos_application
  do_build tvos //app:app --apple_bitcode=embedded || fail "Should build"

  assert_ipa_contains_bitcode_maps tvos "test-bin/app/app.ipa" \
      "Payload/app.app/app"
}

run_suite "tvos_application bundling tests"
