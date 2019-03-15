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

# Tests that the Info.plist in the packaged application has the correct content.
function test_plist_contents() {
  create_common_files
  create_minimal_tvos_application
  create_dump_plist "//app:app" "Payload/app.app/Info.plist" \
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
  do_build tvos //app:dump_plist \
      || fail "Should build"

  # Verify the values injected by the Skylark rule.
  assert_equals "app" "$(cat "test-genfiles/app/CFBundleExecutable")"
  assert_equals "my.bundle.id" "$(cat "test-genfiles/app/CFBundleIdentifier")"
  assert_equals "app" "$(cat "test-genfiles/app/CFBundleName")"
  assert_equals "10.0" "$(cat "test-genfiles/app/MinimumOSVersion")"
  assert_equals "3" "$(cat "test-genfiles/app/UIDeviceFamily.0")"

  if is_device_build tvos ; then
    assert_equals "AppleTVOS" \
        "$(cat "test-genfiles/app/CFBundleSupportedPlatforms.0")"
    assert_equals "appletvos" \
        "$(cat "test-genfiles/app/DTPlatformName")"
    assert_contains "tvos.*" "test-genfiles/app/DTSDKName"
  else
    assert_equals "AppleTVSimulator" \
        "$(cat "test-genfiles/app/CFBundleSupportedPlatforms.0")"
    assert_equals "appletvsimulator" \
        "$(cat "test-genfiles/app/DTPlatformName")"
    assert_contains "appletvsimulator.*" "test-genfiles/app/DTSDKName"
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

# Tests that the dSYM outputs are produced when --apple_generate_dsym is
# present.
function test_dsyms_generated() {
  create_common_files
  create_minimal_tvos_application
  do_build tvos --apple_generate_dsym //app:app || fail "Should build"

  assert_exists "$(find_output_artifact app/app.app.dSYM/Contents/Info.plist)"

  declare -a archs=( $(current_archs tvos) )
  for arch in "${archs[@]}"; do
    assert_exists \
        "$(find_output_artifact "app/app.app.dSYM/Contents/Resources/DWARF/app_${arch}")"
  done
}

# Tests that the linkmap outputs are produced when --objc_generate_linkmap is
# present.
function disabled_test_linkmaps_generated() {  # Blocked on b/73547215
  create_common_files
  create_minimal_tvos_application
  do_build tvos --objc_generate_linkmap //app:app || fail "Should build"

  declare -a archs=( $(current_archs tvos) )
  for arch in "${archs[@]}"; do
    assert_exists  "$(find_output_artifact "app/app_${arch}.linkmap")"
  done
}

# Tests that the IPA contains a valid signed application.
function test_application_is_signed() {
  create_common_files
  create_minimal_tvos_application
  create_dump_codesign "//app:app" "Payload/app.app" -vv
  do_build tvos //app:dump_codesign || fail "Should build"

  assert_contains "satisfies its Designated Requirement" \
      "test-genfiles/app/codesign_output"
}

# Tests that the provisioning profile is present when built for device.
function test_contains_provisioning_profile() {
  # Ignore the test for simulator builds.
  is_device_build tvos || return 0

  create_common_files
  create_minimal_tvos_application
  do_build tvos //app:app || fail "Should build"

  local output_artifact="$(find_output_artifact app/app.ipa)"

  # Verify that the IPA contains the provisioning profile.
  assert_zip_contains "$output_artifact" \
      "Payload/app.app/embedded.mobileprovision"
}

# Tests that entitlements are added to the application correctly. For debug
# builds, we make sure that the appropriate Mach-O section is present; for
# release builds, we check the code signing.
function test_entitlements() {
  create_common_files

  cat >> app/BUILD <<EOF
tvos_application(
    name = "app",
    bundle_id = "my.bundle.id",
    entitlements = "entitlements.plist",
    infoplists = ["Info.plist"],
    minimum_os_version = "10.0",
    provisioning_profile = "@build_bazel_rules_apple//test/testdata/provisioning:integration_testing_tvos.mobileprovision",
    deps = [":lib"],
)
EOF

  cat > app/entitlements.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>test-an-entitlement</key>
  <false/>
</dict>
</plist>
EOF

  if is_device_build tvos ; then
    # For device builds, we verify that the entitlements are in the codesign
    # output.
    create_dump_codesign "//app:app" "Payload/app.app" -d --entitlements :-
    do_build tvos //app:dump_codesign || fail "Should build"

    assert_contains "<key>test-an-entitlement</key>" \
        "test-genfiles/app/codesign_output"
  else
    # For simulator builds, the entitlements are added as a Mach-O section in
    # the binary.
    do_build tvos //app:app || fail "Should build"

    local output_artifact="$(find_output_artifact app/app.ipa)"

    unzip_single_file "$output_artifact" "Payload/app.app/app" | \
        print_debug_entitlements - | \
        grep -sq "<key>test-an-entitlement</key>" || \
        fail "Failed to find custom entitlement"
  fi
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

  local output_artifact="$(find_output_artifact app/app.ipa)"

  assert_ipa_contains_bitcode_maps tvos "$output_artifact" \
      "Payload/app.app/app"
}

run_suite "tvos_application bundling tests"
